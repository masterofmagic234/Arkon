#!/usr/bin/env python3
"""Check the actual user music and generated speech shipped in release 1.58."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'assets/audio158'
TRACKS = {'undertale':'toby fox - Undertale.mp3', 'videoplayback':'videoplayback.webm',
          'daisuke':'hotline_miami_15. El Huervo - Daisuke.mp3',
          'rain':'rain_on_the_blacktop (1).mp3', 'wenn':'wenn_die_stadt_schl_ft (1).mp3'}


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def probe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries',
        'format=duration:stream=codec_name,codec_type,sample_rate,channels','-of','json',str(path)]))


def audio(path, channels):
    info = probe(path)
    streams = info['streams']
    assert len(streams) == 1 and streams[0]['codec_type'] == 'audio', path
    stream = streams[0]
    assert stream['codec_name'] == 'vorbis' and int(stream['sample_rate']) == 44100 and stream['channels'] == channels, path
    return float(info['format']['duration'])


def run():
    report = {'result':'RUNNING', 'music':[], 'voices':[], 'scope':'Media identity, decodability and speech energy; not a claim of human audition or consumer GPU performance.'}
    manifest = json.loads((MEDIA / 'music_manifest.json').read_text())
    for name, source_name in TRACKS.items():
        path, original = MEDIA / (name + '.ogg'), ROOT / source_name
        duration = audio(path, 2)
        original_duration = float(probe(original)['format']['duration'])
        assert abs(duration - original_duration) < .10, (name, duration, original_duration)
        row = manifest['tracks'][name]
        assert row['source'] == source_name and row['source_sha256'] == digest(original)
        assert row['sha256'] == digest(path), name
        report['music'].append({'id':name, 'duration':duration, 'sha256':digest(path)})
    voice_manifest = json.loads((MEDIA / 'voice/manifest.json').read_text())
    expected = {'intro_%02d' % i for i in range(17)} | {
        'l3_reception_00','l3_reception_01','l3_kitchen_00','l3_kitchen_02',
        'l3_kitchen_04','l3_aftermath_01','l3_aftermath_03'}
    entries = voice_manifest['voice_lines']
    assert voice_manifest['count'] == len(entries) == 24
    assert {row['id'] for row in entries} == expected
    assert {p.stem for p in (MEDIA / 'voice').glob('*.ogg')} == expected
    for row in entries:
        path = MEDIA / 'voice' / (row['id'] + '.ogg')
        duration = audio(path, 1)
        assert .35 < duration < 35 and abs(duration - row['duration']) < .03, row['id']
        assert row['sha256'] == digest(path)
        assert row['text'] in (ROOT / row['source']).read_text(), row['id']
        assert row['voice'] == ('Rachel' if row['speaker'] == 'ДАРИНА' else 'Ella')
        assert row['language'] == 'ru'
        raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ar','22050',
            '-ac','1','-f','s16le','pipe:1'])
        samples = array.array('h', raw)
        assert len(samples) > 5000
        rms = math.sqrt(sum((s / 32768.0) ** 2 for s in samples) / len(samples))
        active = sum(abs(s) > 327 for s in samples) / len(samples)
        clipped = sum(abs(s) >= 32760 for s in samples) / len(samples)
        assert rms > .008 and active > .06 and clipped < .01, (row['id'], rms, active, clipped)
        report['voices'].append({'id':row['id'], 'duration':duration, 'rms':rms, 'active_fraction':active, 'clipped_fraction':clipped})
    scratch = MEDIA / 'record_scratch.ogg'
    scratch_duration = audio(scratch, 2)
    assert .65 <= scratch_duration <= 1.35
    report['scratch'] = {'duration':scratch_duration, 'sha256':digest(scratch)}
    report['result'] = 'PASS'
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = run()
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print('MEDIA158 ASSETS: PASS (5 user tracks, 24 voiced lines, vinyl scratch)')
