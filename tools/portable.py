#!/usr/bin/env python3
"""Export gns3gen definitions with Docker images, or verify existing ZIPs.

GNS3 2.2 skips Docker images with include_images=yes. Our portable ZIPs carry
docker-save archives and a restore script to run before importing into GNS3.
GUI edits are not exported: the committed configurations are the source.
"""
import argparse
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import zipfile

import gns3gen

REPO = Path(__file__).resolve().parent.parent
IMAGES = {"host": gns3gen.IMG_HOST, "router": gns3gen.IMG_ROUTER}
RESTORE = '''#!/bin/sh
set -eu
cd "$(dirname "$0")"
docker load -i docker-images/host.tar
docker load -i docker-images/router.tar
for name in host router; do
    docker image inspect "badass/$name:latest" >/dev/null
done
echo "Images loaded. Import the original .gns3project file in GNS3."
'''


def normalize_tags(path, image):
    """Docker must load the short image tag even when Podman saved localhost/."""
    normalized = path.with_suffix(".normalized.tar")
    with tarfile.open(path) as source, tarfile.open(normalized, "w") as target:
        for member in source:
            data = source.extractfile(member) if member.isfile() else None
            if member.name == "manifest.json":
                manifest = json.load(data)
                if len(manifest) != 1:
                    raise ValueError("Expected a single-image Docker save archive")
                manifest[0]["RepoTags"] = [image]
                content = json.dumps(manifest).encode()
                member.size = len(content)
                data = io.BytesIO(content)
            target.addfile(member, data)
    os.replace(normalized, path)


def verify(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP integrity check failed")
        project = json.loads(archive.read("project.gns3"))
        if project != gns3gen.project(project["name"]):
            raise ValueError("Topology differs from the source-defined project")
        for name, image in IMAGES.items():
            members, manifest = {}, None
            with archive.open(f"docker-images/{name}.tar") as stream:
                with tarfile.open(fileobj=stream, mode="r|") as saved:
                    for member in saved:
                        members[member.name] = member.size
                        if member.name == "manifest.json":
                            manifest = json.load(saved.extractfile(member))
            if not manifest:
                raise ValueError(f"{image}: missing Docker save manifest")
            entries = [entry for entry in manifest
                       if {image, "localhost/" + image}.intersection(entry.get("RepoTags") or [])]
            if not entries:
                raise ValueError(f"{image}: missing image tag")
            for entry in entries:
                required = [entry["Config"], *entry["Layers"]]
                if not entry["Layers"] or any(members.get(item, 0) == 0 for item in required):
                    raise ValueError(f"{image}: missing image configuration or layers")
        if archive.read("load-images.sh").decode() != RESTORE:
            raise ValueError("Missing image restore script")
    print(f"Verified topology, ZIP integrity and Docker image contents: {path}")


def export(names, docker):
    with tempfile.TemporaryDirectory(prefix="badass-export-") as work:
        work = Path(work)
        for name, image in IMAGES.items():
            subprocess.run([docker, "image", "save", "-o", str(work / f"{name}.tar"), image],
                           check=True)
            normalize_tags(work / f"{name}.tar", image)
        for name in names:
            output = REPO / name.split("-")[0] / f"{name}.gns3project"
            topology = json.dumps(gns3gen.project(name), indent=4, sort_keys=True) + "\n"
            fd, temporary = tempfile.mkstemp(prefix=f".{name}-", suffix=".tmp", dir=output.parent)
            os.close(fd)
            try:
                with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr("project.gns3", topology)
                    for image in IMAGES:
                        archive.write(work / f"{image}.tar", f"docker-images/{image}.tar")
                    archive.writestr("load-images.sh", RESTORE)
                    archive.writestr("IMPORT.txt",
                                      "Inside the VM, unzip this archive into a temporary directory.\n"
                                      "Run: sh load-images.sh\n"
                                      "Then import the original .gns3project file in GNS3.\n"
                                      "P3: start routers first; hosts start without IPv4 addresses.\n")
                verify(temporary)
                os.replace(temporary, output)
            finally:
                Path(temporary).unlink(missing_ok=True)
            print(f"Exported: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("export")
    build.add_argument("projects", nargs="+", choices=list(gns3gen.PROJECTS))
    build.add_argument("--docker", default=os.environ.get("DOCKER", "docker"))
    check = sub.add_parser("verify")
    check.add_argument("archives", nargs="+", type=Path)
    args = parser.parse_args()
    if args.command == "export":
        export(args.projects, args.docker)
    else:
        for path in args.archives:
            verify(path)


if __name__ == "__main__":
    main()
