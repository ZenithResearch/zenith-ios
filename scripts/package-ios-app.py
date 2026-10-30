#!/usr/bin/env python3
"""Package an existing device build and verify every embedded Mach-O signature.

Xcode debug builds may put application code in a top-level .debug.dylib.
Verifying the outer app seal alone does not prove that dylib is signed.
This script signs nested binaries before frameworks and the outer application.
It never reads or modifies installed application data.
"""
import argparse
import datetime
import json
from pathlib import Path
import plistlib
import shutil
import subprocess

MAGIC = {bytes.fromhex(v) for v in (
    "feedface", "cefaedfe", "feedfacf", "cffaedfe",
    "cafebabe", "bebafeca", "cafebabf", "bfbafeca",
)}


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise RuntimeError("Command failed: " + args[0] + "\n" + result.stderr.decode(errors="replace"))
    return result


def binaries(app):
    found = []
    for path in sorted(app.rglob("*")):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open("rb") as stream:
            if stream.read(4) in MAGIC:
                found.append(path)
    return found


def entitlements(app):
    return plistlib.loads(run("codesign", "-d", "--entitlements", ":-", str(app)).stdout)


def internal_links(app):
    for path in app.rglob("*"):
        if path.is_symlink() and not path.resolve(strict=True).is_relative_to(app):
            raise RuntimeError("Application contains an external symbolic link")


def verify(app, expected_entitlements=None):
    internal_links(app)
    profile = plistlib.loads(run("security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")).stdout)
    team = profile["TeamIdentifier"][0]
    if profile["ExpirationDate"].replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        raise RuntimeError("The embedded provisioning profile has expired")
    embedded = binaries(app)
    if not embedded:
        raise RuntimeError("Application contains no Mach-O binaries")
    for binary in embedded:
        # Verify each actual executable, including top-level debug/preview dylibs.
        run("codesign", "--verify", "--strict", str(binary))
        details = run("codesign", "-d", "--verbose=4", str(binary)).stderr.decode()
        if "TeamIdentifier=" + team not in details.splitlines():
            raise RuntimeError("Embedded code does not match the provisioning team: " + binary.name)
    run("codesign", "--verify", "--deep", "--strict", str(app))
    actual = entitlements(app)
    if expected_entitlements is not None and actual != expected_entitlements:
        raise RuntimeError("Application entitlements changed")
    if actual.get("com.apple.developer.team-identifier") != team:
        raise RuntimeError("Application team does not match its provisioning profile")
    app_id = actual.get("application-identifier", "")
    bundle_id = plistlib.loads((app / "Info.plist").read_bytes())["CFBundleIdentifier"]
    if not app_id.endswith("." + bundle_id):
        raise RuntimeError("Application identity does not match its bundle identifier")
    admitted = profile["Entitlements"]["application-identifier"]
    if not (app_id == admitted or admitted.endswith("*") and app_id.startswith(admitted[:-1])):
        raise RuntimeError("Application identity does not match its provisioning profile")
    return {"verified": True, "same_provisioning_team": True,
            "mach_o_binaries": [str(p.relative_to(app)) for p in embedded]}


def verify_baseline(app, baseline):
    """Reject an update that changes an explicitly selected installed baseline.

    This check runs before any output is created or signed. A renewed profile is
    allowed, but it must still admit the exact existing Keychain access groups.
    """
    verify(baseline)
    actual, previous = entitlements(app), entitlements(baseline)
    if actual != previous:
        raise RuntimeError("Update entitlements differ from the selected baseline")
    current_info = plistlib.loads((app / "Info.plist").read_bytes())
    previous_info = plistlib.loads((baseline / "Info.plist").read_bytes())
    if current_info["CFBundleIdentifier"] != previous_info["CFBundleIdentifier"]:
        raise RuntimeError("Update bundle identifier differs from the selected baseline")
    profile = plistlib.loads(run("security", "cms", "-D", "-i",
                                str(app / "embedded.mobileprovision")).stdout)
    allowed = profile["Entitlements"].get("keychain-access-groups", [])
    for group in previous.get("keychain-access-groups", []):
        if not any(group == pattern or pattern.endswith("*") and
                   group.startswith(pattern[:-1]) for pattern in allowed):
            raise RuntimeError("Update profile does not admit a baseline Keychain group")
    return {"baseline_entitlements_unchanged": True,
            "baseline_keychain_groups_admitted": True,
            "baseline_bundle_identifier_unchanged": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-app", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--output-app", type=Path)
    parser.add_argument("--build-number")
    parser.add_argument("--identity", help="Existing code-signing certificate SHA-1")
    parser.add_argument("--baseline-app", type=Path,
                        help="Previously installed signed app; reject entitlement/identity changes before packaging")
    args = parser.parse_args()
    app = args.source_app.resolve()
    baseline_checks = verify_baseline(app, args.baseline_app.resolve()) if args.baseline_app else {}
    if args.verify_only:
        print(json.dumps(dict(verify(app), **baseline_checks)))
        return
    if not all((args.output_app, args.build_number, args.identity)):
        parser.error("Packaging requires --output-app, --build-number and --identity")
    output = args.output_app.resolve()
    if app in output.parents:
        raise RuntimeError("Output must be outside the source application")
    if output.exists():
        raise RuntimeError("Output exists; preserve it and select a new build path")
    if any(p.suffix in (".appex", ".app") for p in app.rglob("*") if p.is_dir()):
        raise RuntimeError("Nested applications/extensions require their own explicit entitlement plan")
    internal_links(app)
    # The original seal binds the previously qualified build's resource bytes,
    # including any unsigned debug dylibs. Do not bless a modified source app.
    run("codesign", "--verify", "--deep", "--strict", str(app))
    original_entitlements = entitlements(app)
    original_info = plistlib.loads((app / "Info.plist").read_bytes())
    shutil.copytree(app, output, symlinks=True)
    internal_links(output)
    run("codesign", "--verify", "--deep", "--strict", str(output))
    info = dict(original_info, CFBundleVersion=args.build_number)
    (output / "Info.plist").write_bytes(plistlib.dumps(info))
    executable = output / info["CFBundleExecutable"]
    for binary in sorted(binaries(output), key=lambda p: len(p.parts), reverse=True):
        if binary != executable:
            run("codesign", "--force", "--sign", args.identity, "--timestamp=none", str(binary))
    for framework in sorted(output.rglob("*.framework"), key=lambda p: len(p.parts), reverse=True):
        run("codesign", "--force", "--sign", args.identity, "--timestamp=none", str(framework))
    # Use only the source app's existing entitlements, never add capabilities.
    entitlement_file = output.parent / (output.name + ".signing-entitlements.plist")
    if entitlement_file.exists():
        raise RuntimeError("Signing scratch already exists")
    created_entitlement_file = False
    try:
        with entitlement_file.open("xb") as stream:
            created_entitlement_file = True
            entitlement_file.chmod(0o600)
            stream.write(plistlib.dumps(original_entitlements))
        run("codesign", "--force", "--sign", args.identity, "--timestamp=none",
            "--generate-entitlement-der", "--entitlements", str(entitlement_file), str(output))
    finally:
        if created_entitlement_file:
            entitlement_file.unlink(missing_ok=True)
    if (output / "embedded.mobileprovision").read_bytes() != (app / "embedded.mobileprovision").read_bytes():
        raise RuntimeError("Provisioning profile changed")
    result = verify(output, original_entitlements)
    result.update(build=args.build_number, same_application_identifier=True,
                  same_keychain_access_groups=True, same_provisioning_profile=True)
    result.update(baseline_checks)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
