#!/bin/sh
# ---------------------------------------------------------------------------
# BADASS - global lab settings. Sourced by every topology/check script.
# Change LOGIN here and every node name follows (subject: the equipment names
# must carry the login of one of the group members).
# ---------------------------------------------------------------------------
LOGIN=${LOGIN:-pzinurov}

# Docker images built from P1/images/host and P1/images/router
IMG_HOST=${IMG_HOST:-badass/host:latest}
IMG_ROUTER=${IMG_ROUTER:-badass/router:latest}

# Where this repository is mounted inside the containers (configs are read
# straight from it, so the files shipped in P1/P2/P3 are the ones executed).
REPO_MNT=/badass

# ----------------------------- VXLAN parameters ----------------------------
VNI=10                      # subject: "a VXLAN with an ID of 10"
VXDEV=vxlan10               # subject: "You can use any VXLAN name you like here: vxlan10"
BRIDGE=br0                  # subject: "You must set up a bridge here: br0"
VXPORT=4789                 # IANA VXLAN udp port (RFC 7348)
MCAST_GROUP=239.1.1.1       # subject: "here 239.1.1.1 you can modify this part"

# ------------------------------- node names --------------------------------
# P1
P1_HOST="host_${LOGIN}-1"
P1_ROUTER="routeur_${LOGIN}"

# P2
P2_H1="host_${LOGIN}-1";    P2_H2="host_${LOGIN}-2"
P2_R1="routeur_${LOGIN}-1"; P2_R2="routeur_${LOGIN}-2"
P2_SW="Switch_${LOGIN}"

# P3  (_LOGIN-1 is the route reflector / spine, -2..-4 are the leaves/VTEPs)
P3_RR="_${LOGIN}-1"
P3_L2="_${LOGIN}-2"; P3_L3="_${LOGIN}-3"; P3_L4="_${LOGIN}-4"
P3_H1="host_${LOGIN}-1"; P3_H2="host_${LOGIN}-2"; P3_H3="host_${LOGIN}-3"
