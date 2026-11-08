#!/bin/bash
# --------------------------------------------------------------------------
# Base system: packages the lab needs and the kernel modules VXLAN relies on.
# --------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> apt update"
apt-get update -qq

echo "==> base packages"
apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg lsb-release \
    iproute2 bridge-utils tcpdump ethtool iputils-ping \
    make git jq python3 python3-venv unzip zip \
    net-tools traceroute

echo "==> kernel modules for VXLAN / bridging"
cat > /etc/modules-load.d/badass.conf <<'MOD'
vxlan
bridge
br_netfilter
8021q
MOD
modprobe vxlan      || true
modprobe bridge     || true
modprobe br_netfilter || true
modprobe 8021q      || true

# A linux bridge must NOT hand frames to iptables here: the lab's "switch" is
# a dumb L2 device and docker's default FORWARD policy would drop the VXLAN
# underlay traffic crossing it.
cat > /etc/sysctl.d/99-badass.conf <<'SYS'
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-ip6tables=0
net.bridge.bridge-nf-call-arptables=0
SYS
sysctl --system >/dev/null 2>&1 || true

echo "==> base done"
