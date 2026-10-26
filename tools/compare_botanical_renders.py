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
        # Geometry silhouettes intentionally replace sampled alpha interiors.
        # Keep the original strict bound outside the foliage region, and bound
        # the intentional foliage change separately. Both masks are actual
        # engine renders with original transparency and opaque occluders.
        from PIL import ImageFilter
        with Image.open(reference / f'{name}-foliage.png') as am, Image.open(optimized / f'{name}-foliage.png') as bm:
            region = ImageChops.lighter(am.convert('L'), bm.convert('L')).point(lambda p: 255 if p > 8 else 0).filter(ImageFilter.MaxFilter(9))
        outside = ImageChops.invert(region)
        outside_count = sum(outside.histogram()[1:])
        outside_diff = ImageChops.multiply(difference, outside.convert('RGB'))
        outside_mae = sum(ImageStat.Stat(outside_diff).sum) / max(1, outside_count*3)
        outside_max = ImageChops.multiply(maximum,outside)
        outside_changed = sum(outside_max.histogram()[9:]) / max(1,outside_count)
        if outside_mae > .2 or outside_changed > .001:
            failures.append(f'{name}: non-foliage image changed (MAE={outside_mae:.4f}, >8 pixels={outside_changed:.5%})')
        if mae > 1.0 or changed > .01:
            failures.append(f'{name}: reconstructed foliage changed too much (MAE={mae:.4f}, >8 pixels={changed:.5%})')
        if opt['triangles'] > 260000 or opt['calls'] > 500:
            failures.append(f'{name}: reconstructed geometry exceeds 500-call/260k workload cap')
        foliage = opt.get('foliage', {})
        if foliage.get('masked_area_ratio',1) > .35 or foliage.get('opaque_area_estimate',0) <= 0:
            failures.append(f'{name}: cutout area was not reduced by at least 65%')
        rows.append(dict(view=name, mae_8bit=mae, changed_pixels_over_8=changed,
                         reference_triangles=ref['triangles'], optimized_triangles=opt['triangles'],
                         triangle_reduction=1-opt['triangles']/ref['triangles'],
                         reference_calls=ref['calls'], optimized_calls=opt['calls'],
                         reference_median_ms=ref['median_ms'], optimized_median_ms=opt['median_ms'],
                         advisory_speedup=ref['median_ms']/opt['median_ms'],
                         cull_cpu_us=opt.get('cull_cpu_us'), outside_mae=outside_mae, outside_changed_fraction=outside_changed, foliage=foliage))
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
    print('BOTANICAL FIDELITY: PASS — bounded foliage reconstruction, unchanged background, reduced cutout area; timings advisory')


if __name__ == '__main__':
    main()
