#!/bin/sh
set -eu
CHEMLAB_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$CHEMLAB_ROOT/scripts/run.sh"
