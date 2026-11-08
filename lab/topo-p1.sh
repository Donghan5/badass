#!/bin/bash
# ---------------------------------------------------------------------------
# P1 topology:  host_<login>-1   and   routeur_<login>   (no link, like the
# subject's diagram).  Both nodes must simply be up and consoleable.
# ---------------------------------------------------------------------------
p1_up() {
  info "P1 - two docker nodes in GNS3 style"
  node_start "$P1_HOST"   "$IMG_HOST"
  node_start "$P1_ROUTER" "$IMG_ROUTER"
  apply "$P1_HOST"   "P1/$P1_HOST"
  apply "$P1_ROUTER" "P1/$P1_ROUTER"
}
