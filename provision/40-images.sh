#!/bin/bash
# --------------------------------------------------------------------------
# Build the two docker images the subject asks for.  Build context is the
# repository root so the node configuration files get baked in.
# --------------------------------------------------------------------------
set -euo pipefail
cd /badass

echo "==> building badass/host:latest   (alpine = busybox)"
docker build -q -f images/host/Dockerfile   -t badass/host:latest   .

echo "==> building badass/router:latest  (alpine + FRR zebra/bgpd/ospfd/isisd)"
docker build -q -f images/router/Dockerfile -t badass/router:latest .

docker images | grep -E 'REPOSITORY|badass/'
echo "==> images done"
