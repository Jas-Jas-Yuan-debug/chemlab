#!/bin/sh
set -eu
CHEMLAB_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$CHEMLAB_ROOT"
python3 scripts/bootstrap.py --with-godot
python3 scripts/build_catalog.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCHEMLAB_BUILD_GODOT=ON
cmake --build build --parallel 4
exec "$CHEMLAB_ROOT/tools/Godot.app/Contents/MacOS/Godot" --path "$CHEMLAB_ROOT/godot"
