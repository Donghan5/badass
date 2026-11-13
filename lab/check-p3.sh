#!/bin/bash
# Run against p3_up --staged: hosts initially have down/unaddressed access ports.
evpn_routes() {
  sh_in "$1" vtysh -c 'show bgp l2vpn evpn' | grep -E '^ [* >is]+\[[23]\]:' || true
}

fabric_ready() {
  sh_in "$P3_RR" vtysh -c 'show bgp l2vpn evpn summary json' |
    python3 -c 'import json,sys; p=json.load(sys.stdin).get("peers",{}); sys.exit(not (len(p)==3 and all(v.get("state")=="Established" for v in p.values())))'
}

route_present() { evpn_routes "$1" | grep -Fq "$2"; }

check_p3() {
  local n mac routes capture pid src dst
  expect "three EVPN sessions established on RR" retry 60 fabric_ready
  expect_out "RR has three FULL OSPF neighbors" '^3$' \
    sh -c '"$@" | grep -c "Full/"' sh \
    "$DOCKER" exec "$(container_name "$P3_RR")" vtysh -c 'show ip ospf neighbor'
  for n in 2 3 4; do
    expect "type 3 route from VTEP 1.1.1.$n" retry 20 route_present "$P3_RR" "[3]:[0]:[32]:[1.1.1.$n]"
  done
  routes=$(evpn_routes "$P3_RR")
  expect "no type 2 route before host activation" test "${routes#*\[2\]}" = "$routes"
  for n in "$P3_L2" "$P3_L3" "$P3_L4"; do
    expect_out "$n: VNI 10 without data-plane learning" 'vxlan id 10 .*nolearning' \
      sh_in "$n" ip -d link show vxlan10
  done

  # ARP DAD probes use sender IP 0.0.0.0; they generate Ethernet frames without
  # assigning IPv4 to the host. Merely opening a console need not send a frame.
  sh_in "$P3_H1" ip link set eth1 up
  expect "unaddressed host sends Ethernet probes" sh_in "$P3_H1" arping -D -I eth1 -c 2 20.1.1.250
  expect_out "host 1 still has no global IPv4" '^$' \
    sh_in "$P3_H1" sh -c "ip -4 -o addr show scope global | tr -d '\n'"
  mac=$(sh_in "$P3_H1" cat /sys/class/net/eth1/address)
  expect "RR learns MAC-only type 2" retry 15 route_present "$P3_RR" "[2]:[0]:[48]:[$mac]"
  expect "remote VTEP learns reflected type 2" retry 15 route_present "$P3_L4" "[2]:[0]:[48]:[$mac]"

  for n in "$P3_H1" "$P3_H2" "$P3_H3"; do apply "$n" "P3/$n"; done
  capture=$(mktemp)
  sh_in "$P3_RR" timeout 15 tcpdump -l -nn -vv -i eth0 'udp port 4789 or ip proto 89' > "$capture" 2>&1 &
  pid=$!
  sleep 1
  for src in 1 2 3; do
    for dst in 1 2 3; do
      [ "$src" != "$dst" ] || continue
      expect "host $src reaches host $dst" retry 10 sh_in "host_${LOGIN}-$src" ping -c 1 -W 1 "20.1.1.$dst"
    done
  done
  wait "$pid" || true
  expect_out "capture contains VXLAN VNI 10" 'vni 10' cat "$capture"
  expect_out "capture contains encapsulated ICMP" 'ICMP echo' cat "$capture"
  expect_out "capture contains OSPF" 'OSPFv2' cat "$capture"
  rm -f "$capture"
}
