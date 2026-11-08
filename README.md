# BADASS — BGP At Doors of Autonomous Systems is Simple

Network lab for the 42 *BADASS* subject: GNS3 + Docker, a VXLAN, and a small
BGP EVPN data centre.

The whole environment is described in code. There is no "install Ubuntu in
VirtualBox, click next, remember what you did" step:

```sh
make up        # builds the VM and opens a VirtualBox window with GNS3 running
```

---

## What `make up` gives you

A VirtualBox VM (`bento/ubuntu-22.04`, 4 vCPU / 4 GB) that boots straight into
an XFCE desktop with **GNS3 already open**, and inside it:

| | |
|---|---|
| Docker engine | the backend GNS3 builds its nodes from |
| `badass/host:latest` | image 1 — alpine (= busybox), no IP by default |
| `badass/router:latest` | image 2 — alpine + FRRouting: `zebra`, `bgpd`, `ospfd`, `isisd` |
| GNS3 templates | *badass host* and *badass router*, ready in the device list |
| GNS3 project **P1** | already contains `host_pzinurov-1` and `routeur_pzinurov` |
| `/badass` | this repository, shared with your host — edit configs here |

The subject requires the project to be done **inside a VM**; it is. The VM is
just reproducible instead of hand-made.

### Host-side commands

```sh
make up          # build + boot (first run downloads ~700 MB and takes a while)
make gui         # re-open the VM window
make ssh         # shell in the VM
make p1          # run the part 1 checks, no GUI needed
make halt        # stop   /   make destroy   to throw it away
```

---

## Two ways to run a part

**1. GNS3 (the deliverable).** Open the `P1` project, press ▶. Each node runs
its own committed configuration file at start-up, so the topology comes up
configured. Right-click → *Console* to get a shell.

**2. The headless lab (the fast loop).** The same images and the *same*
configuration files, wired with plain `veth` pairs instead of ubridge:

```sh
vagrant ssh
sudo /badass/lab/run.sh test p1     # build it, then check it
sudo /badass/lab/run.sh shell routeur_pzinurov
sudo /badass/lab/run.sh down
```

This is what keeps the project honest: a part is "done" when `run.sh test`
goes green, not when the canvas looks right.

---

## Layout

```
Vagrantfile          the VM
provision/           how the VM is built, step by step
images/host/         image 1  (busybox end device)
images/router/       image 2  (FRR router / VTEP)
lab/                 headless topology builder + checks
tools/gns3gen.py     generates GNS3 templates and project files
P1/ P2/ P3/          one commented configuration file per piece of equipment
```

The per-equipment files in `P1/`, `P2/` and `P3/` are the real thing: they are
baked into the images, executed by the GNS3 nodes *and* by the headless lab.
They are not documentation written after the fact.

---

## Addressing

All equipment names carry the login, as the subject requires (`pzinurov`;
change `LOGIN` in `lab/env.sh` and regenerate).

**P1** — one host, one router, no link.
`routeur_pzinurov` runs BGP AS 65001, OSPF and IS-IS area `49.0001`, all with
router-id `1.1.1.254`. No interface address: *"No IP address should be
configured by default."*

**P2** — VXLAN **VNI 10**, bridge `br0`, device `vxlan10`, UDP 4789.

| | |
|---|---|
| underlay | `10.1.1.0/24` — `routeur_pzinurov-1` `.1`, `routeur_pzinurov-2` `.2`, through `Switch_pzinurov` |
| overlay | `30.1.1.0/24` — `host_pzinurov-1` `.1`, `host_pzinurov-2` `.2` |
| static mode | `*_s` configs — `remote 10.1.1.x` |
| multicast mode | `*_g` configs — `group 239.1.1.1` |

**P3** — BGP EVPN, AS 1 (iBGP), `_pzinurov-1` is the route reflector.

| | |
|---|---|
| loopbacks | `1.1.1.1` (RR) … `1.1.1.4`, advertised by OSPF area 0 |
| p2p links | `10.1.1.0/30`, `10.1.1.4/30`, `10.1.1.8/30` |
| overlay | `20.1.1.0/24` on VNI 10, `host_pzinurov-1..3` = `.1 .2 .3` |
| VTEP source | the loopback — the tunnel survives any underlay reroute |

---

## Status

| part | state |
|---|---|
| **P1** | **done and verified** — images build, GNS3 templates + project generated, nodes boot and self-configure inside GNS3, `run.sh test p1` is 20/20 |
| P2 | configuration files written and commented, topology builder ready; not verified yet |
| P3 | configuration files written and commented, topology builder ready; not verified yet |

`sudo /badass/lab/run.sh up p2` (or `p2m`, `p3`) brings those topologies up for
hand inspection. Their automated checks, the GNS3 projects and the
`.gns3project` exports are the next step.

### Notes from building it

Three things that cost real time and are worth remembering:

* **FRR 10 needs `mgmtd`.** Since FRR 9/10 the `interface … / ip address …`
  configuration is owned by `mgmtd`, not `zebra`. Without it every interface
  address in `frr.conf` is silently dropped — `vtysh -b` reports success and
  the address simply never appears. `images/router/daemons` starts it first.
* **busybox `pgrep -x` matches the whole command line**, not the process name,
  so `pgrep -x zebra` never matches `/usr/lib/frr/zebra -d …`. The image uses
  `pidof` instead.
* **GNS3 validates `container_id`** as a real docker id, so a node with
  `"container_id": ""` is rejected with a schema error at project open.
  `tools/gns3gen.py` omits the key.
