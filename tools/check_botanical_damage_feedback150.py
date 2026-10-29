"""Check rendered hit visibility and clear aim centre in raw native captures."""
import argparse
import json
import math
from pathlib import Path

from PIL import Image


def require(ok, message):
    if not ok:
        raise ValueError(message)


def image(path):
    with Image.open(path) as raw:
        raw.load()
        return raw.convert('RGB')


def patch_mean(img, u, v, half=4):
    x, y = round(img.width * u), round(img.height * v)
    crop = img.crop((x-half, y-half, x+half, y+half))
    values = crop.tobytes()
    return tuple(sum(values[c::3]) / (crop.width * crop.height * 255) for c in range(3))


def edge_redness_change(before, after):
    require(before.size == after.size, 'Visibility comparison changed viewport')
    points = [(u, v) for u in [.015, .985] for v in [.35, .5, .65]]
    points += [(u, v) for v in [.015, .985] for u in [.35, .5, .65]]
    values = []
    for u, v in points:
        a, b = patch_mean(before, u, v), patch_mean(after, u, v)
        values.append((b[0]-b[1])-(a[0]-a[1]))
    return sum(values) / len(values)


def center_change(before, after):
    a = before.crop((before.width//2-28, before.height//2-28,
                     before.width//2+28, before.height//2+28))
    b = after.crop((after.width//2-28, after.height//2-28,
                   after.width//2+28, after.height//2+28))
    return sum(abs(x-y) for x, y in zip(a.tobytes(), b.tobytes())) / (a.width*a.height*3*255)


def direction_pixels(img, direction):
    scale = min(1.55, max(.5, min(img.width/1280, img.height/720)))
    radius = 98*scale
    cx, cy = img.width/2, img.height/2
    actual = opposite = 0
    for y in range(math.floor(cy-radius-10*scale), math.ceil(cy+radius+10*scale)):
        for x in range(math.floor(cx-radius-10*scale), math.ceil(cx+radius+10*scale)):
            dx, dy = x-cx, y-cy
            distance = math.hypot(dx, dy)
            if not radius-15*scale < distance < radius+9*scale:
                continue
            r, g, b = img.getpixel((x, y))
            if r < 150 or r < g*1.7 or r < b*1.6:
                continue
            dot = (dx*direction[0]+dy*direction[1])/distance
            if dot > .88:
                actual += 1
            elif dot < -.88:
                opposite += 1
    require(actual >= 60*scale*scale, 'Source marker is absent/too weak in expected quadrant')
    require(opposite < actual*.18+12, 'Source marker appears on the opposite side')
    return {'expected_quadrant_pixels': actual, 'opposite_quadrant_pixels': opposite}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = json.loads((args.captures/'damage150-report.json').read_text())
    require(report['result'] == 'PASS' and not report['failures'], 'Native state/input checks failed')
    rows = {row['id']: row for row in report['snapshots']}
    require(len(rows) == 16 and report['accepted_hits'] == 9, 'Missing actual hit/aspect/lifecycle samples')
    images = {name: image(args.captures/(name+'.png')) for name in rows}
    for name, img in images.items():
        require(list(img.size) == rows[name]['viewport'], 'Raw capture dimensions disagree with native report')
    pairs = [('desktop', '00-undamaged', '01-right-hit', '02-paused'),
             ('phone', '11-phone-undamaged', '12-phone-hit', '13-phone-paused')]
    checks = {}
    for label, base, hit, paused in pairs:
        delta = edge_redness_change(images[base], images[hit])
        center = center_change(images[base], images[hit])
        pause_delta = edge_redness_change(images[base], images[paused])
        require(delta > .025, label+': actual red hit edges are not visibly stronger than baseline')
        require(center < .05, label+': damage tint/response obscures the aiming centre')
        require(abs(pause_delta) < .018, label+': paused view retains the red damage vignette')
        checks[label] = {'edge_redness_increase': delta, 'centre_rgb_MAE': center,
                         'paused_edge_redness_change': pause_delta, 'size': list(images[base].size)}
    bearings = {}
    for name, direction in [('01-right-hit', (1, 0)), ('05-front-hit', (0, -1)),
                            ('05-rear-hit', (0, 1)), ('05-left-hit', (-1, 0))]:
        bearings[name] = direction_pixels(images[name], direction)
    low = edge_redness_change(images['09-healed'], images['07-low-health'])
    require(low > .008, 'Critical health warning is invisible after the immediate hit expires')
    result = {'result': 'PASS', 'captures_fully_decoded': len(images), 'comparisons': checks,
              'source_markers': bearings, 'low_health_redness_increase': low,
              'scope': 'Independent raw native pixels: visible soft hit edges on desktop/phone, clear central aim, hidden pause tint, four correct source quadrants and sustained critical-health cue. No device FPS claim.'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('BOTANICAL DAMAGE150 PIXELS: PASS')


if __name__ == '__main__':
    main()
