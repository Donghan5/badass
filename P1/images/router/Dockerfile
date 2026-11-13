# ===========================================================================
#  BADASS - image 2 : the router / VTEP  ("routeur_<login>-N", "_<login>-N")
#
#  Subject requires, in a single image:
#    * a packet routing manager (zebra or quagga)      -> FRRouting's zebra
#    * the service BGPD active and configured          -> frr bgpd  (+ EVPN)
#    * the service OSPFD active and configured         -> frr ospfd
#    * an IS-IS routing engine service                 -> frr isisd
#    * busybox or an equivalent                        -> alpine = busybox
#
#  FRR is the maintained successor of Quagga (same vtysh/zebra lineage) and is
#  the only one of the two that speaks BGP EVPN (RFC 7432), which part 3 needs.
#
#  Subject: "No IP address should be configured by default."
#  -> /etc/frr/frr.conf is left empty in the image.  Each node gets its own
#     configuration from the files committed in P1/ P2/ P3.
# ===========================================================================
FROM alpine:3.20

LABEL org.opencontainers.image.title="badass-router" \
      org.opencontainers.image.description="FRR (zebra/bgpd/ospfd/isisd) VTEP for GNS3"

RUN apk add --no-cache \
        frr \
        busybox-extras \
        iproute2 \
        iputils \
        bridge-utils \
        tcpdump \
        ethtool \
 && ln -sf /bin/busybox /usr/bin/busybox

# Which routing engines this image runs.  The subject asks for bgpd, ospfd and
# an IS-IS engine to be active; zebra is the RIB/kernel dataplane manager that
# all of them talk to.  frr-start reads this very file to decide what to spawn.
COPY P1/images/router/daemons      /etc/frr/daemons
COPY P1/images/router/vtysh.conf   /etc/frr/vtysh.conf
COPY P1/images/router/frr-start    /usr/local/bin/frr-start

RUN chmod +x /usr/local/bin/frr-start \
 && install -d -o frr -g frr -m 0755 /var/run/frr /var/log/frr \
 && : > /etc/frr/frr.conf \
 && chown frr:frr /etc/frr/daemons /etc/frr/vtysh.conf /etc/frr/frr.conf \
 && chmod 0640 /etc/frr/frr.conf

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
