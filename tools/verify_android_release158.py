#!/usr/bin/env python3
"""Inspect the actual signed1.58 Android APK and its packaged Godot resources."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

from verify_windows_package157 import clean_path, parse_ecfg, variant_string

CERTIFICATE = 'a303dce96b51ccad40708a8235fb77e348ffeabfd403bacddc60e473235ea98f'
RAW_UPLOADS = ['hotline_miami_15. El Huervo - Daisuke.mp3', 'rain_on_the_blacktop (1).mp3',
               'toby fox - Undertale.mp3', 'videoplayback.webm', 'wenn_die_stadt_schl_ft (1).mp3']


def command(*args):
    return subprocess.check_output([str(arg) for arg in args], stderr=subprocess.STDOUT).decode('utf-8', 'replace')


def check(condition, message):
    if not condition:
        raise ValueError(message)


p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--apk', type=Path, required=True)
p.add_argument('--build-tools', type=Path, required=True)
p.add_argument('--source', required=True)
p.add_argument('--tree', required=True)
p.add_argument('--report', type=Path, required=True)
a = p.parse_args()
check(re.fullmatch('[0-9a-f]{40}', a.source) and re.fullmatch('[0-9a-f]{40}', a.tree), 'Source/tree must be full commit hashes')
check(command('git', 'rev-parse', 'HEAD').strip() == a.source, 'Actual build checkout differs from source pin')
check(command('git', 'rev-parse', 'HEAD^{tree}').strip() == a.tree, 'Actual build tree differs from source pin')
signature = command(a.build_tools / 'apksigner', 'verify', '--verbose', '--print-certs', a.apk)
check('Verified using v2 scheme (APK Signature Scheme v2): true' in signature, 'APK v2 signature missing')
check('Verified using v3 scheme (APK Signature Scheme v3): true' in signature, 'APK v3 signature missing')
match = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)', signature)
check(match and match.group(1).lower() == CERTIFICATE, 'Stable installed-test signing identity changed')
badging = command(a.build_tools / 'aapt', 'dump', 'badging', a.apk)
package = re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging)
check(package and package.groups() == ('com.acornhunter.carolina', '59', '1.58'), 'Actual Android package or version differs')
check(re.search(r"^native-code: 'arm64-v8a'\s*$", badging, re.M), 'Actual APK is not ARM64-only')
check('application-debuggable' not in badging, 'Actual release APK is debuggable')
check("targetSdkVersion:'35'" in badging, 'Android target SDK differs')
check("uses-gl-es: '0x30000'" in badging, 'Compatibility GLES3 requirement missing')
resources = []
with zipfile.ZipFile(a.apk) as archive:
    names = archive.namelist()
    check({name.split('/')[1] for name in names if name.startswith('lib/')} == {'arm64-v8a'}, 'Unexpected native ABI in actual ZIP')
    check(len(names) == len(set(names)), 'Duplicate APK entries')
    check(archive.testzip() is None, 'APK ZIP CRC failure')
    for name in names:
        clean_path(name.rstrip('/'))
        if name.startswith('assets/'):
            relative = name[7:]
            check(not relative.startswith(('tools/', 'art/', 'build/', 'assets/audio158/source/')), 'Authoring directory shipped: ' + relative)
            check(not relative.endswith(('.keystore', '.jks', '.key', '.pfx', '.p12', '.mp4', '.rar', '.zip')), 'Authoring source/key shipped: ' + relative)
            check(not relative.endswith('.gd'), 'Loose GDScript shipped: ' + relative)
            check(not any(relative == path or relative == path + '.import' for path in RAW_UPLOADS), 'Duplicate uploaded audio source shipped: ' + relative)
    values = parse_ecfg(archive.read('assets/project.binary'))
    expected = {'application/config/version':'1.58', 'application/run/main_scene':'res://menu.tscn',
                'rendering/renderer/rendering_method':'gl_compatibility',
                'rendering/renderer/rendering_method.mobile':'gl_compatibility'}
    actual = {key:variant_string(values[key]) for key in expected}
    check(actual == expected, 'Actual packaged Godot settings differ')
    voice_manifest_path = 'assets/audio158/voice/manifest.json'
    voice_manifest_bytes = archive.read('assets/' + voice_manifest_path)
    check(voice_manifest_bytes == Path(voice_manifest_path).read_bytes(), 'Packaged voice manifest differs from pinned source')
    voice_lines = json.loads(voice_manifest_bytes)['voice_lines']
    check(len(voice_lines) == 24 and len({line['id'] for line in voice_lines}) == 24, 'Expected24 distinct spoken lines')
    logical_audio = ['assets/audio158/' + stem + '.ogg' for stem in ['undertale', 'videoplayback', 'daisuke', 'rain', 'wenn', 'record_scratch']]
    for line in voice_lines:
        path = line['asset_path']
        check(path.startswith('res://assets/audio158/voice/') and path.endswith('.ogg'), 'Unexpected voice resource path')
        logical_audio.append(path.removeprefix('res://'))
    for logical in logical_audio:
        metadata = archive.read('assets/' + logical + '.import').decode('utf-8')
        targets = re.findall(r'"res://([^"\r\n]+\.oggvorbisstr)"', metadata)
        targets = list(dict.fromkeys(targets))
        check(len(targets) == 1, 'Missing imported soundtrack remap: ' + logical)
        payload = archive.read('assets/' + targets[0])
        check(len(payload) > 1000 and payload[:4] in [b'RSRC', b'RSCC'], 'Invalid imported soundtrack: ' + logical)
        resources.append({'logical_path':logical, 'target':targets[0], 'bytes':len(payload), 'sha256':hashlib.sha256(payload).hexdigest()})
with a.apk.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
report = {'result':'PASS', 'version':'1.58', 'android_code':59, 'source_commit':a.source, 'source_tree':a.tree,
          'apk':{'file':a.apk.name, 'bytes':a.apk.stat().st_size, 'sha256':digest, 'package':package.group(1),
                 'abi':'arm64-v8a', 'debuggable':False, 'gles':'3.0', 'signature_v2':True, 'signature_v3':True,
                 'certificate_sha256':CERTIFICATE}, 'godot_settings':actual, 'soundtrack_resources':resources,
          'voice_manifest_sha256':hashlib.sha256(voice_manifest_bytes).hexdigest(), 'spoken_line_count':24,
          'scope':'Actual signed Android release manifest/signature/imported6music-SFX+24voice resources; focused source and native Windows media checks are separate evidence.'}
a.report.parent.mkdir(parents=True, exist_ok=True)
a.report.write_text(json.dumps(report, indent=2), encoding='utf-8')
a.apk.with_suffix(a.apk.suffix + '.sha256').write_text(digest + '  ' + a.apk.name + '\n', encoding='utf-8')
print('ANDROID158 RELEASE: PASS')
