#!/bin/bash
# --------------------------------------------------------------------------
# GNS3 (gui + local server) from the official PPA, plus wireshark so that the
# "capture" entries of the GNS3 context menu work.
# --------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
APT="apt-get -y -qq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

if ! command -v gns3 >/dev/null 2>&1; then
    echo "==> GNS3 PPA"
    $APT install --no-install-recommends software-properties-common
    add-apt-repository -y ppa:gns3/ppa
    apt-get update -qq

    # let non-root users run ubridge / capture, answered up-front so that the
    # install stays non-interactive
    echo "ubridge ubridge/install-setuid boolean true"               | debconf-set-selections
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

    echo "==> installing gns3-server, gns3-gui, ubridge, wireshark"
    $APT install gns3-server gns3-gui ubridge
    $APT install --no-install-recommends wireshark tshark || true
fi

for g in docker ubridge wireshark kvm; do
    getent group "$g" >/dev/null && usermod -aG "$g" vagrant
done

# the GUI starts its own local server; make sure a packaged system service
# does not fight with it for port 3080
systemctl disable --now gns3-server 2>/dev/null || true

gns3 --version || true
echo "==> gns3 done"
