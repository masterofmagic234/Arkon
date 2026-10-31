#!/usr/bin/env python3
"""Create/inspect the portable Windows ZIP without executing its EXE or resources.

Godot4.7.2 PCK layout follows core/io/file_access_pack.cpp and
editor/export/editor_export_platform.cpp in the official4.7.2-stable tag.
This verifies container integrity and selected runtime configuration/presence;
native Windows execution and rendering are separate CI checks.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import sys
import zipfile

VERSION = "1.57"
ENGINE = (4, 7, 2)
MAX_FILE = 1024 * 1024 * 1024
ALLOWED = {"AcornHunter.exe", "AcornHunter.pck", "AcornHunter.console.exe", "README.txt", "LICENSE.txt", "COPYRIGHT.txt", "LICENSES.txt"}
REQUIRED_OUTER = {"AcornHunter.exe", "AcornHunter.pck", "README.txt"}
SCENES = ["menu.tscn", "intro_cutscene.tscn", "game.tscn", "scenes/level2.tscn", "scenes/level3_store.tscn", "scenes/park_escape_cutscene.tscn", "scenes/ending_cutscene.tscn"]
SCRIPTS = ["scripts/graphics_settings.gd", "scripts/graphics_policy156.gd", "scripts/graphics_store156.gd", "scripts/graphics_monitor156.gd", "scripts/graphics_panel156.gd", "scripts/scene_flow.gd", "scripts/botanical_garden.gd", "scripts/game_level2_pseudo3d.gd", "scripts/level3_store.gd"]
VIDEOS = ["assets/intro_video/1789650644963.ogv", "assets/intro_video/1789649201942.ogv", "assets/intro_video/1789650878847.ogv", "assets/intro_video/1789649329293.ogv", "assets/cinematics/park_escape/film.ogv"]
MODELS = ["assets/level2/fleet155/camry_patrol.glb", "assets/level2/fleet155/camry_interceptor.glb", "assets/level2/fleet155/camry_wagon.glb", "assets/level1/characters/tank_squirrel.glb"]
FORBIDDEN_PREFIXES = ["tools/", "art/", "build/", ".git/", ".godot/editor/", ".godot/shader_cache/", "assets/level1/characters/source/", "assets/level2/source/", "assets/level2/models/", "assets/level3/squirrels/source/", "assets/level1/botanical/lighting/probe/", "assets/level1/botanical/lighting/meshes/", "assets/level3/dialogue/source/", "assets/level3/vehicles/source/", "assets/level3/carolina147/source/", "assets/level1/weapons/cedar/source/"]
FORBIDDEN_SUFFIXES = (".keystore", ".jks", ".pem", ".key", ".pfx", ".p12", ".mp4", ".rar", ".7z", ".zip")


def need(ok: bool, reason: str) -> None:
    if not ok:
        raise ValueError(reason)


def sha(raw: bytes | memoryview) -> str:
    return hashlib.sha256(raw).hexdigest()


def file_sha(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def clean_path(value: str) -> str:
    need(bool(value) and "\\" not in value and "\0" not in value and ":" not in value, "Unsafe path: " + repr(value))
    need(not value.startswith("/") and all(p not in ["", ".", ".."] for p in value.split("/")), "Noncanonical path: " + repr(value))
    need(str(PurePosixPath(value)) == value, "Noncanonical POSIX path")
    return value


def inspect_pe(raw: bytes) -> dict:
    need(len(raw) >= 512 and raw[:2] == b"MZ", "Missing DOS executable header")
    pe = struct.unpack_from("<I", raw, 0x3C)[0]
    need(64 <= pe <= len(raw) - 24 and raw[pe:pe + 4] == b"PE\0\0", "Invalid PE header offset/signature")
    machine, sections, timestamp, _, _, optional_size, characteristics = struct.unpack_from("<HHIIIHH", raw, pe + 4)
    need(machine == 0x8664, "Expected Windows AMD64 executable")
    optional = pe + 24
    need(optional_size >= 112 and optional + optional_size <= len(raw), "Truncated PE32+ optional header")
    need(struct.unpack_from("<H", raw, optional)[0] == 0x20B, "Expected PE32+64-bit optional header")
    subsystem = struct.unpack_from("<H", raw, optional + 68)[0]
    need(subsystem in [2, 3] and bool(characteristics & 2), "Not a GUI/console Windows executable")
    need(1 <= sections <= 96 and optional + optional_size + sections * 40 <= len(raw), "Invalid PE section table")
    entry_rva = struct.unpack_from("<I", raw, optional + 16)[0]
    executable_entry = False
    rows = []
    for i in range(sections):
        at = optional + optional_size + i * 40
        name = raw[at:at + 8].rstrip(b"\0").decode("ascii", "replace")
        virtual_size, virtual_rva, size, start = struct.unpack_from("<IIII", raw, at + 8)
        flags = struct.unpack_from("<I", raw, at + 36)[0]
        need(size <= MAX_FILE and (size == 0 or 0 < start <= len(raw) - size), "PE section outside executable: " + name)
        if virtual_rva <= entry_rva < virtual_rva + max(virtual_size, size) and flags & 0x20000000:
            executable_entry = True
        rows.append({"name": name, "bytes": size, "offset": start})
    need(executable_entry, "PE entry point is not in an executable section")
    return {"machine": "0x8664", "architecture": "x86_64", "optional_header": "PE32+", "subsystem": subsystem, "sections": rows, "template_timestamp": timestamp, "authenticode_verified": False}


class PCK:
    def __init__(self, raw: bytes):
        self.raw = raw
        self.rows: dict[str, dict] = {}
        need(104 <= len(raw) <= MAX_FILE and raw[:4] == b"GDPC", "Expected bounded standalone Godot PCK")
        version, major, minor, patch, flags = struct.unpack_from("<IIIII", raw, 4)
        need(version == 4 and (major, minor, patch) == ENGINE, "Expected Godot4.7.2 formatV4 pack")
        need(flags == 2, "Only unencrypted, non-sparse relative-file-base PCK is supported")
        file_base, directory = struct.unpack_from("<QQ", raw, 24)
        need(not any(raw[40:104]), "Unexpected nonzero reserved PCK header bytes")
        need(104 <= file_base <= directory <= len(raw) - 4, "PCK data/directory offsets are outside file")
        count = struct.unpack_from("<I", raw, directory)[0]
        need(1 <= count <= 100000, "Invalid PCK directory entry count")
        offset = directory + 4
        intervals = []
        for _ in range(count):
            need(offset + 4 <= len(raw), "Truncated PCK filename length")
            length = struct.unpack_from("<I", raw, offset)[0]
            offset += 4
            need(0 < length <= 16384 and length % 4 == 0 and offset + length + 36 <= len(raw), "Invalid/truncated padded PCK entry")
            padded = raw[offset:offset + length]
            path_bytes = padded.rstrip(b"\0")
            need(length - len(path_bytes) <= 3 and b"\0" not in path_bytes, "Invalid PCK path padding")
            name = clean_path(path_bytes.decode("utf-8", "strict"))
            offset += length
            relative, size = struct.unpack_from("<QQ", raw, offset)
            digest = raw[offset + 16:offset + 32]
            entry_flags = struct.unpack_from("<I", raw, offset + 32)[0]
            offset += 36
            absolute = file_base + relative
            need(entry_flags == 0, "Encrypted/removal/delta file is not a standalone runtime payload: " + name)
            need(0 <= size <= MAX_FILE and file_base <= absolute <= directory and size <= directory - absolute, "PCK entry outside data region: " + name)
            need(name not in self.rows, "Duplicate PCK path: " + name)
            actual = hashlib.md5(memoryview(raw)[absolute:absolute + size]).digest()
            need(actual == digest, "PCK entry MD5 mismatch: " + name)
            self.rows[name] = {"offset": absolute, "bytes": size, "md5": digest.hex()}
            if size:
                intervals.append((absolute, absolute + size, digest, name))
        need(offset == len(raw), "Trailing/unparsed data after PCK directory")
        intervals.sort()
        for first, second in zip(intervals, intervals[1:]):
            need(first[1] <= second[0] or first[:3] == second[:3], "Partially overlapping PCK payloads")
        self.header = {"format": version, "engine": [major, minor, patch], "flags": flags, "entries": count, "file_base": file_base, "directory_offset": directory, "all_md5_checked": True}

    def read(self, path: str) -> bytes:
        need(path in self.rows, "Missing PCK entry: " + path)
        row = self.rows[path]
        return self.raw[row["offset"]:row["offset"] + row["bytes"]]

    def resolve(self, logical: str) -> tuple[str, bytes]:
        if logical in self.rows:
            return logical, self.read(logical)
        metadata = [logical + extension for extension in [".remap", ".import"] if logical + extension in self.rows]
        need(len(metadata) == 1, "Missing/ambiguous import remap: " + logical)
        text = self.read(metadata[0]).decode("utf-8", "strict")
        section = text.split("[remap]", 1)
        need(len(section) == 2, "Import metadata lacks remap section: " + logical)
        text = section[1].split("\n[", 1)[0]
        targets = re.findall(r'^\s*path(?:\.[a-zA-Z0-9_]+)?\s*=\s*"(res://[^"\r\n]+)"\s*$', text, re.M)
        targets = sorted({clean_path(t.removeprefix("res://")) for t in targets if t.removeprefix("res://") in self.rows})
        need(len(targets) == 1, "Missing/ambiguous delivered import target: " + logical)
        return targets[0], self.read(targets[0])


def parse_ecfg(raw: bytes) -> dict[str, bytes]:
    need(len(raw) >= 8 and raw[:4] == b"ECFG", "Missing Godot binary project settings")
    count = struct.unpack_from("<I", raw, 4)[0]
    need(count <= 10000, "Invalid binary project setting count")
    cursor = 8
    settings = {}
    for _ in range(count):
        parts = []
        for part in range(2):
            need(cursor + 4 <= len(raw), "Truncated project setting length")
            length = struct.unpack_from("<I", raw, cursor)[0]
            cursor += 4
            need(length <= 1024 * 1024 and cursor + length <= len(raw), "Truncated binary project setting")
            parts.append(raw[cursor:cursor + length])
            cursor += length
        name = parts[0].decode("utf-8", "strict")
        need(name not in settings, "Duplicate binary project setting")
        settings[name] = parts[1]
    need(cursor == len(raw), "Trailing binary project settings")
    return settings


def variant_string(raw: bytes) -> str:
    need(len(raw) >= 8, "Truncated Variant string")
    kind, length = struct.unpack_from("<II", raw)
    need(kind == 4 and len(raw) == 8 + (length + 3) // 4 * 4 and not any(raw[8 + length:]), "Invalid Variant STRING encoding")
    return raw[8:8 + length].decode("utf-8", "strict")


def inspect_pck(raw: bytes, version: str) -> dict:
    pck = PCK(raw)
    for path in pck.rows:
        lower = path.lower()
        need(lower not in ["override.cfg", "export_presets.cfg"], "Editor/override configuration shipped: " + path)
        need(not any(lower.startswith(p) for p in FORBIDDEN_PREFIXES), "Authoring/tool directory shipped: " + path)
        need(not lower.endswith(FORBIDDEN_SUFFIXES), "Authoring archive/video/key shipped: " + path)
        need(not lower.endswith(".gd"), "Plain GDScript shipped instead of release tokenizer buffer: " + path)
        need(not lower.startswith("scenes/level1_legacy.tscn"), "Superseded Level1 scene shipped")
    values = parse_ecfg(pck.read("project.binary"))
    expected = {"application/config/version": version, "application/run/main_scene": "res://menu.tscn", "rendering/renderer/rendering_method": "gl_compatibility", "rendering/renderer/rendering_method.mobile": "gl_compatibility", "autoload/GraphicsSettings": "*res://scripts/graphics_settings.gd", "autoload/SceneFlow": "*res://scripts/scene_flow.gd"}
    actual = {}
    for key, value in expected.items():
        need(key in values, "Missing actual project setting: " + key)
        actual[key] = variant_string(values[key])
        need(actual[key] == value, "Unexpected actual project setting: " + key)
    selected = []
    for logical in SCENES + SCRIPTS + MODELS:
        target, payload = pck.resolve(logical)
        if logical in SCRIPTS:
            need(target.endswith(".gdc") and payload[:4] == b"GDSC", "Runtime script is not exported GDC: " + logical)
        else:
            need(target.endswith(".scn") and payload[:4] in [b"RSCC", b"RSRC"], "Runtime scene/model is not imported binary scene: " + logical)
        selected.append({"path": logical, "target": target, "bytes": len(payload), "sha256": sha(payload)})
    for path in VIDEOS:
        payload = pck.read(path)
        need(len(payload) > 10000 and payload[:4] == b"OggS" and b"theora" in payload[:512], "Missing/invalid packaged Theora movie: " + path)
        selected.append({"path": path, "bytes": len(payload), "sha256": sha(payload)})
    intro = json.loads(pck.read("assets/intro_video/compiled.json"))
    need(len(intro.get("clips", [])) == 4, "Packaged intro metadata does not list four complete clips")
    for row in intro["clips"]:
        path = "assets/intro_video/" + clean_path(row["file"])
        need(path in VIDEOS and sha(pck.read(path)) == row["sha256"], "Packaged intro movie differs from its actual compiled manifest")
    park = json.loads(pck.read("assets/cinematics/park_escape/compiled.json"))
    # Different reviewed assembly manifests use nested output metadata. Presence
    # and valid JSON are checked here; the native movie smoke validates loading.
    need(isinstance(park, dict) and bool(park), "Missing park-departure conversion metadata")
    return {"header": pck.header, "project_settings": actual, "selected_runtime_resources": selected, "all_paths_checked_for_authoring_keys_and_tools": True, "plain_gd_scripts": 0, "scope": "Container bounds/MD5 and selected actual configuration/remapped binary resources; not native execution or exact source-to-binary equivalence."}


def inspect_directory(directory: Path, version: str) -> tuple[dict, dict]:
    need(directory.is_dir() and not directory.is_symlink(), "Release directory is missing or a symlink")
    paths = sorted(directory.iterdir())
    need(all(p.is_file() and not p.is_symlink() for p in paths), "Portable release must contain regular files only")
    need(all(0 < p.stat().st_size <= MAX_FILE for p in paths), "Empty/unbounded portable file")
    names = {p.name for p in paths} - {"build-manifest.json"}
    need(REQUIRED_OUTER <= names and names <= ALLOWED, "Unexpected/missing portable files: " + repr(sorted(names)))
    need(any(n in names for n in ["LICENSE.txt", "LICENSES.txt"]), "Godot license notice missing from portable folder")
    files = {p.name: {"bytes": p.stat().st_size, "sha256": file_sha(p)} for p in paths if p.name != "build-manifest.json"}
    pe = inspect_pe((directory / "AcornHunter.exe").read_bytes())
    if "AcornHunter.console.exe" in names:
        inspect_pe((directory / "AcornHunter.console.exe").read_bytes())
    pck = inspect_pck((directory / "AcornHunter.pck").read_bytes(), version)
    (directory / "README.txt").read_text(encoding="utf-8-sig")
    return files, {"pe": pe, "pck": pck}


def inspect_manifest(manifest: dict, expected_source: str, expected_tree: str | None = None, expected_checkout: str | None = None) -> None:
    need(manifest.get("schema") == 1 and manifest.get("version") == VERSION and manifest.get("source_commit") == expected_source, "Unexpected source/version/schema in build manifest")
    for key in ["source_commit", "source_tree", "checkout_commit"]:
        need(re.fullmatch("[a-f0-9]{40}", manifest.get(key, "")), "Expected complete commit/tree identity: " + key)
    if expected_tree is not None:
        need(manifest["source_tree"] == expected_tree, "Unexpected source tree")
    if expected_checkout is not None:
        need(manifest["checkout_commit"] == expected_checkout, "Unexpected checkout commit")
    need(manifest.get("platform") == "Windows x86_64", "Unexpected platform metadata")
    files = manifest.get("files", {})
    need(isinstance(files, dict) and REQUIRED_OUTER <= set(files) and set(files) <= ALLOWED, "Unexpected manifest file inventory")
    need(any(n in files for n in ["LICENSE.txt", "LICENSES.txt"]), "Missing redistribution license")


def inspect_existing_directory(directory: Path, expected_source: str, expected_tree: str | None = None, expected_checkout: str | None = None) -> dict:
    manifest = json.loads((directory / "build-manifest.json").read_text(encoding="utf-8"))
    inspect_manifest(manifest, expected_source, expected_tree, expected_checkout)
    files, inspection = inspect_directory(directory, VERSION)
    need(files == manifest["files"], "Portable directory differs from its manifest")
    return {"result": "PASS", "directory": str(directory), "manifest": manifest, **inspection, "scope": "Static portable directory/AMD64PE/PCK integrity/configuration inspection. No execution, driver/FPS measurement or Authenticode trust validation."}


def inspect_zip(path: Path, expected_source: str, expected_tree: str | None = None, expected_checkout: str | None = None) -> dict:
    with zipfile.ZipFile(path) as archive:
        need(3 <= len(archive.infolist()) <= 12, "Unexpected portable ZIP file count")
        names = set()
        folded = set()
        records = {}
        roots = set()
        total = 0
        for entry in archive.infolist():
            need(not entry.is_dir(), "Portable ZIP should contain files, no directory entries")
            name = clean_path(entry.filename)
            need(name not in names and name.casefold() not in folded, "Duplicate/case-colliding ZIP entry")
            need(stat.S_IFMT(entry.external_attr >> 16) != stat.S_IFLNK and not entry.flag_bits & 1, "Symlink/encrypted ZIP entry")
            roots.add(name.split("/")[0] if "/" in name else "")
            need(len(name.split("/")) <= 2, "Portable ZIP has unexpected nested files")
            need(0 < entry.file_size <= MAX_FILE, "Unbounded/empty portable file")
            total += entry.file_size
            names.add(name)
            folded.add(name.casefold())
            records[name] = entry
        need(len(roots) == 1 and total <= 2 * MAX_FILE, "Invalid portable ZIP root/total size")
        root_name = next(iter(roots))
        prefix = root_name + "/" if root_name else ""
        need(prefix + "build-manifest.json" in names, "Missing build manifest")
        manifest = json.loads(archive.read(prefix + "build-manifest.json"))
        inspect_manifest(manifest, expected_source, expected_tree, expected_checkout)
        if root_name:
            need(manifest.get("archive_root") == root_name, "Unexpected ZIP folder name")
        files = manifest.get("files", {})
        need(isinstance(files, dict) and REQUIRED_OUTER <= set(files) and set(files) <= ALLOWED, "Unexpected manifest file inventory")
        need(any(n in files for n in ["LICENSE.txt", "LICENSES.txt"]), "Missing redistribution license")
        need(names == {prefix + n for n in files} | {prefix + "build-manifest.json"}, "ZIP inventory differs from manifest")
        for name, row in files.items():
            entry = records[prefix + name]
            with archive.open(entry) as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            need(row == {"bytes": entry.file_size, "sha256": digest}, "Actual ZIP file differs from manifest: " + name)
        pe = inspect_pe(archive.read(prefix + "AcornHunter.exe"))
        if "AcornHunter.console.exe" in files:
            inspect_pe(archive.read(prefix + "AcornHunter.console.exe"))
        pck = inspect_pck(archive.read(prefix + "AcornHunter.pck"), VERSION)
        archive.read(prefix + "README.txt").decode("utf-8-sig")
        return {"result": "PASS", "archive": {"path": str(path), "bytes": path.stat().st_size, "sha256": file_sha(path), "root": root_name or "flat"}, "manifest": manifest, "pe": pe, "pck": pck, "scope": "Static portable ZIP/AMD64PE/PCK integrity/configuration inspection. No EXE/script/resource execution, Windows driver/PC FPS measurement or Authenticode trust validation."}


def create(args: argparse.Namespace) -> dict:
    directory = args.directory.resolve()
    output = args.output.resolve() if args.output else None
    if output is not None:
        need(not output.is_relative_to(directory), "ZIP output must be outside the portable directory")
    for value in [args.source, args.tree, args.checkout or args.source]:
        need(re.fullmatch("[a-f0-9]{40}", value), "Source/tree/checkout must be complete SHA")
    need(args.version == VERSION, "This release inspector expects1.57")
    files, _ = inspect_directory(directory, args.version)
    manifest = {"schema": 1, "application": "ACORN HUNTER", "version": args.version, "platform": "Windows x86_64", "source_commit": args.source, "source_tree": args.tree, "checkout_commit": args.checkout or args.source, "engine": "4.7.2-stable", "renderer": "gl_compatibility", "archive_root": directory.name, "files": files, "packager": "tools/verify_windows_package157.py", "packager_sha256": file_sha(Path(__file__)), "performance_claim": "No measured minimum PC specification or FPS. Native Windows/headless/render checks are separate CI evidence."}
    (directory / "build-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    if output is None:
        return inspect_existing_directory(directory, args.source, args.tree, args.checkout or args.source)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(directory.iterdir()):
            entry = zipfile.ZipInfo(directory.name + "/" + path.name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(entry, path.read_bytes())
    report = inspect_zip(output, args.source, args.tree, args.checkout or args.source)
    output.with_suffix(output.suffix + ".sha256").write_text(report["archive"]["sha256"] + "  " + output.name + "\n", encoding="ascii")
    return report


def self_test() -> dict:
    rows = {"test.bin": b"payload"}
    base = 112
    body = bytearray(b"\0" * base)
    struct.pack_into("<4sIIIIIQQ", body, 0, b"GDPC", 4, *ENGINE, 2, base, 0)
    directory_rows = []
    for name, payload in rows.items():
        at = len(body) - base
        body += payload
        padded = name.encode()
        padded += b"\0" * ((-len(padded)) % 4)
        directory_rows.append(struct.pack("<I", len(padded)) + padded + struct.pack("<QQ", at, len(payload)) + hashlib.md5(payload).digest() + struct.pack("<I", 0))
    directory = len(body)
    struct.pack_into("<Q", body, 32, directory)
    body += struct.pack("<I", len(directory_rows)) + b"".join(directory_rows)
    need(PCK(bytes(body)).read("test.bin") == b"payload", "Synthetic PCK valid case failed")
    rejected = []
    cases = {}
    for label, index in [("payload_md5", base), ("header_version", 4), ("reserved_header", 48), ("directory_bounds", 32), ("entry_flags", len(body) - 1)]:
        mutated = bytearray(body)
        mutated[index] ^= 0x40
        cases[label] = bytes(mutated)
    cases["truncation"] = bytes(body[:-2])
    cases["trailing_data"] = bytes(body + b"\0")
    for label, raw in cases.items():
        try:
            PCK(raw)
        except (ValueError, UnicodeError, struct.error):
            rejected.append(label)
    need(len(rejected) == len(cases), "PCK negative cases did not all reject")
    for path in ["../x", "/x", "a/../b", "a//b", "C:/x", "a\\b"]:
        try:
            clean_path(path)
        except ValueError:
            rejected.append("path:" + path)
        else:
            raise ValueError("Unsafe path accepted")
    return {"result": "PASS", "synthetic_pck_valid": True, "rejected": rejected, "scope": "Parser boundary/path/integrity negative cases only; not an exported application or Windows execution."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("create")
    build.add_argument("--directory", type=Path, required=True)
    build.add_argument("--output", type=Path, help="Optional local ZIP; CI uploads the shipping directory directly")
    build.add_argument("--source", required=True)
    build.add_argument("--tree", required=True)
    build.add_argument("--checkout")
    build.add_argument("--version", default=VERSION)
    build.add_argument("--report", type=Path)
    check = sub.add_parser("verify")
    check.add_argument("archive", type=Path)
    check.add_argument("--expected-source", required=True)
    check.add_argument("--expected-tree")
    check.add_argument("--expected-checkout")
    check.add_argument("--report", type=Path)
    folder = sub.add_parser("verify-directory")
    folder.add_argument("--directory", type=Path, required=True)
    folder.add_argument("--expected-source", required=True)
    folder.add_argument("--expected-tree")
    folder.add_argument("--expected-checkout")
    folder.add_argument("--report", type=Path)
    test = sub.add_parser("self-test")
    test.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = {"result": "RUNNING"}
    try:
        if args.command == "create":
            result = create(args)
        elif args.command == "verify":
            result = inspect_zip(args.archive, args.expected_source, args.expected_tree, args.expected_checkout)
        elif args.command == "verify-directory":
            result = inspect_existing_directory(args.directory, args.expected_source, args.expected_tree, args.expected_checkout)
        else:
            result = self_test()
    except Exception as error:
        result = {"result": "FAIL", "error": str(error), "command": args.command}
        raise
    finally:
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("WINDOWS PACKAGE157: " + result["result"])
    if "archive" in result:
        print(json.dumps(result["archive"]))


if __name__ == "__main__":
    main()
