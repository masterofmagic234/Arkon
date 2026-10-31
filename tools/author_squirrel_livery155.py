"""Author outlined Cyrillic police markings; preserve the generated badge source.

The atlas is new vector artwork. No source vehicle texture is repainted: the
runtime projects these markings only onto the audited exterior paint mask.
"""
from __future__ import annotations
import argparse,hashlib,json,shutil
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/level2/fleet155'
FONT=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
BADGE_PROMPT='Original fictional squirrel forest police shield: ivory acorn with squirrel ears, sweeping brass squirrel tail, oak leaves, deep petrol field, ivory keyline; no text. Flat game decal with transparent background. Generated with image_gen on 2026-10-31.'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--badge-source',type=Path)
    args=parser.parse_args();OUT.mkdir(parents=True,exist_ok=True)
    if args.badge_source:
        shutil.copyfile(args.badge_source,OUT/'patrol_badge.png')
    assert (OUT/'patrol_badge.png').is_file(),'Provide original generated badge once'
    font=TTFont(FONT);glyphs=font.getGlyphSet();cmap=font.getBestCmap()
    units=font['head'].unitsPerEm
    def word(text,cx,baseline,size,max_width):
        names=[cmap[ord(c)] for c in text]
        advances=[font['hmtx'].metrics[n][0] for n in names]
        scale=min(size/units,max_width/max(sum(advances),1))
        cursor=cx-sum(advances)*scale/2;paths=[]
        for name,advance in zip(names,advances):
            pen=SVGPathPen(glyphs);glyphs[name].draw(pen)
            commands=pen.getCommands()
            if commands:paths.append(f'<path transform="translate({cursor:.5f} {baseline:.5f}) scale({scale:.8f} {-scale:.8f})" d="{commands}"/>')
            cursor+=advance*scale
        return ''.join(paths)
    # Top-left640x192: side lettering; top-right384x192: rear lettering.
    # Lower half: ten equal-width outlined digits. Transparent padding stops
    # mipmaps from pulling neighbouring glyphs into a door/unit number.
    groups=[word('ЛЕСНОЙ',320,82,83,586),word('ПАТРУЛЬ',320,172,84,592),
            word('БЕЛИЧЬЯ',832,77,57,344),word('ПОЛИЦИЯ',832,149,57,344)]
    for i in range(10):groups.append(word(str(i),51.2+i*102.4,458,168,78))
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="512" viewBox="0 0 1024 512"><g fill="#e6e4d4">'+''.join(groups)+'</g></svg>\n'
    (OUT/'patrol_marks.svg').write_text(svg)
    provenance={'version':155,'badge':{'file':'assets/level2/fleet155/patrol_badge.png','sha256':sha(OUT/'patrol_badge.png'),'tool':'image_gen','generated_date':'2026-10-31','prompt_summary':BADGE_PROMPT,'source_preserved':'Unedited tool output; runtime importer size limit512 with mipmaps.'},'marks':{'file':'assets/level2/fleet155/patrol_marks.svg','sha256':sha(OUT/'patrol_marks.svg'),'text':['ЛЕСНОЙ ПАТРУЛЬ','БЕЛИЧЬЯ ПОЛИЦИЯ','0123456789'],'font':'DejaVu Sans Bold','font_sha256':sha(FONT),'method':'Actual outlined glyph paths; no SVG text/font runtime dependency.'},'tool':'tools/author_squirrel_livery155.py','tool_sha256':sha(__file__),'runtime':'Original normal/lamp textures retained. Full coat coverage on audited exterior COLOR.r; original albedo contributes restrained luminance detail. Glass, chrome, tires and interior outside the mask retain their original textures. Object-space markings share the original opaque Body surface; no extra draw pass, camera or light.'}
    (OUT/'livery-provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'result':'PASS','badge_sha256':provenance['badge']['sha256'],'marks_sha256':provenance['marks']['sha256'],'marks_bytes':len(svg.encode())}))

if __name__=='__main__':main()
