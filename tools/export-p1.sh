#!/bin/bash

set -euo pipefail

API=http://127.0.0.1:3080/v2
PROJECT=/home/vagrant/GNS3/projects/P1/P1.gns3
OUTPUT=/badass/P1/P1.gns3project

: "${GNS3_USER:?Set GNS3_USER}"
: "${GNS3_PASSWORD:?Set GNS3_PASSWORD}"

PROJECT_ID=$(python3 - "$PROJECT" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    print(json.load(f)["project_id"])
PY
)

curl --fail --silent --show-error \
    --user "$GNS3_USER:$GNS3_PASSWORD" \
    "$API/projects/$PROJECT_ID" > /dev/null

TEMP=$(mktemp "${OUTPUT}.tmp.XXXXXX")
trap 'rm -f "$TEMP"' EXIT

curl --fail --silent --show-error \
    --user "$GNS3_USER:$GNS3_PASSWORD" \
    "$API/projects/$PROJECT_ID/export?include_images=yes&compression=zip" \
    --output "$TEMP"

python3 - "$TEMP" <<'PY'
import sys
import zipfile
import json

with zipfile.ZipFile(sys.argv[1]) as archive:
    if archive.testzip() is not None:
        raise SystemExit("ZIP integrity check failed")

    names = archive.namelist()
    if "project.gns3" not in names:
        raise SystemExit("Missing GNS3 project")

    project = json.loads(archive.read("project.gns3"))
    nodes = project.get("topology", {}).get("nodes", [])
    required_images = {"badass/host:latest", "badass/router:latest"}
    used_images = {
        node.get("properties", {}).get("image")
        for node in nodes
        if node.get("node_type") == "docker"
    }
    if not required_images.issubset(used_images):
        raise SystemExit("Missing required Docker image references")

    print("Archive verified")
PY

mv "$TEMP" "$OUTPUT"
echo "Exported: $OUTPUT"
