#!/bin/bash
# Export the source-defined P1 topology with real Docker images.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$HERE/portable.py" export P1
