#!/usr/bin/env python3
"""Bounded launch of the actual Windows GUI PE; explicit log/report capture.

This helper never invokes the editor. External acceptance scripts and software
Mesa DLLs remain outside the shipping ZIP.
"""
import argparse, hashlib, json, os, re, subprocess, sys
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--exe', type=Path, required=True)
p.add_argument('--script', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--marker', required=True)
p.add_argument('--native', action='store_true')
p.add_argument('--timeout', type=int, default=360)
p.add_argument('--expect-runtime-report', action='store_true')
a = p.parse_args()
assert sys.platform == 'win32', 'Run the Windows acceptance on Windows'
a.output.mkdir(parents=True, exist_ok=True)
exe, script = a.exe.resolve(), a.script.resolve()
log = a.output.resolve() / 'game.log'
before = hashlib.sha256(exe.read_bytes()).hexdigest()
cmd = [str(exe), '--main-pack', str(exe.with_suffix('.pck')), '--log-file', str(log), '--audio-driver', 'Dummy', '--fixed-fps', '60']
if not a.native: cmd += ['--headless']
else: cmd += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--resolution', '1280x720']
cmd += ['--script', str(script), '--', '--output=' + str(a.output.resolve())]
if a.native and a.expect_runtime_report: cmd += ['--native']
environment = dict(os.environ)
environment['APPDATA'] = str(a.output.resolve() / 'user-data')
environment['LOCALAPPDATA'] = str(a.output.resolve() / 'user-local-data')
environment['LP_NUM_THREADS'] = '4'
if a.native:
    environment['GALLIUM_DRIVER'] = 'llvmpipe'
    environment['LIBGL_ALWAYS_SOFTWARE'] = '1'
result = subprocess.run(cmd, cwd=exe.parent, env=environment, timeout=a.timeout)
text = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
print(text, end='')
fatal = re.findall(r'^.*(?:SCRIPT ERROR:|Parser Error:|Parse Error:|Shader compilation failed|Invalid (?:access|call|get|set)|Cannot open file|ERROR:).*$', text, flags=re.M)
assert result.returncode == 0, f'Windows EXE exit code {result.returncode}'
assert not fatal, f'Actual Windows runtime errors: {fatal}'
assert a.marker in text, f'Missing actual runtime marker {a.marker}'
assert hashlib.sha256(exe.read_bytes()).hexdigest() == before, 'Test modified shipping executable'
report_path = a.output / 'report.json'
if a.expect_runtime_report:
    report = json.loads(report_path.read_text(encoding='utf-8'))
    assert report['result'] == 'PASS' and report['actual_os'] == 'Windows'
    assert len(report['scenes']) == 8 and len(report['videos']) == 5
    assert report['native'] is a.native
    if a.native: assert len(report['captures']) == 6
(a.output / 'launch.json').write_text(json.dumps({'result':'PASS', 'actual_windows_executable':str(exe), 'exe_sha256':before, 'external_script_sha256':hashlib.sha256(script.read_bytes()).hexdigest(), 'exit_code':result.returncode, 'native':a.native, 'marker':a.marker, 'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(), 'scope':'Actual Windows release process, not editor. Fixed-fps correctness/readback, not hardware FPS.'}, indent=2), encoding='utf-8')
print('WINDOWS157 PROCESS: PASS')
