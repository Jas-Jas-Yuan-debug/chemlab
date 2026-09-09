#!/usr/bin/env python3
"""Fetch pinned sources into this project; never install global software."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / 'dependencies.lock.json').read_text())


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def archive(dep):
    dest = ROOT / 'third_party/downloads' / dep['archive']
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        partial = dest.with_suffix(dest.suffix + '.part')
        print('Downloading', dep['url'], flush=True)
        with urllib.request.urlopen(dep['url'], timeout=120) as response, partial.open('wb') as out:
            shutil.copyfileobj(response, out)
        if sha256(partial) != dep['sha256']:
            raise RuntimeError(f'Checksum mismatch: {partial}; preserved for inspection')
        partial.replace(dest)
    if sha256(dest) != dep['sha256']:
        raise RuntimeError(f'Checksum mismatch: {dest}; refusing to extract or run')
    return dest


def source(key):
    dep = LOCK[key]
    src = ROOT / 'third_party/src' / dep['source_directory']
    downloaded = archive(dep)
    if not src.exists():
        src.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(downloaded) as tar:
            tar.extractall(src.parent, filter='data')
    # Verify every upstream regular file, preserving local edits if verification fails.
    with tarfile.open(downloaded) as tar:
        for member in tar:
            if member.isfile():
                target = src.parent / member.name
                with tar.extractfile(member) as original:
                    expected = hashlib.file_digest(original, 'sha256').hexdigest()
                if not target.is_file() or sha256(target) != expected:
                    raise RuntimeError(f'Upstream source changed: {target}; restore deliberately, not automatically')
    print('Verified source:', key, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--with-godot', action='store_true', help='Fetch portable macOS Godot and C++ bindings')
    args = parser.parse_args()
    source('iphreeqc')
    db = ROOT / 'third_party/src' / LOCK['iphreeqc']['source_directory'] / LOCK['database']['path']
    if sha256(db) != LOCK['database']['sha256']:
        raise RuntimeError('Database checksum mismatch')
    if args.with_godot:
        source('godot_cpp')
        downloaded = archive(LOCK['godot'])
        tools = ROOT / 'tools'
        tools.mkdir(exist_ok=True)
        if not (tools / 'Godot.app').exists():
            subprocess.run(['ditto', '-x', '-k', str(downloaded), str(tools)], check=True)
        subprocess.run([str(tools / 'Godot.app/Contents/MacOS/Godot'), '--headless', '--version'], check=True)
    print('Dependencies ready. See README.md for build commands.')


if __name__ == '__main__':
    main()
