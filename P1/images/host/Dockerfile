# ===========================================================================
#  BADASS - image 1 : the end device  ("host_<login>-N")
#
#  Subject: "The first image should be based on a system of your choice and
#            must contain at least busybox or an equivalent solution."
#
#  Alpine IS busybox: /bin/sh, ip, ifconfig, ping, arp ... are all busybox
#  applets, so the requirement is met by construction.  busybox-extras is
#  added on top for telnet/telnetd (GNS3 consoles a node over telnet).
#
#  Subject: "No IP address should be configured by default."
#  -> nothing here touches the network; addressing is done per node by the
#     configuration files committed in P1/ P2/ P3.
# ===========================================================================
FROM alpine:3.20

LABEL org.opencontainers.image.title="badass-host" \
      org.opencontainers.image.description="busybox/alpine end device for GNS3"

RUN apk add --no-cache \
        busybox-extras \
        iproute2 \
        iputils \
        tcpdump \
        ethtool \
 && ln -sf /bin/busybox /usr/bin/busybox

# The per-equipment configuration files are baked in, so a GNS3 node can
# configure itself from its own console:   sh /badass/P1/<node>
# (the headless lab bind-mounts the live repo over /badass instead, so edits
#  on the host take effect without rebuilding the image)
COPY P1 /badass/P1
COPY P2 /badass/P2
COPY P3 /badass/P3
COPY lab/env.sh /badass/lab/env.sh

# GNS3 consoles the node and expects an interactive shell to be there.
CMD ["/bin/sh"]
