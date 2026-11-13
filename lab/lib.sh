#!/bin/bash
# ---------------------------------------------------------------------------
# BADASS - headless lab plumbing.
#
# GNS3 draws a topology and then builds it out of docker containers whose
# interfaces are wired together by ubridge.  These helpers do the same thing
# with plain docker + veth pairs, so the exact same images and the exact same
# per-node configuration files from P1/P2/P3 can be booted and tested without
# opening a GUI.  What you validate here is what you import into GNS3.
# ---------------------------------------------------------------------------
set -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
# shellcheck source=env.sh
. "$HERE/env.sh"

DOCKER=${DOCKER:-docker}
LABEL=badass.lab                 # every container we create is tagged with it
LINK_N=0                         # veth pair counter (interface names are capped at 15 chars)

c_red()  { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
info()   { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
step()   { printf '    \033[36m-\033[0m %s\n' "$*"; }

die() { c_red "ERROR: $*" >&2; exit 1; }

need_root() {
  [ "$(id -u)" -eq 0 ] || die "this lab manipulates netns/veth, run it as root (sudo)"
}

# --------------------------------------------------------------------------
# containers
# --------------------------------------------------------------------------

# node_start <name> <image>
# --network none  : GNS3 does the same, no IP address is configured by default
# --privileged    : the node must be able to create bridges/vxlan in its netns
container_name() { printf 'badass-%s' "$1"; }

node_start() {
  local name=$1 image=$2
  local container
  container=$(container_name "$name")
  $DOCKER rm -f "$container" >/dev/null 2>&1 || true
  $DOCKER run -d --name "$container" --hostname "$name" \
      --label "$LABEL=1" \
      --privileged --network none \
      --cap-add=ALL \
      -v "$REPO:$REPO_MNT:ro" \
      "$image" sleep infinity >/dev/null \
    || die "cannot start $name from $image"
  step "node $name ($image)"
}

node_pid() { $DOCKER inspect -f '{{.State.Pid}}' "$(container_name "$1")" 2>/dev/null; }

# nsx <node> <cmd...>   run a command in the node's network namespace (host fs)
nsx() { local n=$1; shift; nsenter -t "$(node_pid "$n")" -n -- "$@"; }

# sh_in <node> <cmd...> run a command *inside* the container
sh_in() { local n=$1; shift; $DOCKER exec "$(container_name "$n")" "$@"; }

# apply <node> <config-file-relative-to-repo> [args...]
# runs one of the committed P1/P2/P3 node configuration files inside the node
apply() {
  local n=$1 cfg=$2; shift 2
  step "apply $cfg -> $n"
  sh_in "$n" sh "$REPO_MNT/$cfg" "$@" \
    || die "config $cfg failed on $n"
}

# --------------------------------------------------------------------------
# cabling
# --------------------------------------------------------------------------

# link <nodeA> <ethA> <nodeB> <ethB> [down] -- optionally leave side B down
link() {
  local a=$1 ia=$2 b=$3 ib=$4
  local pa pb ta tb
  pa=$(node_pid "$a"); pb=$(node_pid "$b")
  [ -n "$pa" ] && [ -n "$pb" ] || die "link $a:$ia <-> $b:$ib : node not running"
  LINK_N=$((LINK_N + 1))
  ta="vth${LINK_N}a"; tb="vth${LINK_N}b"
  ip link add "$ta" type veth peer name "$tb"
  ip link set "$ta" netns "$pa"
  ip link set "$tb" netns "$pb"
  nsx "$a" ip link set "$ta" name "$ia"
  nsx "$b" ip link set "$tb" name "$ib"
  nsx "$a" ip link set "$ia" up
  nsx "$b" ip link set "$ib" "${5:-up}"
  step "cable $a:$ia <-> $b:$ib"
}

# switch_add <name>  -- a dumb L2 switch, i.e. a linux bridge in the VM itself.
# multicast_snooping is turned OFF so the bridge floods multicast exactly like
# the unmanaged "Ethernet switch" GNS3 drops on the canvas; without that, the
# dynamic-multicast VXLAN of part 2 would be silently dropped for lack of an
# IGMP querier.
switch_add() {
  local sw=$1
  ip link del "$sw" 2>/dev/null || true
  ip link add "$sw" type bridge mcast_snooping 0 stp_state 0
  ip link set "$sw" up
  step "switch $sw (linux bridge, multicast flooding)"
}

# switch_port <switch> <node> <eth>   -- plug a node interface into the switch
switch_port() {
  local sw=$1 n=$2 i=$3 p t
  p=$(node_pid "$n"); [ -n "$p" ] || die "switch_port: $n not running"
  LINK_N=$((LINK_N + 1))
  t="vsw${LINK_N}"
  ip link add "$t" type veth peer name "${t}p"
  ip link set "$t" master "$sw" up
  ip link set "${t}p" netns "$p"
  nsx "$n" ip link set "${t}p" name "$i"
  nsx "$n" ip link set "$i" up
  step "cable $n:$i <-> $sw"
}

# --------------------------------------------------------------------------
# teardown
# --------------------------------------------------------------------------
lab_down() {
  local ids
  ids=$($DOCKER ps -aq --filter "label=$LABEL=1" 2>/dev/null)
  if [ -n "$ids" ]; then
    # shellcheck disable=SC2086
    $DOCKER rm -f $ids >/dev/null 2>&1 || true
    info "removed $(echo "$ids" | wc -l) lab container(s)"
  fi
  for sw in $(ip -o link show type bridge 2>/dev/null | awk -F': ' '{print $2}' | grep -E "^(Switch|sw)_" || true); do
    ip link del "$sw" 2>/dev/null || true
  done
}

# --------------------------------------------------------------------------
# test harness
# --------------------------------------------------------------------------
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); c_grn  "  PASS  $*"; }
ko()   { FAIL=$((FAIL+1)); c_red  "  FAIL  $*"; }

# expect <description> <command...>   -- command must succeed
expect() {
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi
}

# expect_out <description> <regex> <command...>  -- output must match regex
expect_out() {
  local d=$1 re=$2; shift 2
  local out
  # "|| true": a probe returning non-zero is a failed check, not a reason to
  # abort the whole run (run.sh is set -e)
  out=$("$@" 2>&1) || true
  if printf '%s\n' "$out" | grep -Eq "$re"; then
    ok "$d"
  else
    ko "$d"
    printf '        expected /%s/ in:\n' "$re"
    printf '%s\n' "$out" | sed 's/^/        | /' | head -20
  fi
}

# retry <seconds> <command...>  -- poll until the command succeeds
retry() {
  local t=$1; shift
  local end=$(( $(date +%s) + t ))
  while [ "$(date +%s)" -lt "$end" ]; do
    "$@" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

summary() {
  echo
  if [ "$FAIL" -eq 0 ]; then
    c_grn "================  $PASS/$((PASS+FAIL)) checks passed  ================"
  else
    c_red "================  $FAIL/$((PASS+FAIL)) checks FAILED  ================"
  fi
  [ "$FAIL" -eq 0 ]
}
