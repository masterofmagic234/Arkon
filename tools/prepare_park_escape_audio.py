#!/usr/bin/env python3
"""Stage the reviewed 26-second park-escape soundtrack from pinned source audio.

Dependencies: Python 3, NumPy, FFmpeg/ffprobe with libvorbis and libmp3lame.
No account, network request, paid generation or runtime synthesis is involved.

From the repository root, after restoring the retained authoring sources:
    python3 tools/prepare_park_escape_audio.py --output-dir /tmp/park-escape-audio

Defaults read six MP3s from art/intro/park_escape145/audio/raw and their pinned
source/FX hashes from art/intro/park_escape145/audio/audio-report.json. Original
game vehicle, rotor and wind effects remain in assets/. Optional path arguments
permit a different checkout or an external authoring archive.

Only an external staging directory is written. The tool never promotes output
into assets/cinematics/park_escape or changes the runtime manifest. Review the
candidates before copying any bytes and pinning their new hashes. Ogg container
serials may vary between runs: the report also records decoded PCM digests.

The first scout is time-compressed 20% without changing pitch; no human voice is
pitch-shifted into a squirrel. Source creature authenticity requires human review;
signal/timeline checks do not establish how an animal sounds to a listener.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / 'art/intro/park_escape145/audio'
RATE = 48000
SECONDS = 26.0
N = round(RATE * SECONDS)
T = np.arange(N) / RATE
SPECS = (
    ('scout1', 6.4, 2.5, 6.2, 8.95, 'РАЗВЕДЧИК', 'Она увозит наши жёлуди!'),
    ('scout2', 9.0, 2.2, 9.0, 11.45, 'СВЯЗНОЙ', 'Командир! Она уходит!'),
    ('commander_pursuit', 12.0, 1.2, 11.7, 13.7, 'КОМАНДИР', 'За ней!'),
    ('commander_helicopter', 13.8, 2.3, 13.8, 16.25, 'КОМАНДИР', 'Поднять вертолёт!'),
    ('commander_acorns', 16.4, 3.6, 16.4, 20.25, 'КОМАНДИР', 'Вернуть жёлуди любой ценой!'),
    ('pilot', 21.0, 2.2, 20.9, 24.8, 'ОРЕХ-1 · ПИЛОТ', 'Есть! Начинаем преследование!'),
)
FX_FILES = (
    'assets/vehicle_audio/engine_0900_load.wav',
    'assets/vehicle_audio/engine_2700_load.wav',
    'assets/vehicle_audio/engine_4500_load.wav',
    'assets/vehicle_audio/engine_6300_load.wav',
    'assets/level2/pursuit/rotor.wav',
    'assets/level1/audio/park_wind.ogg',
)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(args):
    subprocess.run(args, check=True)


def read_audio(path):
    raw = subprocess.check_output([
        'ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(path),
        '-f', 'f32le', '-ac', '1', '-ar', str(RATE), 'pipe:1',
    ])
    return np.frombuffer(raw, dtype='<f4').astype(np.float64)


def write_wav(path, samples):
    samples = np.asarray(samples)
    channels = 1 if samples.ndim == 1 else samples.shape[1]
    if not np.isfinite(samples).all() or np.max(abs(samples)) >= 1.0:
        raise ValueError(f'{path.name}: non-finite or clipped PCM')
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(channels)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(np.round(samples * 32767).astype('<i2').tobytes())


def rms(samples):
    return float(np.sqrt(np.mean(np.asarray(samples) ** 2)))


def db(value):
    return 20 * math.log10(max(float(value), 1e-12))


def envelope(points):
    return np.interp(T, [p[0] for p in points], [p[1] for p in points])


def pan(samples, positions):
    theta = (np.asarray(positions) + 1) * math.pi / 4
    # Equal-power pan; center keeps a mono source present in both channels.
    return np.column_stack((samples * np.cos(theta), samples * np.sin(theta)))


def active_regions(samples):
    stride = round(RATE * .02)
    windows = np.asarray([rms(samples[i:i + stride]) for i in range(0, len(samples), stride)])
    active = windows > max(.0025, float(windows.max()) * .10)
    starts = np.where(active & ~np.r_[False, active[:-1]])[0] * .02
    ends = (np.where(active & ~np.r_[active[1:], False])[0] + 1) * .02
    return [[round(float(a), 3), round(min(len(samples) / RATE, float(b)), 3)] for a, b in zip(starts, ends)]


def repeated(path):
    samples = read_audio(path)
    samples -= samples.mean()
    return np.resize(samples, N)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sources-dir', type=Path, default=AUTHORING / 'raw')
    parser.add_argument('--provenance', type=Path, default=AUTHORING / 'audio-report.json',
                        help='Reviewed source report containing six source_sha256 and FX hashes')
    parser.add_argument('--project-root', type=Path, default=ROOT, help='Checkout containing the original assets/ FX')
    parser.add_argument('--output-dir', type=Path, required=True, help='External staging directory, never the checkout')
    parser.add_argument('--overwrite', action='store_true', help='Replace existing staged outputs; runtime destinations remain forbidden')
    return parser.parse_args()


def inside(path, directory):
    return path == directory or directory in path.parents


def prepare_inputs(args):
    project = args.project_root.resolve()
    sources = args.sources_dir.resolve()
    provenance_path = args.provenance.resolve()
    output = args.output_dir.resolve()
    if any(inside(output, root) for root in (ROOT, project, sources)):
        raise ValueError('Stage outside the repository/project and raw source directory')
    for binary in ('ffmpeg', 'ffprobe'):
        if shutil.which(binary) is None:
            raise FileNotFoundError(f'{binary} is required; install FFmpeg before authoring')
    provenance = json.loads(provenance_path.read_text(encoding='utf-8'))
    rows = provenance.get('utterances', [])
    by_key = {row['key']: row for row in rows}
    if len(rows) != len(SPECS) or set(by_key) != {spec[0] for spec in SPECS}:
        raise ValueError('Provenance must pin exactly the six reviewed creature takes')
    fx_pins = {row['file']: row['sha256'] for row in provenance.get('fx_sources', [])}
    protected = {provenance_path}
    selected = []
    for key, start, duration, sub_start, sub_end, speaker, text in SPECS:
        record = by_key[key]
        source = sources / (key + '.mp3')
        if digest(source) != record.get('source_sha256'):
            raise ValueError(f'Unreviewed source hash: {source.name}')
        for field, expected in [('target_start', start), ('target_duration', duration),
                                ('subtitle_start', sub_start), ('subtitle_end', sub_end)]:
            if abs(float(record.get(field, -1)) - expected) > .000001:
                raise ValueError(f'{key}: reviewed {field} changed')
        if record.get('speaker') != speaker or record.get('subtitle') != text:
            raise ValueError(f'{key}: reviewed speaker/subtitle changed')
        protected.add(source.resolve())
        selected.append({field: record[field] for field in (
            'key', 'file', 'task_id', 'tool', 'prompt', 'requested_credits',
            'reported_duration', 'target_start', 'target_duration', 'speaker', 'subtitle')})
    for name in FX_FILES:
        source = project / name
        if digest(source) != fx_pins.get(name):
            raise ValueError(f'Unreviewed original FX hash: {name}')
        protected.add(source.resolve())
    names = [f'{spec[0]}.{extension}' for spec in SPECS for extension in ('wav', 'ogg')]
    names += ['voices-stem.wav', 'effects-stem.wav', 'park_escape_mix_premaster.wav',
              'park_escape_mix.wav', 'park_escape_mix.ogg', 'park_escape_preview.mp3',
              'subtitle-cues.json', 'assembly-report.json']
    for name in names:
        destination = output / name
        resolved = destination.resolve()
        if resolved in protected or any(inside(resolved, root) for root in (ROOT, project, sources)):
            raise ValueError(f'Output cannot overwrite approved/project/source files: {name}')
        if destination.exists() and not args.overwrite:
            raise FileExistsError(f'Staged file exists: {destination}; choose a new directory or --overwrite')
    output.mkdir(parents=True, exist_ok=True)
    return project, sources, provenance, selected, output


def decoded_pcm(path, channels):
    return subprocess.check_output([
        'ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(path),
        '-f', 's16le', '-ar', str(RATE), '-ac', str(channels), 'pipe:1',
    ])


def validate_output(path, duration, channels):
    info = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries',
        'stream=codec_name,sample_rate,channels:format=duration', '-of', 'json', str(path),
    ]))
    streams = info['streams']
    if len(streams) != 1 or streams[0]['codec_name'] != 'vorbis':
        raise ValueError(f'{path.name}: expected one Vorbis stream')
    if int(streams[0]['sample_rate']) != RATE or streams[0]['channels'] != channels:
        raise ValueError(f'{path.name}: incorrect sample rate/channels')
    if abs(float(info['format']['duration']) - duration) > .001:
        raise ValueError(f'{path.name}: incorrect stream duration')
    raw = decoded_pcm(path, channels)
    if len(raw) != round(duration * RATE) * channels * 2:
        raise ValueError(f'{path.name}: incomplete decoded sample timeline')
    data = np.frombuffer(raw, dtype='<i2').astype(np.float64) / 32768
    if not np.any(data) or np.max(abs(data)) >= .9999:
        raise ValueError(f'{path.name}: silent or clipped decoded audio')
    return {'file': path.name, 'sha256': digest(path), 'bytes': path.stat().st_size,
            'duration': duration, 'channels': channels, 'rate': RATE,
            'decoded_frames': len(raw) // (channels * 2),
            'decoded_pcm_sha256': hashlib.sha256(raw).hexdigest()}


def measure_loudness(path):
    result = subprocess.run([
        'ffmpeg', '-hide_banner', '-i', str(path),
        '-af', 'loudnorm=I=-18.46:TP=-1.5:LRA=9:print_format=json',
        '-f', 'null', '-',
    ], capture_output=True, text=True, encoding='utf-8', errors='replace', check=True)
    log = result.stderr
    values = json.loads(log[log.rfind('{'):log.rfind('}')+1])
    if not math.isfinite(float(values['input_i'])) or abs(float(values['input_i']) + 18.46) > .25:
        raise ValueError(f'Unexpected rebuilt loudness: {values["input_i"]} LUFS')
    if float(values['input_tp']) >= -1.0:
        raise ValueError(f'Insufficient true-peak headroom: {values["input_tp"]} dBTP')
    return {name: values[name] for name in ('input_i', 'input_tp', 'input_lra', 'input_thresh')}


def main():
    args = parse_args()
    project, sources, provenance, selected, output = prepare_inputs(args)
    report_path = output / 'assembly-report.json'
    report_path.write_text(json.dumps({'result': 'building', 'note': 'Staged candidates, not promoted runtime audio.'}) + '\n', encoding='utf-8')
    voice_stem = np.zeros((N, 2))
    dialogue_windows = []
    records = []

    subtitle_times = [(6.2, 8.95), (9.0, 11.45), (11.7, 13.7),
                      (13.8, 16.25), (16.4, 20.25), (20.9, 24.8)]
    for index, row in enumerate(selected):
        source = sources / (row['key'] + '.mp3')
        original = read_audio(source)
        target_seconds = row['target_duration']
        count = round(target_seconds * RATE)
        speed = (len(original) / RATE) / target_seconds
        filters = [f'aresample={RATE}']
        if speed > 1.01:
            filters.append(f'atempo={speed:.12g}')
        filters += ['highpass=f=140', 'lowpass=f=10000', 'treble=g=-2:f=5000',
                    f'apad=whole_len={count}', f'atrim=end_sample={count}',
                    'afade=t=in:st=0:d=0.006',
                    f'afade=t=out:st={target_seconds-.016:.6f}:d=0.016']
        raw = subprocess.check_output([
            'ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(source),
            '-af', ','.join(filters), '-ac', '1', '-ar', str(RATE),
            '-f', 'f32le', 'pipe:1',
        ])
        clip = np.frombuffer(raw, dtype='<f4').astype(np.float64)
        assert len(clip) == count, (row['key'], len(clip), count)
        clip -= clip.mean()
        stride = round(RATE * .02)
        level_windows = [clip[i:i+stride] for i in range(0, len(clip), stride)]
        levels = np.asarray([rms(part) for part in level_windows])
        active = np.concatenate([part for part, level in zip(level_windows, levels)
                                 if level > max(.0025, levels.max()*.10)])
        active_target = .084 if row['key'].startswith('commander') else .075
        gain = min(active_target / max(rms(active), 1e-9), .48 / max(abs(clip).max(), 1e-9))
        clip *= gain
        wav = output / (row['key'] + '.wav')
        ogg = output / (row['key'] + '.ogg')
        write_wav(wav, clip)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav),
             '-c:a', 'libvorbis', '-q:a', '5', '-map_metadata', '-1', str(ogg)])
        at = round(row['target_start'] * RATE)
        assert at + len(clip) < N
        voice_stem[at:at + len(clip)] += np.column_stack((clip, clip))
        dialogue_windows.append((row['target_start'], row['target_start'] + target_seconds))
        records.append({**row, 'source_sha256': digest(source),
                        'raw_duration': len(original)/RATE, 'atempo': speed if speed > 1.01 else 1,
                        'runtime_file': ogg.name, 'runtime_sha256': digest(ogg),
                        'runtime_frames': len(clip), 'runtime_duration': target_seconds,
                        'runtime_peak': float(abs(clip).max()), 'runtime_rms_dbfs': db(rms(clip)),
                        'normalization_gain': gain, 'active_regions': active_regions(clip),
                        'subtitle_start': subtitle_times[index][0], 'subtitle_end': subtitle_times[index][1]})

    # Original four-cylinder game loops: crossfade RPM layers instead of a
    # generic V8 recording. This departure recedes before the first squirrel.
    rpms = [900, 2700, 4500, 6300]
    rpm_curve = np.interp(T, [0, .4, 1.2, 2.3, 3.4, 4.4, 5.6, 7, SECONDS],
                         [900, 1100, 2400, 3300, 4500, 6200, 5700, 4500, 4500])
    engine = np.zeros(N)
    fx_sources = []
    for index, rpm in enumerate(rpms):
        path = project / f'assets/vehicle_audio/engine_{rpm:04d}_load.wav'
        track = repeated(path)
        if index == 0:
            weight = np.clip((rpms[1] - rpm_curve) / (rpms[1] - rpms[0]), 0, 1)
        elif index == len(rpms)-1:
            weight = np.clip((rpm_curve - rpms[-2]) / (rpms[-1] - rpms[-2]), 0, 1)
        else:
            weight = np.minimum(np.clip((rpm_curve-rpms[index-1])/(rpm-rpms[index-1]),0,1),
                                np.clip((rpms[index+1]-rpm_curve)/(rpms[index+1]-rpm),0,1))
        engine += track * weight
        fx_sources.append({'file': str(path.relative_to(project)), 'sha256': digest(path)})
    engine *= envelope([(0,0),(.15,.40),(1.5,.44),(3,.40),(4.2,.32),(5.5,.16),(6.5,.025),(7,0),(SECONDS,0)])
    engine_stereo = pan(engine, np.interp(T,[0,3.5,7,SECONDS],[-.12,.08,.22,.22]))

    rotor_path = project / 'assets/level2/pursuit/rotor.wav'
    rotor_source = read_audio(rotor_path)
    rotor_source -= rotor_source.mean()
    speed = envelope([(0,.28),(19.8,.28),(20.7,.45),(21.8,.80),(22.6,1),(SECONDS,1)])
    phase = np.cumsum(speed)
    rotor = np.interp(np.mod(phase, len(rotor_source)),np.arange(len(rotor_source)),rotor_source)
    rotor *= envelope([(0,0),(19.8,0),(20.2,.16),(21.0,.38),(22.6,.54),(25.4,.50),(25.98,0),(SECONDS,0)])
    rotor_stereo = pan(rotor, np.interp(T,[0,20,23,26],[.10,.10,0,-.06]))
    fx_sources.append({'file': str(rotor_path.relative_to(project)), 'sha256': digest(rotor_path)})

    wind_path = project / 'assets/level1/audio/park_wind.ogg'
    wind = repeated(wind_path)
    wind *= .008 / max(rms(wind), 1e-9)
    wind *= envelope([(0,0),(.6,1),(18.5,1),(20,0),(SECONDS,0)])
    ambience = np.column_stack((wind, np.roll(wind, round(.012*RATE))))
    fx_sources.append({'file': str(wind_path.relative_to(project)), 'sha256': digest(wind_path)})
    effects_stem = engine_stereo + rotor_stereo + ambience

    # Smooth -9dB duck around each line; keep ambience/rotor below the voices.
    duck = np.ones(N)
    for start, end in dialogue_windows:
        shape = np.interp(T, [0,max(0,start-.12),start,end,end+.18,SECONDS],
                          [1,1,10**(-9/20),10**(-9/20),1,1])
        duck = np.minimum(duck, shape)
    effects_stem *= duck[:,None]
    # Preserve the accepted mastering chain: print the quiet16-bit premaster,
    # then apply exactly+4dB through FFmpeg. Direct float scaling changes the
    # quantization/encoder input, so it is deliberately not substituted here.
    premaster = voice_stem + effects_stem
    premaster_gain = min(1, .74/max(abs(premaster).max(),1e-9))
    premaster *= premaster_gain
    premaster[-round(.020*RATE):] *= np.linspace(1,0,round(.020*RATE))[:,None]
    master_gain_db = 4.0
    master_gain = 10**(master_gain_db/20)
    if abs(premaster).max() * master_gain >= .88:
        raise ValueError('Rebuilt premaster lacks the reviewed+4dB headroom')
    write_wav(output/'voices-stem.wav',voice_stem)
    write_wav(output/'effects-stem.wav',effects_stem)
    write_wav(output/'park_escape_mix_premaster.wav',premaster)
    run(['ffmpeg','-hide_banner','-loglevel','error','-y',
         '-i',str(output/'park_escape_mix_premaster.wav'),'-af','volume=4dB',
         '-c:a','pcm_s16le',str(output/'park_escape_mix.wav')])
    with wave.open(str(output/'park_escape_mix.wav'), 'rb') as stream:
        if (stream.getframerate(), stream.getnchannels(), stream.getnframes()) != (RATE, 2, N):
            raise ValueError('Incomplete mastered PCM timeline')
        mix = np.frombuffer(stream.readframes(N), dtype='<i2').reshape(-1,2).astype(np.float64)/32768
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(output/'park_escape_mix.wav'),
         '-c:a','libvorbis','-q:a','5','-map_metadata','-1',str(output/'park_escape_mix.ogg')])
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(output/'park_escape_mix.wav'),
         '-c:a','libmp3lame','-b:a','192k','-map_metadata','-1',str(output/'park_escape_preview.mp3')])
    cues = [{'start': spec[3], 'end': spec[4], 'speaker': spec[5], 'text': spec[6]} for spec in SPECS]
    (output/'subtitle-cues.json').write_text(json.dumps({'duration': SECONDS, 'cues': cues},ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    validation = [validate_output(output / (spec[0]+'.ogg'), spec[2], 1) for spec in SPECS]
    validation.append(validate_output(output/'park_escape_mix.ogg', SECONDS, 2))
    loudness = measure_loudness(output/'park_escape_mix.ogg')
    report = {'kind': 'park_escape_audio_candidates', 'result': 'PASS',
              'note': 'External candidates only. No approved runtime file or manifest was changed.',
              'scene': provenance.get('scene', 'park_escape_manga_145'),
              'source_report_sha256': digest(args.provenance.resolve()),
              'source_review': provenance.get('perceptual_review', 'Human audition remains separate.'),
              'generation_credits': sum(int(row['requested_credits']) for row in records),
              'paid_calls_by_this_tool': 0,
              'utterances': records, 'subtitle_cues': cues,
              'rate':RATE,'channels':2,'frames':N,'duration':SECONDS,
              'fx_sources':fx_sources,'premaster_gain':premaster_gain,
              'master_gain':master_gain,'master_gain_db':master_gain_db,
              'mix_peak':float(abs(mix).max()),'mix_rms_dbfs':db(rms(mix)),
              'clipped_pcm_samples':int(np.count_nonzero(abs(mix)>=1)),
              'runtime_mix':'park_escape_mix.ogg',
              'runtime_mix_sha256':digest(output/'park_escape_mix.ogg'),
              'runtime_mix_bytes':(output/'park_escape_mix.ogg').stat().st_size,
              'approved_runtime_mix_sha256':provenance.get('runtime_mix_sha256'),
              'master_pcm_sha256':hashlib.sha256(decoded_pcm(output/'park_escape_mix.wav',2)).hexdigest(),
              'decoded_vorbis_loudness':loudness,'encoded_checks':validation,
              'assembly_tool_sha256':digest(Path(__file__).resolve()),
              'ffmpeg_version':subprocess.check_output(['ffmpeg','-version'],text=True,encoding='utf-8',errors='replace').splitlines()[0],
              'sync_note':'Cue starts are relative to movie clock0; one continuous26s stream. Voice and caption end times differ deliberately.',
              'mix_note':'Centered creature calls; original game four-cylinder loops, rotor spin-up and quiet park wind. FX duck-9dB during calls. No voice pitch shifting; original MP3s untouched.'}
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'duration':SECONDS,'frames':N,'peak':report['mix_peak'],
                      'rms_dbfs':report['mix_rms_dbfs'],'bytes':report['runtime_mix_bytes'],
                      'source_cost':report['generation_credits'],'clips':len(records)},indent=2))
    print('PARK ESCAPE AUDIO: PASS — pinned sources, complete26s timeline, six cues and safe+4dB master; candidates only')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'PARK ESCAPE AUDIO: {type(exc).__name__}: {exc}', file=sys.stderr)
        raise SystemExit(1)
