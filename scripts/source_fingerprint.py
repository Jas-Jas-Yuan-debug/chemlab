"""Content identity for runtime source, configuration and data (excluding caches)."""
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def source_fingerprint():
    paths=[]
    for directory in ['src','cmake','godot/scripts','godot/scenes','godot/shaders','godot/data']:
        paths += [p for p in (ROOT/directory).rglob('*') if p.is_file()]
    paths += [ROOT/name for name in ['CMakeLists.txt','dependencies.lock.json','godot/project.godot','godot/export_presets.cfg','godot/bin/chemlab.gdextension']]
    digest=hashlib.sha256()
    for p in sorted(set(paths)):
        digest.update(p.relative_to(ROOT).as_posix().encode()+b'\0')
        digest.update(p.read_bytes()+b'\0')
    return digest.hexdigest()
