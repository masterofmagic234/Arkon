#!/usr/bin/env python3
"""Gate native render fidelity and workload; software-GPU timings are advisory.

Requires Pillow. Both directories come from botanical_benchmark.gd with the same
renderer, camera sequence, pixel cap and MSAA. --reference selects the original
1.33 geometry/material path in the current source. No generated artwork is used.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageStat


def compare(reference, optimized):
    before = json.loads((reference / 'benchmark.json').read_text())
    after = json.loads((optimized / 'benchmark.json').read_text())
    failures, rows = [], []
    for field in ('renderer', 'adapter'):
        if before[field] != after[field]:
            failures.append(f'{field} differs between runs')
    by_view = {v['view']: v for v in after['views']}
    for ref in before['views']:
        name = ref['view']
        opt = by_view[name]
        with Image.open(reference / f'{name}.png') as a, Image.open(optimized / f'{name}.png') as b:
            if a.size != b.size:
                failures.append(f'{name}: image sizes differ')
                continue
            difference = ImageChops.difference(a.convert('RGB'), b.convert('RGB'))
            mae = sum(ImageStat.Stat(difference).mean) / 3
            bands = difference.split()
            maximum = ImageChops.lighter(ImageChops.lighter(bands[0], bands[1]), bands[2])
            histogram = maximum.histogram()
            changed = sum(histogram[9:]) / (a.width * a.height)
        if mae > .2 or changed > .001:
            failures.append(f'{name}: visible image changed (MAE={mae:.4f}, >8/255 pixels={changed:.5%})')
        if opt['triangles'] > ref['triangles'] * .85:
            failures.append(f'{name}: geometry reduction is below 15%')
        if opt['calls'] > ref['calls'] + 2:
            failures.append(f'{name}: extra draw calls')
        rows.append(dict(view=name, mae_8bit=mae, changed_pixels_over_8=changed,
                         reference_triangles=ref['triangles'], optimized_triangles=opt['triangles'],
                         triangle_reduction=1-opt['triangles']/ref['triangles'],
                         reference_calls=ref['calls'], optimized_calls=opt['calls'],
                         reference_median_ms=ref['median_ms'], optimized_median_ms=opt['median_ms'],
                         advisory_speedup=ref['median_ms']/opt['median_ms'],
                         cull_cpu_us=opt.get('cull_cpu_us')))
    speedup = math.exp(sum(math.log(r['advisory_speedup']) for r in rows)/len(rows))
    return dict(views=rows, failures=failures, advisory_geomean_speedup=speedup,
                note='Native software-GPU frames. Timing is advisory, not phone FPS. Fidelity and submitted geometry are gated.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('optimized', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = compare(args.reference, args.optimized)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    if report['failures']:
        raise SystemExit(1)
    print('BOTANICAL FIDELITY: PASS — original look, reduced geometry, no extra draw calls; timings advisory')


if __name__ == '__main__':
    main()
