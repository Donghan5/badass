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
make p2          # static VXLAN: ping, FDB and packet inspection
make p2m         # multicast VXLAN, including multicast packet inspection
make p3          # staged EVPN learning, all host pairs and OSPF/VXLAN capture
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
P1/images/host/     image 1  (busybox end device)
P1/images/router/   image 2  (FRR router / VTEP)
lab/                 headless topology builder + checks
tools/gns3gen.py     generates GNS3 templates and project files
P1/ P2/ P3/          one commented configuration file per piece of equipment
```

The per-equipment files in `P1/`, `P2/` and `P3/` are the real thing: they are
baked into the images, executed by the GNS3 nodes *and* by the headless lab.
They are not documentation written after the fact.

---

## Addressing

All equipment names carry group member login `pzinurov`. Role prefixes make
the equipment easy to identify during evaluation: `host_` for end devices,
`routeur_` for routers and `Switch_` for the P2 underlay switch. The subject
requires a consistent name containing a member's login; leading underscores
in its examples are not required.

P3 uses `routeur_pzinurov-1` for the RR and `routeur_pzinurov-2..4` for VTEPs.
The node configuration filename, GNS3 node name and FRR hostname match.
P2's `_s` / `_g` configuration suffixes select static / multicast mode for
the same router. `P2-multicast` is a project name, not an equipment prefix;
the main static submission remains `P2/P2.gns3project`.

Renaming requires updating `lab/env.sh`, `tools/gns3gen.py`,
node configuration filenames and their internal references together, followed
by rebuilding images and exports; changing `LOGIN` alone is insufficient.

**P1** — one host, one router, no link.
`routeur_pzinurov` runs BGP AS 65001, OSPF and IS-IS area `49.0001`, all with
router-id `1.1.1.254` (a protocol identifier, not a loopback address).
No interface address: *"No IP address should be
configured by default."*

**P2** — VXLAN **VNI 10**, bridge `br0`, device `vxlan10`, UDP 4789.

| | |
|---|---|
| underlay | `10.1.1.0/24` — `routeur_pzinurov-1` `.1`, `routeur_pzinurov-2` `.2`, through `Switch_pzinurov` |
| overlay | `30.1.1.0/24` — `host_pzinurov-1` `.1`, `host_pzinurov-2` `.2` |
| static mode | `*_s` configs — `remote 10.1.1.x` |
| multicast mode | `*_g` configs — `group 239.1.1.1` |

**P3** — BGP EVPN, AS 1 (iBGP), `routeur_pzinurov-1` is the route reflector.

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
| P1 | headless checks: 20/20; main and auxiliary consoles use separate port pairs; no global IPv4 on any interface |
| P2 static | headless checks: 11/11, including bidirectional ping, remote MAC learning and VXLAN/ICMP capture |
| P2 multicast | headless checks: 12/12, including multicast VXLAN packets |
| P3 | headless checks: 22/22, covering OSPF, EVPN type 3, MAC-only type 2 reflection, all six directed host pairs and OSPF/VXLAN/ICMP capture |

Checks were run with rootless Podman in an isolated network namespace on the
development host. Generated topology JSON was also validated against GNS3
2.2.55 schemas. Portable images were restored into an empty Podman store, and
the generated P1 router startup was checked without mounting repository files.
GUI import/start inside the VirtualBox VM still needs checking;
the development host lacks `/dev/vboxdrv`.

`sudo /badass/lab/run.sh test p3` starts hosts with their access interfaces down,
waits for EVPN routes, then sends ARP probes from `0.0.0.0` to demonstrate MAC
learning without assigning IPv4. It finally applies host addresses and tests
connectivity. For manual staged inspection use `up p3 --staged`.

## Portable projects

`tools/gns3gen.py` defines the topologies. The submitted `P1/P1.gns3project`,
`P2/P2.gns3project`, `P2/P2-multicast.gns3project` and `P3/P3.gns3project` ZIPs
contain `project.gns3`, both actual Docker images and a `load-images.sh` restore
script. Duplicate uncompressed `.gns3` files are not kept in the repository;
VM provisioning generates its working copies under `~/GNS3/projects/`.

GNS3 2.2 skips Docker images in its normal `include_images` export. Our ZIPs
therefore carry `docker save` archives under `docker-images/`. Before importing
a portable project on a fresh machine, inside the VM:

```sh
unzip /badass/P1/P1.gns3project -d /tmp/badass-p1-import
sh /tmp/badass-p1-import/load-images.sh
# GNS3: File -> Import portable project -> /badass/P1/P1.gns3project
```

The same procedure applies to P2 and P3. For P3, start only routers first to
inspect type 3 routes. Hosts start in a shell without applying their IPv4
configuration; later run `sh /badass/P3/host_pzinurov-N` in each host console.
Routers use `routeur_pzinurov-N` consistently in configuration filenames,
GNS3 node names and FRR hostnames.

After changing node configurations, rebuild images before exporting:

```sh
make images
make export-all
# Or inside the VM:
python3 /badass/tools/portable.py verify /badass/P1/P1.gns3project
```

Exports use `gns3gen.py` definitions, not manual GUI edits. Verification checks
topology consistency, ZIP integrity and image manifests/configuration/layers.
`.dockerignore` keeps exported images out of subsequent Docker build contexts.

### Notes from building it

Three things that cost real time and are worth remembering:

* **FRR 10 needs `mgmtd`.** Since FRR 9/10 the `interface … / ip address …`
  configuration is owned by `mgmtd`, not `zebra`. Without it every interface
  address in `frr.conf` is silently dropped — `vtysh -b` reports success and
  the address simply never appears. `P1/images/router/daemons` starts it first.
* **busybox `pgrep -x` matches the whole command line**, not the process name,
  so `pgrep -x zebra` never matches `/usr/lib/frr/zebra -d …`. The image uses
  `pidof` instead.
* **GNS3 validates `container_id`** as a real docker id, so a node with
  `"container_id": ""` is rejected with a schema error at project open.
  `tools/gns3gen.py` omits the key.
