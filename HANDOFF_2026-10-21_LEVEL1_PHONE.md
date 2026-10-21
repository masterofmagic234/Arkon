# Level 1 phone regression and masonry — Android 1.28 / code 29

Repo masterofmagic234/Arkon, branch fix/level2-final-game-flow, PR11.
Do not merge automatically. Baseline source 9f76ecf0254e98a1b913ce395888be908616e213,
tree 1abda7eb385edb79f13c97c9177348cfe9349aee, successful Actions #1051
(39552059613). The user reports that 1.27 is unplayable on the phone and the
main walls look terrible. Green visual/gameplay CI did not establish phone FPS.
This handoff supersedes performance/material claims in ESTATE_REBUILD; its
spatial progression and the helicopter fix remain in place.

## Findings

The park boundary uses level1_terrain_edge.gdshader: several layers of sine-based
procedural fragment noise across huge wall surfaces. The existing photographed
1024px park_outer_limestone.jpg was assigned only to some cover architecture,
not the main walls. Boundary cells also submitted complete cubes; shared faces
were hidden but still present. Separate material/shape batches, ten meshes per
gate leaf and six small meshes per pickup inflated submission count. Full-screen
Forward+ glow and physical phone resolution compound the fragment work.

Ablation on native Vulkan llvmpipe LLVM20 at 1280x720, same entry/lake poses:
1.27 full draw/readback medians 149.9 / 103.5 ms; disabling glow alone 82.3 /
74.3 ms. Replacing only the noisy walls was not enough, especially at the lake.
These are host comparisons, NOT phone FPS measurements or guaranteed speedups.

## Changes

- level1_estate_walls.gd builds a closed masonry shell from the same physical
  boundary cells. Shared interior faces are removed; lake/forest backs stay
  closed because they are visible from other routes. Coping is actual geometry.
  One shared, mipmapped, world-space limestone material keeps block scale across
  corners. Correct clockwise outward winding and physical backing are tested.
  The procedural terrain shader is no longer loaded by the level.
- Main masonry, ground, paths, grass, shrub and surface shaders use vertex
  lighting. Ground patches are 24m with subdivisions to retain lantern pools.
  The stone keeps a single anisotropic sample; main-wall derivative bump is off.
  Boundary shrub crowns use a cheaper closed mesh; shrubs stay above wall caps.
- Immutable wood/stone/metal furniture shares vertex-coloured material batches
  per 24m block, with existing detail texture and emission. This consumes the
  original CPU transforms directly; no mutable MultiMesh readback/reassembly.
  Tree LOD batches retain their 12m granularity. Every gate leaf is one shared
  coloured mesh under the original moving pivot/collision. Every rotating
  pickup is one surface; the stationary pedestal and real Area3D stay separate.
- Water rejects lanterns beyond the existing 18m reflection range before costly
  normalization/power operations. Reflections inside that range remain intact.
- Android activates a scene-local mobile profile: full-screen glow off; 3D
  target at most 1280x720 pixels, preserving a lower prior scale if one exists.
  Full-HD 3D scale is 2/3; wider aspect ratios retain their aspect. UI stays at
  the physical display size. Resize updates the cap; leaving Level1 restores
  the old viewport scale before the chase. Desktop keeps its full resolution
  and glow. Global renderer stays Forward+; no project-wide renderer downgrade.

No map, collision, key order, puzzle, AI, enemy count, combat, audio, input or
campaign semantics were changed. The three shortcuts and independent branches
from 1.27 are retained.

## Verification

All 21 existing headless gates pass locally, including all three input-driven
Level1 routes, native-geometry/physics consistency, mobile profile lifecycle,
intro, full pursuit, diner and complete campaign flow. The estate fixture now
checks outward face winding and physical support of masonry triangles, three
phone sizes, glow state and restoration on scene exit. Shrub clearance checks
include the new crown mesh.

Native Forward+ mobile captures check the actual profile, wall closeup, all
landmarks, return bridge and two control layouts. New level1_render_budget.gd
uses current production poses and fails above 260 draw calls / 150k triangles;
1.27's entry/lake exceed that submission budget. It also checks the real Full-HD
framebuffer/UI size, 3D pixel cap and scene-exit restoration. CI runs it alongside
native gameplay/renderer checks and uploads the evidence.

Measured entry: 381 -> 222 calls; lake 323 -> about 199. Representative mobile
host draw/readback medians: entry 75.2ms, lake 59.3ms, greenhouse 61.0ms, oak
69.0ms, before final wall-shell closure/winding correction. Timings include
readback and are not device benchmarks; final exact counters belong to CI/PR.

Real phone FPS is unmeasured here. Do not claim 30/60 FPS, or that a green build
proves the reported device is now smooth. Record the exact source SHA, matching
successful Actions run, tested merge-tree equality and downloaded APK manifest,
bytecode, renderer and integrity checks in PR11's description after building.
