#!/usr/bin/env python3
"""Launch a stock Windows release with captured early output and exact PCK pins.

Godot 4.7 release templates disable --script and --main-pack. A canonical normal
startup uses neither. Acceptance fixtures use a disposable, byte-identical copy
of EXE/PCK and a CI-only adjacent override.cfg selecting an external bootstrap.
No fixture, override, or software Mesa DLL is added to the shipping folder.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--exe', type=Path, required=True)
p.add_argument('--script', type=Path)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--marker')
p.add_argument('--native', action='store_true')
p.add_argument('--startup-only', action='store_true')
p.add_argument('--timeout', type=int, default=360)
p.add_argument('--expect-runtime-report', action='store_true')
a = p.parse_args()
assert sys.platform == 'win32', 'Run the Windows acceptance on Windows'
assert a.startup_only != bool(a.script), 'Choose a canonical startup or an external acceptance fixture'
assert a.startup_only or a.marker, 'An acceptance fixture needs its explicit pass marker'
a.output = a.output.resolve()
a.output.mkdir(parents=True, exist_ok=True)
source = a.exe.resolve()
source_pack = source.with_suffix('.pck')
assert not (source.parent / 'override.cfg').exists(), 'Canonical input must have no acceptance override'
pins = {'exe_sha256':sha(source), 'pck_sha256':sha(source_pack)}
exe = source
script = a.script.resolve() if a.script else None
log = a.output / 'game.log'
launch = {'result':'FAIL', 'canonical_executable':str(source), **pins,
          'native':a.native, 'startup_only':a.startup_only, 'marker':a.marker,
          'scope':('Untouched shipping Windows release normal startup, no test override.' if a.startup_only else
                   'Stock Windows release and byte-identical shipping PCK, external CI-only main-scene override and acceptance fixture. Production resources unchanged.'),
          'performance_scope':'Correctness and readback only; fixed-fps/software CI is not a hardware FPS benchmark.'}
runtime = None
try:
    if script:
        runtime = Path(tempfile.mkdtemp(prefix='AcornHunter-acceptance-', dir=os.environ.get('RUNNER_TEMP')))
        shutil.copytree(source.parent, runtime, dirs_exist_ok=True)
        exe = runtime / source.name
        assert sha(exe) == pins['exe_sha256'] and sha(exe.with_suffix('.pck')) == pins['pck_sha256']
        bootstrap = runtime / 'acceptance-bootstrap.gd'
        scene = runtime / 'acceptance-bootstrap.tscn'
        override = runtime / 'override.cfg'
        bootstrap.write_text('extends Node\n\nfunc _ready() -> void:\n'
                             '    var fixture := load(' + json.dumps(script.as_posix()) + ') as Script\n'
                             '    if fixture == null or not fixture.can_instantiate():\n'
                             '        push_error("Windows acceptance fixture could not load")\n'
                             '        get_tree().quit(1)\n'
                             '        return\n'
                             '    var tree := get_tree()\n'
                             '    tree.current_scene = null\n'
                             '    queue_free()\n'
                             '    tree.set_script(fixture)\n', encoding='utf-8')
        scene.write_text('[gd_scene load_steps=2 format=3]\n\n'
                         '[ext_resource type="Script" path=' + json.dumps(bootstrap.as_posix()) + ' id="1"]\n\n'
                         '[node name="WindowsAcceptanceBootstrap" type="Node"]\n'
                         'script = ExtResource("1")\n', encoding='utf-8')
        override.write_text('[application]\nrun/main_scene=' + json.dumps(scene.as_posix()) + '\n', encoding='utf-8')
        launch.update({'external_script':str(script), 'external_script_sha256':sha(script),
                       'bootstrap_sha256':sha(bootstrap), 'bootstrap_scene_sha256':sha(scene),
                       'ci_override_sha256':sha(override), 'ci_override_text':override.read_text(encoding='utf-8')})
    cmd = [str(exe), '--log-file', str(log), '--audio-driver', 'Dummy', '--fixed-fps', '60']
    if not a.native:
        cmd += ['--headless']
    else:
        cmd += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--resolution', '1280x720']
    if a.startup_only:
        cmd += ['--quit-after', '120']
    else:
        cmd += ['--', '--output=' + str(a.output)]
        if a.native and a.expect_runtime_report:
            cmd += ['--native']
        elif a.native:
            cmd += ['--visual']
    environment = dict(os.environ)
    environment['APPDATA'] = str(a.output / 'user-data')
    environment['LOCALAPPDATA'] = str(a.output / 'user-local-data')
    environment['LP_NUM_THREADS'] = '4'
    if a.native:
        environment['GALLIUM_DRIVER'] = 'llvmpipe'
        environment['LIBGL_ALWAYS_SOFTWARE'] = '1'
    stdout_path, stderr_path = a.output / 'stdout.log', a.output / 'stderr.log'
    launch.update({'actual_windows_executable':str(exe), 'command':cmd})
    with stdout_path.open('wb') as stdout, stderr_path.open('wb') as stderr:
        try:
            result = subprocess.run(cmd, cwd=exe.parent, env=environment, timeout=a.timeout, stdout=stdout, stderr=stderr)
            exit_code, timed_out, spawn_error = result.returncode, False, None
        except subprocess.TimeoutExpired:
            exit_code, timed_out, spawn_error = None, True, None
        except OSError as error:
            exit_code, timed_out, spawn_error = None, False, str(error)
    text = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
    combined = '\n'.join([text, stdout_path.read_text(encoding='utf-8', errors='replace'), stderr_path.read_text(encoding='utf-8', errors='replace')])
    launch.update({'exit_code':exit_code, 'timed_out':timed_out, 'spawn_error':spawn_error,
                   'log_exists':log.exists(), 'stdout_sha256':sha(stdout_path), 'stderr_sha256':sha(stderr_path),
                   'log_sha256':sha(log) if log.exists() else None,
                   'tested_exe_sha256_after':sha(exe), 'tested_pck_sha256_after':sha(exe.with_suffix('.pck')),
                   'canonical_exe_sha256_after':sha(source), 'canonical_pck_sha256_after':sha(source_pack)})
    launch_path = a.output / 'launch.json'
    launch_path.write_text(json.dumps(launch, indent=2), encoding='utf-8')
    print(combined, end='')
    fatal = re.findall(r'^.*(?:SCRIPT ERROR:|Parser Error:|Parse Error:|Shader compilation failed|Invalid (?:access|call|get|set)|Cannot open file|ERROR:).*$', combined, flags=re.M)
    assert not spawn_error, f'Windows process did not start: {spawn_error}'
    assert not timed_out, f'Windows EXE exceeded {a.timeout}s; captured logs and launch.json retained'
    assert exit_code == 0, f'Windows EXE exit code {exit_code}; captured logs and launch.json retained'
    assert not fatal, f'Actual Windows runtime errors: {fatal}'
    assert 'Godot Engine v4.7.2.stable' in combined, 'Missing real release engine startup header'
    assert a.startup_only or a.marker in combined, f'Missing actual runtime marker {a.marker}'
    assert launch['tested_exe_sha256_after'] == launch['canonical_exe_sha256_after'] == pins['exe_sha256']
    assert launch['tested_pck_sha256_after'] == launch['canonical_pck_sha256_after'] == pins['pck_sha256']
    assert not (source.parent / 'override.cfg').exists(), 'Test contaminated canonical shipping folder'
    if a.expect_runtime_report:
        report = json.loads((a.output / 'report.json').read_text(encoding='utf-8'))
        assert report['result'] == 'PASS' and report['actual_os'] == 'Windows'
        assert len(report['scenes']) == 8 and len(report['videos']) == 5
        assert report['native'] is a.native
        if a.native:
            assert len(report['captures']) == 6
    launch['result'] = 'PASS'
    launch_path.write_text(json.dumps(launch, indent=2), encoding='utf-8')
    print('WINDOWS157 PROCESS: PASS')
finally:
    if runtime is not None:
        shutil.rmtree(runtime, ignore_errors=True)
