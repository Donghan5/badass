#!/bin/bash

set -euo pipefail

API=http://127.0.0.1:3080/v2
PROJECT=/home/vagrant/GNS3/projects/P1/P1.gns3
OUTPUT=/badass/P1/P1.gns3project

PROJECT_ID=$(python3 - "$PROJECT" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    print(json.load(f)["project_id"])
PY
)

curl --fail --silent --show-error \
    "$API/projects/$PROJECT_ID" > /dev/null

TEMP=$(mktemp "${OUTPUT}.tmp.XXXXXX")
trap 'rm -f "$TEMP"' EXIT

curl --fail --silent --show-error \
    "$API/projects/$PROJECT_ID/export?include_images=yes&compression=zip" \
    --output "$TEMP"

python3 - "$TEMP" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    if archive.testzip() is not None:
        raise SystemExit("ZIP integrity check failed")

    names = archive.namelist()
    if not any(name.endswith(".gns3") for name in names):
        raise SystemExit("Missing GNS3 project")
    if not any(name.startswith("images/") for name in names):
        raise SystemExit("Missing base images")

    print("Archive verified")
PY

mv "$TEMP" "$OUTPUT"
echo "Exported: $OUTPUT"
