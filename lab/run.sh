#!/bin/bash
# ===========================================================================
#  BADASS headless lab driver.
#
#      sudo ./lab/run.sh up    p1          build the topology
#      sudo ./lab/run.sh check p1          run the subject's checks on it
#      sudo ./lab/run.sh test  p1          up + check
#      sudo ./lab/run.sh down               tear everything down
#      sudo ./lab/run.sh shell <node>       drop into a node
#      sudo ./lab/run.sh ps                 what is running
#
#  Same images and same configuration files as the GNS3 projects; this is the
#  fast way to know a part works before drawing it on a canvas.
# ===========================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
. "$HERE/topo-p1.sh"
. "$HERE/topo-p2.sh"
. "$HERE/topo-p3.sh"
. "$HERE/check-p1.sh"

usage() { sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

part_up() {
  case "$1" in
    p1)  p1_up ;;
    p2)  p2_up static ;;
    p2m) p2_up multicast ;;
    p3)  p3_up ${2:-} ;;
    *)   die "unknown part '$1' (p1 | p2 | p2m | p3)" ;;
  esac
}

part_check() {
  case "$1" in
    p1)  check_p1 ;;
    *)   die "no checks wired for '$1' yet" ;;
  esac
  summary
}

cmd=${1:-}; shift || true
case "$cmd" in
  up)    need_root; lab_down; part_up "${1:?part}" "${2:-}" ;;
  check) need_root; part_check "${1:?part}" ;;
  test)  need_root; lab_down; part_up "${1:?part}" "${2:-}"; part_check "$1" ;;
  down)  need_root; lab_down ;;
  shell) need_root; exec $DOCKER exec -it "${1:?node}" /bin/sh ;;
  ps)    $DOCKER ps --filter "label=$LABEL=1" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' ;;
  *)     usage ;;
esac
