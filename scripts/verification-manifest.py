"""Record candidate source and local test/artifact hashes, never wallet state.

Usage: python3 scripts/verification-manifest.py WALLET WEB DEVGRAPH
Run after the documented checks. Log entries are evidence of that recorded run,
not an instruction to treat future changed source as qualified.
"""
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

app = Path(__file__).resolve().parents[1]
wallet, web, graph = [Path(p).resolve() for p in sys.argv[1:]]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT).strip()


def inventory(root, selections):
    files = set()
    for selection in selections:
        path = root / selection
        if path.is_file():
            files.add(path)
        elif path.is_dir():
            files.update(p for p in path.rglob('*') if p.is_file() and not p.name.startswith('.'))
    return {str(p.relative_to(root)): sha(p) for p in sorted(files)}


groups = {
    'zenith_ios': (app, ['App', 'Sources', 'Tests', 'scripts', 'Package.swift', 'project.yml']),
    'wallet': (wallet, [
        'crates/castalia-wallet-core', 'crates/castalia-wallet-presentation',
        'crates/castalia-wallet-native', 'contracts/portable-web', 'Cargo.toml', 'Cargo.lock',
        'scripts/portable-contracts.test.mjs', 'scripts/package-browser-acceptance-extension.mjs',
        'scripts/verify-ci-workflow.test.mjs',
    ]),
    'public_web': (web, [
        'apps/web/src/wallet', 'apps/web/src/profile.ts', 'apps/web/tests',
        'packages/membership-contract', 'vendor/castalia-wallet', 'crates', 'Cargo.toml', 'Cargo.lock',
        'package.json', 'pnpm-lock.yaml', 'scripts/build-wallet-wasm.mjs',
        'scripts/sync-wallet-core.py', 'scripts/verify-wallet-core.mjs',
        'tests/wallet-snapshot.test.mjs', 'tests/browser/recovery.spec.ts', 'playwright.recovery.config.ts',
    ]),
    'public_devgraph': (graph, [
        'src/devgraph/api/native_read.py', 'src/devgraph/auth/native_read.py',
        'src/devgraph/auth/native_membership.py', 'tests/native_read',
    ]),
}
sources = {}
for name, (root, selections) in groups.items():
    hashes = inventory(root, selections)
    # Exclude compiler/cache output inside package source trees.
    hashes = {k: v for k, v in hashes.items() if not any(part in k.split('/') for part in ['__pycache__', 'dist', '.turbo', 'target'])}
    sources[name] = {
        'base_revision': None if root == app else command(['git', 'rev-parse', 'HEAD'], root),
        'state': 'uncommitted candidate; base revision is not the implementation pin',
        'files': hashes,
        'digest': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(),
    }

logs = {
    'wallet_rust_workspace': ('/tmp/zenith-wallet-rust.log', 'passed'),
    'wallet_recovery_final': ('/tmp/zenith-wallet-recovery-final.log', '5 passed'),
    'wallet_portable_final': ('/tmp/zenith-wallet-portable.log', '3 passed'),
    'wallet_javascript_workspace': ('/tmp/zenith-wallet-tests.log', 'passed'),
    'wallet_types': ('/tmp/zenith-wallet-types.log', 'passed'),
    'wallet_pins': ('/tmp/zenith-wallet-pins-final.log', 'passed'),
    'swift': (str(app / 'Artifacts/swift-tests.log'), '8 passed'),
    'ios_simulator_build': (str(app / 'Artifacts/xcode-simulator-build.log'), 'passed'),
    'web_workspace': ('/tmp/zenith-web-workspace-tests.log', '263 passed across seven suites'),
    'web_ui_final': ('/tmp/zenith-web-ui-final.log', '7 passed after final copy adjustment'),
    'web_recovery_final': ('/tmp/zenith-web-recovery-final.log', '8 passed after final temporary-custody disposal adjustment'),
    'web_types': ('/tmp/zenith-web-workspace-types.log', 'passed'),
    'web_lint': ('/tmp/zenith-web-workspace-lint.log', 'passed'),
    'web_rust': ('/tmp/zenith-web-rust.log', '20 passed'),
    'web_build': ('/tmp/zenith-web-build.log', 'passed'),
    'web_contracts': ('/tmp/zenith-web-contracts.log', 'passed'),
    'web_pins': ('/tmp/zenith-web-pins.log', 'passed'),
    'web_docs': ('/tmp/zenith-web-docs.log', 'passed'),
    'web_format': ('/tmp/zenith-web-format-check.log', 'passed'),
    'web_policy': ('/tmp/zenith-web-policies.log', 'passed'),
    'web_bundle_scan': ('/tmp/zenith-web-bundle-scan.log', 'passed'),
    'web_browser': ('/tmp/zenith-recovery-browser-final.log', '2 passed; isolated Chrome, scoped axe'),
    'devgraph_auth_and_reads': ('/tmp/zenith-devgraph-final.log', '371 passed'),
    'devgraph_native_final': ('/tmp/zenith-devgraph-native-final.log', '12 passed after explicit no-store responses'),
}
evidence_dir = app / 'Artifacts/qualification'
evidence_dir.mkdir(exist_ok=True)
checks = {}
for name, (filename, result) in logs.items():
    path = Path(filename)
    destination = evidence_dir / (name + '.log')
    destination.write_bytes(path.read_bytes())
    checks[name] = {'result': result, 'log': str(destination.relative_to(app)), 'sha256': sha(destination)}

core = json.loads((app / 'Artifacts/core-build-manifest.json').read_text())
manifest = {
    'schema': 'zenith.ios-source-verification.v1',
    'recorded_at': datetime.now(timezone.utc).isoformat(),
    'claim': 'source checks and Simulator welcome inspection only; no physical-device or live activation claim',
    'sources': sources,
    'native_core': core,
    'artifacts': {
        'simulator_app': inventory(app / '.derived-data/Build/Products/Debug-iphonesimulator/Zenith.app', ['.']),
        'web_wasm': sha(web / 'apps/web/src/generated/castalia-wallet-wasm/castalia_wallet_wasm_bg.wasm'),
        'web_build': inventory(web / 'apps/web/dist', ['assets', 'index.html']),
        'simulator_screenshot': sha(app / 'Artifacts/welcome-iphone16-final.png'),
    },
    'tools': {
        'xcode': command(['xcodebuild', '-version']),
        'swift': command(['xcrun', 'swift', '--version']),
        'rustc': command(['rustc', '--version']),
        'cargo': command(['cargo', '--version']),
        'node': command(['node', '--version']),
        'pnpm': command(['pnpm', '--version'], web),
        'wasm_pack': command(['wasm-pack', '--version']),
        'wasm_bindgen': command(['wasm-bindgen', '--version']),
    },
    'checks': checks,
    'simulator': {'device': 'iPhone 16', 'os': 'iOS 18.6', 'installed_and_launched': True, 'interactive_journeys': 'not exercised; explicit interaction approval pending'},
    'outstanding': [
        'physical iPhone qualification with approved disposable service configuration',
        'VoiceOver, largest Dynamic Type, small-device and Files interruption qualification',
        'five-person usability acceptance and independent custody review',
        'reviewed commit pins and signed distribution artifacts',
        'separate Devgraph/Wallet/secS mutation-chain installed gate remains unchanged',
    ],
    'live_activation': 'excluded; no live identity, grants, trust, data or deployment changed',
}
output = app / 'verification/source-checks-2026-10-12.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(manifest, indent=2) + '\n')
print('Recorded source-checks-2026-10-12.json; no wallet or configuration contents collected')
