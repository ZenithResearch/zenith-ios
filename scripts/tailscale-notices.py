#!/usr/bin/env python3
"""Generate bundled notices from the packages linked into the pinned iOS core."""
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
raw = (root / 'Artifacts/tailscale-go-packages.json').read_text()
decoder = json.JSONDecoder()
modules = {}
while raw.strip():
    value, end = decoder.raw_decode(raw.lstrip())
    raw = raw.lstrip()[end:]
    module = value.get('Module')
    if module and not module.get('Main'):
        modules[module['Path']] = module
parts = ['Third-party Go dependencies used by the embedded Tailscale core.\n']
missing = []
for name, module in sorted(modules.items()):
    folder = Path(module['Dir'])
    files = sorted(p for p in folder.iterdir() if p.is_file() and p.name.upper().startswith(('LICENSE','COPYING','NOTICE')))
    if not files:
        missing.append(name)
    parts.append('\n' + '=' * 72 + '\n' + name + ' ' + module['Version'] + '\n')
    for path in files:
        parts.extend(['\n' + path.name + '\n', path.read_text()])
if missing:
    raise SystemExit('Missing module notices: ' + ', '.join(missing))
parts.extend(['\nGo standard library\n', (Path(subprocess.check_output(['go', 'env', 'GOROOT'], text=True).strip()) / 'LICENSE').read_text()])
(root / 'App/Notices/Tailscale-dependencies.txt').write_text('\n'.join(parts))
print(f'Generated notices for {len(modules)} linked modules and Go.')
