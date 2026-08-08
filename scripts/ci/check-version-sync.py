#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
root=Path(__file__).resolve().parents[2]
v=(root/'VERSION').read_text().strip()
checks=[]
def eq(label, got):
    checks.append((label,got));
    if got != v:
        raise SystemExit(f'{label}: {got!r} != VERSION {v!r}')
for rel in ['nodejs/package.json','typescript/package.json','studio-web/package.json','studio-html-js/package.json']:
    eq(rel,json.loads((root/rel).read_text())['version'])
for rel in ['rust-tauri/Cargo.toml','rust-tauri/studio/src-tauri/Cargo.toml']:
    txt=(root/rel).read_text(); m=re.search(r'^version\s*=\s*"([^"]+)"',txt,re.M); eq(rel,m.group(1) if m else '')
conf=json.loads((root/'rust-tauri/studio/src-tauri/tauri.conf.json').read_text()); eq('tauri.conf.json',conf['version'])
props=(root/'csharp-dotnet/Directory.Build.props').read_text(); m=re.search(r'<Version>([^<]+)</Version>',props); eq('Directory.Build.props',m.group(1) if m else '')
print('Versões sincronizadas:', v, '-', ', '.join(x[0] for x in checks))
