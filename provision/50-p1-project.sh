#!/bin/bash
# --------------------------------------------------------------------------
# Register the two images as GNS3 templates and drop a ready-made P1 project
# into ~/GNS3/projects, so GNS3 opens on the part 1 diagram.
#
# Everything here is written ONCE.  Re-provisioning leaves your GNS3 settings
# and your projects alone - GNS3 records the id of the docker container it
# created for each node inside the project file, so silently regenerating it
# would orphan those containers and the next start would fail with a docker
# "name already in use" conflict.
#
#   BADASS_FORCE_PROJECT=1 vagrant provision --provision-with p1
# forces a clean regeneration (and prunes the orphaned containers).
# --------------------------------------------------------------------------
set -euo pipefail

GNS3_HOME=/home/vagrant/GNS3
CFG=/home/vagrant/.config/GNS3/2.2
FORCE=${BADASS_FORCE_PROJECT:-0}

mkdir -p "$GNS3_HOME/projects/P1" "$GNS3_HOME/images" "$CFG" /home/vagrant/.config/autostart

write_once() {           # write_once <file> <generator...>
    local f=$1; shift
    if [ -f "$f" ] && [ "$FORCE" != "1" ]; then
        echo "    keeping existing $(basename "$f")"
        return
    fi
    "$@" > "$f"
    echo "    wrote $(basename "$f")"
}

echo "==> GNS3 gui settings (skip the setup wizard)"
write_once "$CFG/gns3_gui.conf"        python3 /badass/tools/gns3gen.py gui-config

echo "==> GNS3 templates: badass host / badass router"
write_once "$CFG/gns3_controller.conf" python3 /badass/tools/gns3gen.py templates

echo "==> GNS3 project P1"
PROJ="$GNS3_HOME/projects/P1/P1.gns3"
if [ -f "$PROJ" ] && [ "$FORCE" != "1" ]; then
    echo "    keeping existing P1.gns3"
else
    # the project file records the docker container id of every node; a fresh
    # one must start from a clean slate or docker refuses the container names
    ids=$(docker ps -aq --filter "name=GNS3." 2>/dev/null || true)
    [ -n "$ids" ] && docker rm -f $ids >/dev/null 2>&1 || true
    python3 /badass/tools/gns3gen.py project P1 > "$PROJ"
    echo "    wrote P1.gns3"
fi

# Additional source-defined projects. Preserve any existing GUI work.
for part in P2 P2-multicast P3; do
    mkdir -p "$GNS3_HOME/projects/$part"
    write_once "$GNS3_HOME/projects/$part/$part.gns3" \
        python3 /badass/tools/gns3gen.py project "$part"
done

echo "==> autostart GNS3 on the desktop"
cat > /home/vagrant/.config/autostart/gns3.desktop <<DK
[Desktop Entry]
Type=Application
Name=GNS3
Comment=BADASS lab - opens the P1 project
Exec=gns3 $PROJ
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
DK

chown -R vagrant:vagrant /home/vagrant/.config /home/vagrant/GNS3

echo "==> P1 ready"
