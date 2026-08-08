#!/usr/bin/env bash
set -euo pipefail
DIR="${1:-release-assets}"
VERSION="$(tr -d '[:space:]' < VERSION)"
python3 - "$DIR" "$VERSION" <<'PY2'
import hashlib,json,os,sys,time
from pathlib import Path
folder=Path(sys.argv[1]); version=sys.argv[2]
assets=[]
for p in sorted(folder.iterdir(), key=lambda x:x.name):
    if not p.is_file() or p.name in {'release-manifest.json'}: continue
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024), b''): h.update(b)
    assets.append({'name':p.name,'size_bytes':p.stat().st_size,'sha256':h.hexdigest()})
out={'format':'odc-release-manifest-v1','version':version,'assets':assets}
(folder/'release-manifest.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(f"manifesto: {len(assets)} assets")
PY2
