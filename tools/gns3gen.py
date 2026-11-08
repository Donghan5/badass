#!/usr/bin/env python3
"""
Generate GNS3 2.2 configuration from the topology described in this repo.

    gns3gen.py gui-config        -> ~/.config/GNS3/2.2/gns3_gui.conf
    gns3gen.py templates         -> ~/.config/GNS3/2.2/gns3_controller.conf
    gns3gen.py project P1        -> ~/GNS3/projects/P1/P1.gns3

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
    return "/bin/sh -c 'sh /badass/%s/%s; exec /bin/sh'" % (part, node)


def project_p1():
    """Part 1 diagram: one host, one router, no link."""
    host = "host_%s-1" % LOGIN
    router = "routeur_%s" % LOGIN
    return {
        "nodes": [
            docker_node(host, IMG_HOST, 2, SYM_HOST, -220, -60, 5000,
                        selfconfig("P1", host)),
            docker_node(router, IMG_ROUTER, 4, SYM_ROUTER, 40, -90, 5001,
                        selfconfig("P1", router)),
        ],
        "links": [],
    }


PROJECTS = {"P1": project_p1}


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
        out = project(argv[2])
    else:
        sys.exit("unknown command: %s" % cmd)
    json.dump(out, sys.stdout, indent=4, sort_keys=True)
    print()


if __name__ == "__main__":
    main(sys.argv)
