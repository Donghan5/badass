#!/bin/bash
# ---------------------------------------------------------------------------
# P3 topology (subject's diagram):
#
#                          routeur_<login>-1  (RR / spine)
#                   e0 /        e1 |        \ e2
#                     /            |         \
#            routeur_<login>-2      routeur_<login>-3     routeur_<login>-4     (leaves / VTEPs)
#               e1 |             e0 |          e0 |
#        host_<login>-1    host_<login>-2   host_<login>-3
#
# p3_up            -> fabric + hosts configured
# p3_up --staged   -> fabric only; the hosts stay unaddressed so that the
#                     check can show "type 3 only, no type 2 yet", then bring
#                     them up one by one exactly like the subject does.
# ---------------------------------------------------------------------------
p3_up() {
  local staged=0 host_state=up
  [ "${1:-}" = "--staged" ] && staged=1
  [ "$staged" -eq 0 ] || host_state=down

  info "P3 - BGP EVPN fabric, VNI $VNI, AS 1, route reflector $P3_RR"
  node_start "$P3_RR" "$IMG_ROUTER"
  node_start "$P3_L2" "$IMG_ROUTER"
  node_start "$P3_L3" "$IMG_ROUTER"
  node_start "$P3_L4" "$IMG_ROUTER"
  node_start "$P3_H1" "$IMG_HOST"
  node_start "$P3_H2" "$IMG_HOST"
  node_start "$P3_H3" "$IMG_HOST"

  # underlay: RR e0/e1/e2 towards the three leaves, on their own uplink port
  link "$P3_RR" eth0 "$P3_L2" eth0
  link "$P3_RR" eth1 "$P3_L3" eth1
  link "$P3_RR" eth2 "$P3_L4" eth2
  # access side
  link "$P3_L2" eth1 "$P3_H1" eth1 "$host_state"
  link "$P3_L3" eth0 "$P3_H2" eth0 "$host_state"
  link "$P3_L4" eth0 "$P3_H3" eth0 "$host_state"

  apply "$P3_RR" "P3/$P3_RR"
  apply "$P3_L2" "P3/$P3_L2"
  apply "$P3_L3" "P3/$P3_L3"
  apply "$P3_L4" "P3/$P3_L4"

  if [ "$staged" -eq 0 ]; then
    apply "$P3_H1" "P3/$P3_H1"
    apply "$P3_H2" "P3/$P3_H2"
    apply "$P3_H3" "P3/$P3_H3"
  else
    step "host interfaces left down and unaddressed (staged mode)"
  fi
}
