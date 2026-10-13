#!/usr/bin/env python3
"""Record public build inputs and unsigned framework hashes, never node state."""
import hashlib
import json
import pathlib
import subprocess
root = pathlib.Path(__file__).resolve().parents[1]
pin = json.loads((root / 'Dependencies.json').read_text())['tailscale']
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {
    'schema': 'zenith.tailscale-build.v1',
    'dependency': pin,
    'patch_sha256': sha(root / pin['patch']),
    'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
    'framework_files': {str(p.relative_to(root / 'Artifacts')): sha(p)
                        for p in sorted((root / 'Artifacts/TailscaleKit.xcframework').rglob('*')) if p.is_file()},
}
(root / 'Artifacts/tailscale-build.json').write_text(json.dumps(manifest, indent=2) + '\n')
