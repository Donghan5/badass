#!/bin/bash
# ---------------------------------------------------------------------------
# P1 verification - exactly what the subject asks for part 1:
#
#   image 1 : "a system of your choice + at least busybox or an equivalent"
#   image 2 : zebra/quagga + BGPD active and configured + OSPFD active and
#             configured + an IS-IS routing engine + busybox
#   both    : working nodes you can connect to
#   and     : "No IP address should be configured by default"
# ---------------------------------------------------------------------------
check_p1() {
  echo
  info "P1 - image 1: $P1_HOST"
  expect     "node is running"                       test -n "$(node_pid "$P1_HOST")"
  expect_out "busybox is present"      'BusyBox'     sh_in "$P1_HOST" busybox
  expect_out "/bin/sh is busybox ash"  'busybox'     sh_in "$P1_HOST" readlink -f /bin/sh
  expect_out "iproute2 available"      'bin/ip$' \
                                     sh_in "$P1_HOST" sh -c 'command -v ip' 
  expect_out "no IPv4 address by default" '^$' \
      sh_in "$P1_HOST" sh -c "ip -4 -o addr show scope global | tr -d '\n'"

  echo
  info "P1 - image 2: $P1_ROUTER"
  expect     "node is running"                       test -n "$(node_pid "$P1_ROUTER")"
  expect_out "busybox is present"      'BusyBox'     sh_in "$P1_ROUTER" busybox

  # the four routing engines the subject enumerates
  for d in zebra bgpd ospfd isisd; do
      expect "$d is ACTIVE"            sh_in "$P1_ROUTER" pidof "$d"
  done
  expect_out "daemons file enables them" 'zebra=yes' \
                                         sh_in "$P1_ROUTER" cat /etc/frr/daemons

  # ... and that they are *configured*, not just running
  expect_out "bgpd is configured"   'router bgp 65001' \
      sh_in "$P1_ROUTER" vtysh -c 'show running-config'
  expect_out "ospfd is configured"  'router ospf' \
      sh_in "$P1_ROUTER" vtysh -c 'show running-config'
  expect_out "isisd is configured"  'router isis' \
      sh_in "$P1_ROUTER" vtysh -c 'show running-config'
  # the instance exists even with zero neighbours: it answers for the table
  expect_out "BGP instance is live" 'prefixes displayed|BGP table version' \
      sh_in "$P1_ROUTER" vtysh -c 'show ip bgp'
  expect_out "OSPF instance is live" 'Router ID: 1\.1\.1\.254' \
      sh_in "$P1_ROUTER" vtysh -c 'show ip ospf'
  expect_out "IS-IS instance is live" 'Area BADASS' \
      sh_in "$P1_ROUTER" vtysh -c 'show isis summary'

  # only the loopback carries the router-id; no ethernet port is addressed
  expect_out "no IPv4 address on the ethernet ports" '^$' \
      sh_in "$P1_ROUTER" sh -c "ip -4 -o addr show scope global | grep -v ': lo ' | tr -d '\n'"
  expect_out "router-id lives on the loopback" '1\.1\.1\.254/32' \
      sh_in "$P1_ROUTER" ip -4 -o addr show lo
}
