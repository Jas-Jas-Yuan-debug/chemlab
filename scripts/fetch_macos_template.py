#!/usr/bin/env python3
"""Fetch only the macOS member of the official template ZIP via HTTP ranges."""
import hashlib
import io
import json
from pathlib import Path
import struct
import urllib.request
import zipfile
ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT/'dependencies.lock.json').read_text())
URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
SIZE = 1281349702

def get_range(start, end):
    req = urllib.request.Request(URL, headers={'Range': f'bytes={start}-{end}'})
    with urllib.request.urlopen(req, timeout=60) as response:
        if response.status != 206 or response.headers.get('Content-Range') != f'bytes {start}-{end}/{SIZE}':
            raise RuntimeError('Server did not honor byte range; refusing full template download')
        data = response.read(end-start+2)
    if len(data) != end-start+1:
        raise RuntimeError('Truncated byte range')
    return data

def fetch():
    dest = ROOT/'third_party/downloads/Godot-4.7.2-macos-template.zip'
    dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists():
        tail = get_range(SIZE-65536,SIZE-1)
        end = tail.rfind(b'PK\x05\x06')
        fields = struct.unpack_from('<4s4H2LH',tail,end)
        cd_size,cd_offset = fields[5:7]
        # zipfile adjusts member offsets by the central-directory displacement.
        compact = io.BytesIO(tail)
        with zipfile.ZipFile(compact) as directory:
            info = directory.getinfo('templates/macos.zip')
            offset = info.header_offset+SIZE-65536
            expected_crc = info.CRC
            compressed_size = info.compress_size
            method = info.compress_type
        local = get_range(offset,offset+29)
        _,_,_,_,_,_,_,_,_,name_len,extra_len = struct.unpack('<4s5H3L2H',local)
        start = offset+30+name_len+extra_len
        print(f'Downloading macOS template member only: {compressed_size/1024**2:.1f} MiB',flush=True)
        data = get_range(start,start+compressed_size-1)
        if method==8:
            import zlib
            data=zlib.decompress(data,-15)
        elif method!=0:
            raise RuntimeError('Unsupported ZIP method')
        import binascii
        if binascii.crc32(data)!=expected_crc:
            raise RuntimeError('ZIP member CRC mismatch')
        partial=dest.with_suffix('.part')
        partial.write_bytes(data)
        digest=hashlib.sha256(data).hexdigest()
        expected=LOCK.get('godot_macos_template',{}).get('sha256')
        if expected and digest!=expected:
            raise RuntimeError('Template SHA-256 mismatch; partial retained')
        partial.replace(dest)
    digest=hashlib.sha256(dest.read_bytes()).hexdigest()
    expected=LOCK.get('godot_macos_template',{}).get('sha256')
    if expected and digest!=expected:
        raise RuntimeError('Template SHA-256 mismatch')
    print(dest.name,digest,flush=True)
    return dest

if __name__=='__main__':
    fetch()
