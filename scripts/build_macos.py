#!/usr/bin/env python3
"""Build a project-local Apple Silicon app with the pinned official runtime."""
import hashlib
import json
import time
from pathlib import Path
import shutil
import subprocess
import zipfile
from fetch_macos_template import fetch,ROOT
from source_fingerprint import source_fingerprint

source = fetch()
output = ROOT/'tools/macos-template.arm64.zip'
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(source) as original,zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED) as target:
    for item in original.infolist():
        data=original.read(item)
        if item.filename.endswith('.universal'):
            universal=ROOT/'tools/template-universal-local'
            arm=ROOT/'tools/template-arm64-local'
            universal.write_bytes(data)
            subprocess.run(['lipo',str(universal),'-thin','arm64','-output',str(arm)],check=True)
            data=arm.read_bytes()
            item.filename=item.filename.removesuffix('.universal')+'.arm64'
        target.writestr(item,data)
link=ROOT/'godot/bin/macos-template.zip'
if link.is_symlink():link.unlink()
if link.exists():raise RuntimeError('Unexpected real file at template link; preserved')
link.symlink_to('../../tools/macos-template.arm64.zip')
(ROOT/'dist').mkdir(exist_ok=True)
command=[str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'),'--headless','--path','godot','--export-release','macOS Apple Silicon','../dist/ChemLab.app']
result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(ROOT/'artifacts/export.log').write_text(result.stdout)
if result.returncode or 'ERROR:' in result.stdout:
    raise RuntimeError('Export failed; see artifacts/export.log')
app=ROOT/'dist/ChemLab.app'
licenses=app/'Contents/Resources/Licenses'
licenses.mkdir(exist_ok=True)
for source in [ROOT/'LICENSE',ROOT/'THIRD_PARTY_NOTICES.md',*list((ROOT/'third_party/licenses').glob('*'))]:
    if source.is_file():shutil.copy2(source,licenses/source.name)
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
files={}
for path in sorted(app.rglob('*')):
    if path.is_file():
        files[path.relative_to(app).as_posix()]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
receipt={'created_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'source_sha256':source_fingerprint(),
    'architecture':'arm64','runtime':'official Godot 4.7.2 release template, thinned from universal',
    'signing':'ad-hoc, codesign --verify --deep --strict passed','notarized':False,'files':files}
(ROOT/'artifacts/build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Built and verified ad-hoc signed Apple Silicon app:',app)
