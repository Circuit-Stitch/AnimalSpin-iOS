#!/usr/bin/env python3
"""Regenerate the iOS assets + localization + Swift catalog from the AnimalSpin-Resources submodule.

The generator and the source of truth now live in the submodule (`resources/`): the real work is in
`resources/tools/gen_ios.py`, driven by `resources/animals.json`. This is a thin wrapper kept at the
old path so the workflow (and CLAUDE.md) stay the same. Forwards any extra args (e.g. --check).

    python3 tools/gen_assets.py            # regenerate the committed resources in place
    python3 tools/gen_assets.py --check    # verify the committed output matches the manifest (CI)

If you changed content, edit `resources/animals.json` (or run the filter/ pipeline), commit the
submodule, then re-run this and commit the regenerated files + the bumped submodule gitlink.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(REPO, "resources")
GEN = os.path.join(RESOURCES, "tools", "gen_ios.py")

if not os.path.exists(GEN):
    sys.exit("resources submodule not initialized — run: git submodule update --init resources")

sys.exit(subprocess.call([sys.executable, GEN, "--resources", RESOURCES, "--out", REPO, *sys.argv[1:]]))
