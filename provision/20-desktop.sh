#!/bin/bash
# --------------------------------------------------------------------------
# A minimal XFCE desktop with autologin, so that "vagrant up" opens a
# VirtualBox window you can actually work in (GNS3 is a GUI tool).
# --------------------------------------------------------------------------
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# never stop on a conffile prompt during an unattended provision
APT="apt-get -y -qq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# the bento box already ships VirtualBox Guest Additions (built from the ISO);
# the distro packages collide with them, so they are deliberately NOT installed
dpkg --configure -a 2>/dev/null || true

if ! dpkg -s xfce4-session >/dev/null 2>&1; then
    echo "==> installing XFCE + lightdm (this is the long one)"
    $APT install --no-install-recommends \
        xserver-xorg xinit \
        xfce4 xfce4-session xfce4-panel xfce4-terminal xfdesktop4 \
        thunar mousepad \
        lightdm lightdm-gtk-greeter \
        dbus-x11 policykit-1 \
        fonts-dejavu-core
fi

echo "==> autologin as vagrant"
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-badass-autologin.conf <<'LD'
[Seat:*]
autologin-user=vagrant
autologin-user-timeout=0
user-session=xfce
greeter-hide-users=false
LD
groupadd -f autologin
groupadd -f nopasswdlogin
usermod -aG autologin,nopasswdlogin vagrant

systemctl set-default graphical.target
systemctl enable lightdm

# no screen blanking, and a usable resolution.  The bento box ships VirtualBox
# Guest Additions but not VBoxClient, so the screen does not follow the window
# on its own; BADASS_RES picks the mode once, at session start.
RES="${BADASS_RES:-1440x900}"
mkdir -p /home/vagrant/.config/autostart
cat > /home/vagrant/.config/autostart/badass-session.desktop <<DK
[Desktop Entry]
Type=Application
Name=BADASS session tweaks
Exec=sh -c "xset s off; xset -dpms; xset s noblank; xrandr --output Virtual-1 --mode $RES || true"
X-GNOME-Autostart-enabled=true
DK
chown -R vagrant:vagrant /home/vagrant/.config

echo "==> desktop done"
