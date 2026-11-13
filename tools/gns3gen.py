#!/usr/bin/env python3
"""
Generate GNS3 2.2 configuration from the topology described in this repo.

    gns3gen.py gui-config        -> ~/.config/GNS3/2.2/gns3_gui.conf
    gns3gen.py templates         -> ~/.config/GNS3/2.2/gns3_controller.conf
    gns3gen.py project P1        -> ~/GNS3/projects/P1/P1.gns3
    gns3gen.py project P2        -> static VXLAN topology
    gns3gen.py project P2-multicast -> multicast VXLAN topology
    gns3gen.py project P3        -> OSPF + BGP EVPN fabric (hosts unaddressed)

Why generate instead of clicking: the topology, the node names, the port
numbers and the image names all have to match the configuration files
committed in P1/ P2/ P3.  Describing them once, here, keeps the GNS3 canvas
and the headless lab in sync.

All identifiers are uuid5-derived, so running this twice produces the exact
same file and re-provisioning never duplicates a template.
"""
import json
import sys
import uuid

LOGIN = "pzinurov"
NS = uuid.UUID("badabada-0000-4000-8000-000000000000")
GNS3_VERSION = "2.2.55"

IMG_HOST = "badass/host:latest"
IMG_ROUTER = "badass/router:latest"

SYM_HOST = ":/symbols/docker_guest.svg"
SYM_ROUTER = ":/symbols/multilayer_switch.svg"


def uid(*parts):
    return str(uuid.uuid5(NS, "/".join(str(p) for p in parts)))


def label(text, y=-25):
    return {
        "rotation": 0,
        "style": ("font-family: TypeWriter;font-size: 10.0;font-weight: bold;"
                  "fill: #000000;fill-opacity: 1.0;"),
        "text": text,
        "x": None,
        "y": y,
    }


# ---------------------------------------------------------------- templates --
def docker_template(name, image, adapters, symbol, name_format, usage):
    return {
        "adapters": adapters,
        "builtin": False,
        "category": "guest",
        "compute_id": "local",
        "console_auto_start": False,
        "console_http_path": "/",
        "console_http_port": 80,
        "console_resolution": "1024x768",
        "console_type": "telnet",
        "custom_adapters": [],
        "default_name_format": name_format,
        "environment": "",
        "extra_hosts": "",
        "extra_volumes": [],
        "image": image,
        "name": name,
        "start_command": "",
        "symbol": symbol,
        "template_id": uid("template", name),
        "template_type": "docker",
        "usage": usage,
    }


def templates():
    return {
        "templates": [
            docker_template(
                "badass host", IMG_HOST, 2, SYM_HOST,
                "host_%s-{0}" % LOGIN,
                "End device (alpine = busybox). No IP address is configured "
                "by default: run  sh /badass/P<n>/<node name>  in the console.",
            ),
            docker_template(
                "badass router", IMG_ROUTER, 4, SYM_ROUTER,
                "routeur_%s-{0}" % LOGIN,
                "FRRouting node: zebra + bgpd + ospfd + isisd. No IP address "
                "is configured by default: run  sh /badass/P<n>/<node name>.",
            ),
        ],
        "version": GNS3_VERSION,
    }


def gui_config():
    return {
        "MainWindow": {
            "hide_getting_started_dialog": True,
            "hide_setup_wizard": True,
            "hide_new_template_button": False,
            "check_for_update": False,
            "send_stats": False,
            "default_local_server_path": "/usr/bin/gns3server",
        },
        "Servers": {
            "local_server": {
                "auto_start": True,
                "allow_console_from_anywhere": False,
                "host": "127.0.0.1",
                "images_path": "/home/vagrant/GNS3/images",
                "path": "/usr/bin/gns3server",
                "port": 3080,
                "projects_path": "/home/vagrant/GNS3/projects",
                "protocol": "http",
                "report_errors": False,
                "ubridge_path": "/usr/bin/ubridge",
            },
            "remote_servers": [],
        },
        "Dynamips": {"allocate_aux_console_ports": False},
        "version": GNS3_VERSION,
    }


# ----------------------------------------------------------------- topology --
def docker_node(name, image, adapters, symbol, x, y, console, start_command=""):
    return {
        "compute_id": "local",
        "console": console,
        "console_auto_start": False,
        "console_type": "telnet",
        "custom_adapters": [],
        "first_port_name": None,
        "height": 59,
        "label": label(name),
        "locked": False,
        "name": name,
        "node_id": uid("node", name),
        "node_type": "docker",
        "port_name_format": "eth{0}",
        "port_segment_size": 0,
        "properties": {
            "adapters": adapters,
            # Docker nodes need both a main console and an auxiliary console.
            # Reserve adjacent pairs; callers must leave the next port free.
            "aux": console + 1,
            "console_http_path": "/",
            "console_http_port": 80,
            "console_resolution": "1024x768",
            # no container_id key on purpose: GNS3 validates it as a real
            # docker id (minLength), so sending an empty one is rejected
            "environment": "",
            "extra_hosts": "",
            "extra_volumes": [],
            "image": image,
            "start_command": start_command,
            "usage": "",
        },
        "symbol": symbol,
        "width": 65,
        "x": x,
        "y": y,
        "z": 1,
    }


def selfconfig(part, node):
    """Start command that applies the node's own committed config, then drops
    into a shell, so pressing Play in GNS3 is enough to build the part."""
    return "/bin/sh -c 'sh /badass/%s/%s && exec /bin/sh'" % (part, node)


def project_p1():
    """Part 1 diagram: one host, one router, no link."""
    host = "host_%s-1" % LOGIN
    router = "routeur_%s" % LOGIN
    return {
        "nodes": [
            docker_node(host, IMG_HOST, 2, SYM_HOST, -220, -60, 5000,
                        selfconfig("P1", host)),
            docker_node(router, IMG_ROUTER, 4, SYM_ROUTER, 40, -90, 5002,
                        selfconfig("P1", router)),
        ],
        "links": [],
    }

def ethernet_switch(name, x, y, ports=2):
    """Built-in GNS3 switch: all ports are access ports in VLAN 1."""
    return {
        "compute_id": "local",
        "console": None,
        "console_type": "none",
        "height": 32,
        "label": label(name),
        "name": name,
        "node_id": uid("node", name),
        "node_type": "ethernet_switch",
        "port_name_format": "Ethernet{0}",
        "properties": {
            "ports_mapping": [
                {"name": f"Ethernet{i}", "port_number": i,
                 "type": "access", "vlan": 1}
                for i in range(ports)
            ],
        },
        "symbol": ":/symbols/ethernet_switch.svg",
        "width": 72,
        "x": x,
        "y": y,
        "z": 1,
    }


def link(node_a, adapter_a, node_b, adapter_b):
    """Docker ethN uses adapter N/port 0; switch port N uses adapter 0/port N."""
    def endpoint(node, adapter):
        switch = node["node_type"] == "ethernet_switch"
        return {
            "node_id": node["node_id"],
            "adapter_number": 0 if switch else adapter,
            "port_number": adapter if switch else 0,
        }

    return {
        "link_id": uid("link", node_a["node_id"], adapter_a,
                       node_b["node_id"], adapter_b),
        "nodes": [endpoint(node_a, adapter_a), endpoint(node_b, adapter_b)],
        "suspend": False,
    }


def project_p2(mode="static"):
    """Two hosts and two VTEPs connected through an underlay switch."""
    if mode not in ("static", "multicast"):
        raise ValueError("P2 mode must be static or multicast")
    suffix = "_s" if mode == "static" else "_g"
    console_base = 5010 if mode == "static" else 5040
    hosts = [f"host_{LOGIN}-{i}" for i in (1, 2)]
    routers = [f"routeur_{LOGIN}-{i}" for i in (1, 2)]
    h1, h2 = [
        docker_node(name, IMG_HOST, 2, SYM_HOST, -400, y, console,
                    selfconfig("P2", name))
        for name, y, console in zip(hosts, (-150, 150), (console_base, console_base + 2))
    ]
    r1, r2 = [
        docker_node(name, IMG_ROUTER, 2, SYM_ROUTER, -100, y, console,
                    selfconfig("P2", name + suffix))
        for name, y, console in zip(routers, (-150, 150), (console_base + 4, console_base + 6))
    ]
    switch = ethernet_switch(f"Switch_{LOGIN}", 200, 0)
    return {
        "nodes": [h1, h2, r1, r2, switch],
        "links": [
            link(h1, 1, r1, 1),
            link(h2, 1, r2, 1),
            link(r1, 0, switch, 0),
            link(r2, 0, switch, 1),
        ],
    }


def project_p3():
    """One RR and three VTEPs; hosts start without applying their IP configs.

    Start only the routers first for the type-3-only evaluation stage.
    Later, apply sh /badass/P3/host_<login>-N in each host console to add IPv4.
    """
    rr_name = f"routeur_{LOGIN}-1"
    rr = docker_node(rr_name, IMG_ROUTER, 3, SYM_ROUTER, 0, -250, 5020,
                     selfconfig("P3", rr_name))
    leaves = [
        docker_node(f"routeur_{LOGIN}-{i}", IMG_ROUTER, 3, SYM_ROUTER,
                    x, 0, console, selfconfig("P3", f"routeur_{LOGIN}-{i}"))
        for i, x, console in zip((2, 3, 4), (-300, 0, 300), (5022, 5024, 5026))
    ]
    hosts = [
        docker_node(f"host_{LOGIN}-{i}", IMG_HOST, 2, SYM_HOST,
                    x, 250, console, "/bin/sh")
        for i, x, console in zip((1, 2, 3), (-300, 0, 300), (5028, 5030, 5032))
    ]
    # Match lab/topo-p3.sh and the interfaces used in the committed configs.
    return {
        "nodes": [rr, *leaves, *hosts],
        "links": [
            link(rr, 0, leaves[0], 0),
            link(rr, 1, leaves[1], 1),
            link(rr, 2, leaves[2], 2),
            link(leaves[0], 1, hosts[0], 1),
            link(leaves[1], 0, hosts[1], 0),
            link(leaves[2], 0, hosts[2], 0),
        ],
    }


PROJECTS = {
    "P1": project_p1,
    "P2": project_p2,
    "P2-multicast": lambda: project_p2("multicast"),
    "P3": project_p3,
}


def project(name):
    topo = PROJECTS[name]()
    return {
        "auto_close": True,
        "auto_open": False,
        "auto_start": False,
        "drawing_grid_size": 25,
        "grid_size": 75,
        "name": name,
        "project_id": uid("project", name),
        "revision": 9,
        "scene_height": 1000,
        "scene_width": 2000,
        "show_grid": False,
        "show_interface_labels": True,
        "show_layers": False,
        "snap_to_grid": False,
        "supplier": None,
        "topology": {
            "computes": [],
            "drawings": [],
            "links": topo["links"],
            "nodes": topo["nodes"],
        },
        "type": "topology",
        "variables": None,
        "version": GNS3_VERSION,
        "zoom": 100,
    }


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "templates":
        out = templates()
    elif cmd == "gui-config":
        out = gui_config()
    elif cmd == "project":
        if len(argv) != 3 or argv[2] not in PROJECTS:
            sys.exit("usage: gns3gen.py project {%s}" % ",".join(PROJECTS))
        out = project(argv[2])
    else:
        sys.exit("unknown command: %s" % cmd)
    json.dump(out, sys.stdout, indent=4, sort_keys=True)
    print()


if __name__ == "__main__":
    main(sys.argv)
