#!/usr/bin/env python3
"""Rebrands Nextcloud's KDE Craft recipe (craft-blueprints-nextcloud/nextcloud-client/), which builds the Windows
installer: its name, icon, shortcuts, uninstall entry, and the blacklist that decides which .exe files it ships.
Idempotent; fails when the recipe changed shape.
Usage: patch-craft-blueprint.py <path to nextcloud-client.py> <installer .ico>"""
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
icon = pathlib.Path(sys.argv[2]).resolve()
if not icon.is_file():
    sys.exit(f"installer icon not found: {icon}")
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

# Installer icon (Craft's own by default)
ICON_ANCHOR = 'self.applicationExecutable = "orneos"'
icon_line = f'self.defines["icon"] = r"{icon}"'
if icon_line not in src:
    src = re.sub(r'\n\s*self\.defines\["icon"\] = r".*"', "", src)
    src = src.replace(ICON_ANCHOR, ICON_ANCHOR + "\n        " + icon_line)

path.write_text(src, encoding="utf-8")

# The blacklist strips every .exe but the client's: keep orneos.exe and orneoscmd.exe
blacklist = path.parent / "blacklist.txt"
bl = blacklist.read_text(encoding="utf-8")
OLD, NEW = "bin/(?!(nextcloud|nextcloudcmd|QtWebEngineProcess))", "bin/(?!(orneos|orneoscmd|QtWebEngineProcess))"
if NEW not in bl:
    if OLD not in bl:
        sys.exit(f"upstream recipe changed: executable rule not found in {blacklist}")
    blacklist.write_text(bl.replace(OLD, NEW), encoding="utf-8")
print(f"craft recipe rebranded: {path}")
