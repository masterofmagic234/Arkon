CEDAR support hand source

The retained JSON contains ONLY the left hand and forearm from MakeHuman
Community model DATA, explicitly released under CC0 in September 2020.
The model header and the rig/weight JSON licence fields explicitly say CC0.
The upstream application code licence (GPL) is a separate file and was not used.

SOURCES.json pins the immutable upstream commit, URLs and exact SHA-256 hashes.
original_vertex_ids maps the subset back to base.obj for independent auditing.
The original weapon, procedural pose solver, extraction script and Blender
authoring code were written for this game; no upstream program code is copied.

Reproduce source subset:
1. Download the four immutable source URLs in SOURCES.json into a temporary dir.
2. python tools/extract_cedar_hand_source.py --upstream-dir /temporary/directory
   The extractor verifies the four pinned hashes before parsing anything.
3. blender -b --factory-startup -P tools/build_modern_conegun.py
   CEDAR_OUTPUT_DIR can redirect all model/provenance output for offline review.
   CEDAR_SKIP_RENDER=1 skips only the offline reference render.

The root art directory is authoring-only and is excluded from APK exports.
Only the final opaque GLB, tiny embedded PBR atlases and CC0 notice are needed
at runtime. This subset does not contain a whole unclothed human model.

Exact upstream model-data header (base.obj, pinned hash in SOURCES.json):
# This is a mesh file for MakeHuman
#
# This asset was explicitly released as CC0 in september 2020. The license
# text for CC0 can be found in the root of this repository.
#
# The copyright holders at the point of the release to CC0 were:
#
# Copyright (C) 2020 Data Collection AB, https://www.datacollection.se
# Copyright (C) 2020 Joel Palmius
# Copyright (C) 2020 Jonas Hauquier
#
# The primary legal contact for MakeHuman is Data Collection AB.
#
# For more information, see homepage at http://www.makehumancommunity.org
#
# basemesh hm08

The default.mhskel and default_weights.mhw JSON data each state "license": "CC0".
