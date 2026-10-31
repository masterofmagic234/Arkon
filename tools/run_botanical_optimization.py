#!/usr/bin/env python3
"""Run native matched A/B in a private copy with the Adreno depth policy.

Adreno GLES3 disables the depth prepass in Godot's platform configuration;
llvmpipe does not. An isolated startup override applies that same policy to
both A and B without changing the production project, APK, or other tests.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import time


MARKER = ".botanical_optimization_copy.json"
OVERRIDE = "[rendering]\ndriver/depth_prepass/enable=false\n"


def git(source, *arguments):
    result = subprocess.run(["git", "-C", str(source), *arguments], text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else None


def require(ok, why):
    if not ok:
        raise ValueError(why)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=4)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=840)
    parser.add_argument("--view")
    parser.add_argument("--phone-only", action="store_true")
    args = parser.parse_args()
    source, staging, output = args.source.resolve(), args.staging.resolve(), args.output.resolve()
    require((source / "project.godot").is_file(), "Source must be the real Godot project")
    require(not staging.is_relative_to(source) and not source.is_relative_to(staging), "Staging must be outside the source checkout")
    require(not output.is_relative_to(source) and not output.is_relative_to(staging), "Evidence must stay outside source and temporary project")
    require(not (source / "override.cfg").exists(), "Unexpected source override.cfg: do not silently replace another platform configuration")
    if staging.exists():
        marker = staging / MARKER
        require(marker.is_file() and json.loads(marker.read_text()).get("source") == str(source), "Refusing to replace a staging directory not created by this benchmark")
        shutil.rmtree(staging)
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    shutil.copytree(source, staging, ignore=shutil.ignore_patterns(".git", "build", "__pycache__", "*.pyc"))
    (staging / MARKER).write_text(json.dumps({"source": str(source), "purpose": "isolated native 1.47/1.48 ABBA"}) + "\n")
    (staging / "override.cfg").write_text(OVERRIDE)
    # Only relevant authored runtime inputs are listed, rather than import-cache
    # files or signed URLs. Their actual bytes identify this development copy.
    relevant = [staging / "project.godot", *(staging / "scripts").glob("botanical*.gd"), *(staging / "shaders/woodland").glob("garden*"), staging / "tools/botanical_optimization_test.gd"]
    hashes = {str(p.relative_to(staging)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(relevant)) if p.is_file()}
    godot = shutil.which(args.godot)
    require(godot is not None, "Godot executable not found")
    version = subprocess.run([godot, "--version"], text=True, capture_output=True, check=True).stdout.strip()
    env = os.environ.copy()
    env["XDG_DATA_HOME"] = str(staging.parent / (staging.name + "-user"))
    env["LP_NUM_THREADS"] = "2"
    if env.get("TASK_NATIVE_DISPLAY"):
        env["DISPLAY"] = env["TASK_NATIVE_DISPLAY"]
    command = [godot, "--path", str(staging), "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--script", "tools/botanical_optimization_test.gd", "--", "--output=" + str(output), "--samples=" + str(args.samples), "--warmup=" + str(args.warmup)]
    if args.view:
        command += ["--view=" + args.view]
    if args.phone_only:
        command += ["--phone-only"]
    if not env.get("DISPLAY"):
        xvfb = shutil.which("xvfb-run")
        require(xvfb is not None, "Native display or xvfb-run is required")
        command = [xvfb, "-a", "-s", "-screen 0 3200x1800x24", *command]
    manifest = {"source": str(source), "staging": str(staging), "source_commit": git(source, "rev-parse", "HEAD"), "source_tree": git(source, "rev-parse", "HEAD^{tree}"), "tracked_source_diff": git(source, "diff", "--name-only"), "runtime_source_sha256": hashes, "godot_version": version, "startup_override": OVERRIDE, "override_sha256": hashlib.sha256(OVERRIDE.encode()).hexdigest(), "command": command, "software_render_threads": 2, "status": "running", "note": "Only the isolated copy has override.cfg. Both A and B run in this process at the mobile-Adreno-like no-prepass policy and identical two llvmpipe threads; this is software-rendered evidence, not Samsung/Huawei FPS."}
    manifest_path = output / "benchmark-source.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("Isolated native ABBA:", str(staging), "Godot", version, flush=True)
    log_path = output / "capture.log"
    with log_path.open("w") as log:
        process = subprocess.Popen(command, cwd=staging, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
            code = 124
    text = log_path.read_text(errors="replace")
    print(text, end="")
    errors = [line for line in text.splitlines() if any(word in line for word in ("SCRIPT ERROR:", "Parser Error:", "Parse Error:", "Shader compilation failed", "Invalid access", "Invalid call", "Invalid get", "Invalid set", "Cannot open file", "ERROR:"))]
    ok = code == 0 and not errors and "BOTANICAL OPTIMIZATION CAPTURE: PASS" in text
    manifest.update(status="PASS" if ok else "FAIL", exit_code=code, strict_errors=errors, wall_seconds=round(time.monotonic()-started, 3))
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    # Rewrite only provenance fields in the evidence JSON: native rendering ran
    # in a private copy deliberately lacking .git, so use the pinned source root.
    capture = output / "optimization.json"
    if capture.is_file():
        data = json.loads(capture.read_text())
        data["source_commit"] = manifest["source_commit"]
        data["source_tree"] = manifest["source_tree"]
        data["isolation_manifest"] = manifest_path.name
        capture.write_text(json.dumps(data, indent=2) + "\n")
    if not ok:
        print("BOTANICAL OPTIMIZATION RUN: FAIL", file=sys.stderr)
        return code or 1
    print("BOTANICAL OPTIMIZATION RUN: PASS — isolated startup policy; production checkout unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
