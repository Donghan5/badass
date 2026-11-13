#!/bin/bash
# Exercise both the VXLAN data plane and the packets visible on the underlay.
check_p2() {
  local mode=${1:-static} n mac capture pid
  for n in "$P2_R1" "$P2_R2"; do
    expect_out "$n: VNI 10 and UDP 4789" 'vxlan id 10 .*dstport 4789' \
      sh_in "$n" ip -d link show vxlan10
    expect_out "$n: VXLAN attached to br0" 'master br0' \
      sh_in "$n" ip link show vxlan10
    if [ "$mode" = multicast ]; then
      expect_out "$n: multicast group" 'group 239\.1\.1\.1' \
        sh_in "$n" ip -d link show vxlan10
    else
      expect_out "$n: static remote VTEP" 'remote 10\.1\.1\.[12]' \
        sh_in "$n" ip -d link show vxlan10
    fi
  done

  capture=$(mktemp)
  sh_in "$P2_R1" timeout 12 tcpdump -l -nn -vv -i eth0 'udp port 4789' > "$capture" 2>&1 &
  pid=$!
  sleep 1
  sh_in "$P2_H1" ip neigh flush dev eth1
  expect "host 1 reaches host 2" retry 8 sh_in "$P2_H1" ping -c 1 -W 1 30.1.1.2
  expect "host 2 reaches host 1" sh_in "$P2_H2" ping -c 2 -W 1 30.1.1.1
  mac=$(sh_in "$P2_H2" cat /sys/class/net/eth1/address)
  expect_out "remote host MAC learned in VXLAN FDB" "$mac.*dst 10\.1\.1\.2" \
    sh_in "$P2_R1" bridge fdb show dev vxlan10
  wait "$pid" || true  # timeout terminates the capture after 12 seconds
  expect_out "capture contains VXLAN VNI 10" 'vni 10' cat "$capture"
  expect_out "capture contains encapsulated ICMP" 'ICMP echo' cat "$capture"
  if [ "$mode" = multicast ]; then
    expect_out "capture contains multicast VXLAN traffic" '239\.1\.1\.1\.4789' cat "$capture"
  fi
  rm -f "$capture"
}
