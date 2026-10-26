#!/usr/bin/env python3
"""Rebuild real Godot LightmapGI assets using the native Vulkan editor.

Usage: python3 tools/bake_botanical_lighting.py /path/to/godot
Requires a display (or xvfb-run) and a working Vulkan driver. The project file
and existing texture-import settings are restored after the editor finishes.
"""
from pathlib import Path
import os
import subprocess
import sys

repo = Path(__file__).resolve().parent.parent
godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
project = repo / "project.godot"
project_before = project.read_bytes()
imports_before = {p: p.read_bytes() for p in repo.rglob("*.import")
                  if ".godot" not in p.parts and "lighting" not in p.parts}


def run(*args, env=None):
    subprocess.run([godot, "--path", str(repo), "--audio-driver", "Dummy", *args],
                   cwd=repo, check=True, env=env)


try:
    run("--script", "tools/prepare_botanical_lighting.gd")
    text = project_before.decode()
    if "[editor_plugins]" in text:
        raise RuntimeError("Temporarily disable existing editor plugins before offline baking")
    project.write_text(text + '\n[editor_plugins]\nenabled=PackedStringArray("res://tools/botanical_baker/plugin.cfg")\n')
    run("--headless", "--editor", "--import")
    run("--editor", env=dict(os.environ, BOTANICAL_BAKE_SCENE=
        "res://assets/level1/botanical/lighting/garden_source.scn"))
    run("--script", "tools/finalize_botanical_lighting.gd")
finally:
    project.write_bytes(project_before)
    for path, contents in imports_before.items():
        path.write_bytes(contents)

run("--headless", "--editor", "--import")
run("--script", "tools/botanical_lighting_test.gd")
