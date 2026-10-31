#!/usr/bin/env python3
"""Compatibility entry point for the anatomically refitted Scout rig.

The former rigid seven-influence region mask and three-key sinusoid sampler are
replaced by tools/prepare_squirrel_rigs.py. Source mesh, UVs and original 1K
texture stay intact; all limb/ear/jaw/tail joints now carry actual smooth skin.
"""
from prepare_squirrel_rigs import ROOT, build_scout
import json
if __name__=='__main__':
    print(json.dumps(build_scout(ROOT/'scout_rigged.glb'),indent=2))
