#!/bin/bash
# ---------------------------------------------------------------------------
# P2 topology (subject's diagram):
#
#   host_<login>-1 --e1--e1-- routeur_<login>-1 --e0--e0-- Switch_<login>
#                                                            |e1
#   host_<login>-2 --e1--e1-- routeur_<login>-2 --e0---------+
#
# p2_up static      -> vxlan10 with "remote"  (configs *_s)
# p2_up multicast   -> vxlan10 with "group"   (configs *_g)
# ---------------------------------------------------------------------------
p2_up() {
  local mode=${1:-static} sfx
  case "$mode" in
    static)    sfx=_s ;;
    multicast) sfx=_g ;;
    *) die "p2_up: mode must be 'static' or 'multicast'" ;;
  esac

  info "P2 - VXLAN $VNI, $mode mode"
  node_start "$P2_H1" "$IMG_HOST"
  node_start "$P2_H2" "$IMG_HOST"
  node_start "$P2_R1" "$IMG_ROUTER"
  node_start "$P2_R2" "$IMG_ROUTER"

  switch_add "$P2_SW"
  switch_port "$P2_SW" "$P2_R1" eth0        # Switch e0
  switch_port "$P2_SW" "$P2_R2" eth0        # Switch e1
  link "$P2_H1" eth1 "$P2_R1" eth1
  link "$P2_H2" eth1 "$P2_R2" eth1

  apply "$P2_R1" "P2/${P2_R1}${sfx}"
  apply "$P2_R2" "P2/${P2_R2}${sfx}"
  apply "$P2_H1" "P2/$P2_H1"
  apply "$P2_H2" "P2/$P2_H2"
}
