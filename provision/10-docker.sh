#!/bin/bash
# --------------------------------------------------------------------------
# Docker engine.  GNS3 builds its nodes out of docker containers, and the
# headless lab (lab/run.sh) uses exactly the same images.
# --------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
    echo "==> installing docker engine"
    install -m0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi

usermod -aG docker vagrant
systemctl enable --now docker

# docker's default FORWARD policy is DROP; the lab wires containers together
# with raw veth pairs outside of any docker network, so let those through.
iptables -P FORWARD ACCEPT || true

docker --version
echo "==> docker done"
