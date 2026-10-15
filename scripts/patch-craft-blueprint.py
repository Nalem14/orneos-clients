#!/usr/bin/env python3
"""Rebrands Nextcloud's KDE Craft recipe (craft-blueprints-nextcloud/nextcloud-client/nextcloud-client.py), which
names the Windows installer, its shortcuts and its uninstall entry. Idempotent; fails when the recipe changed shape.
Usage: patch-craft-blueprint.py <path to nextcloud-client.py>"""
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
src = path.read_text(encoding="utf-8")

# Upstream bug (stable-35.0): createPackage() uses os without importing it
if not re.search(r"^import os$", src, re.M):
    src = "import os\n" + src

REPLACEMENTS = [
    ('self.description = "Nextcloud Desktop Client"', 'self.description = "Orneos"'),
    ('self.displayName = "Nextcloud"', 'self.displayName = "Orneos"'),
    ('self.webpage = "https://nextcloud.com"', 'self.webpage = "https://orneos.eu"'),
    ('self.defines["appname"] = "nextcloud"', 'self.defines["appname"] = "orneos"'),
    ('self.defines["company"] = "Nextcloud GmbH"', 'self.defines["company"] = "Orneos"'),
    ('self.applicationExecutable = "nextcloud"', 'self.applicationExecutable = "orneos"'),  # APPLICATION_EXECUTABLE
]
for old, new in REPLACEMENTS:
    if new in src:
        continue
    if old not in src:
        sys.exit(f"upstream recipe changed: {old!r} not found in {path}")
    src = src.replace(old, new)

path.write_text(src, encoding="utf-8")
print(f"craft recipe rebranded: {path}")
