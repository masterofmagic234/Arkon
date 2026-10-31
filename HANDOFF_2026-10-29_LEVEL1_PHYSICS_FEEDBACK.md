# Android 1.50 — garden collision, support hand and damage feedback

The owner requested three focused Level 1 corrections: solid world geometry for
Carolina and squirrels, a more natural supporting hand, and visible feedback when
Carolina takes damage. This release retains the 1.49 mission and encounters,
Compatibility renderer, baked garden lighting, animal voices and articulated
defeats. Keep PR11 a draft; do not merge automatically.

## World contact and movement

Visible walls, rocks and floors must agree with physical collision for the player
and squirrels. Tests must exercise movement against the real garden geometry,
including walking and dashing, both directions where applicable, and real actor
routes across stairs, terraces and open passages. A blocked route must be routed
around its obstacle; do not fix a test by disabling collision or moving an actor
through a wall. World collider repairs must preserve traversable intended paths,
the powered pond bridge, closed hydraulic barriers and access to every encounter.
Two visible half-steps at the conservatory and pavilion thresholds make their
raised floors reachable within the shared20cm step limit. These are additional
visible geometry, and the renderer-only A/B fixture excludes them equally from
both profiles while production scene proof includes them.

World collision uses the retained CPU transforms supplied to authoring, including
batched instances. Headless rendering does not preserve MultiMesh transform
buffers and cannot supply collision placements. Source-matched native proof
compares all authored transforms with the immutable original GPU uploads and
checks membership of the renderer's repacked visible instances. Its placement
digest must agree with headless collision proof. Rendering buffers and culling
are not changed by that audit.

The garden duplicates the player's capsule to1.70m with a local+.25m offset,
protecting the1.55m eye while preserving feet at root−.60m. Legacy scenes retain
their original1.20m resource. Actual1.40m headroom blocks the garden body and2m
headroom permits normal movement. Save recovery uses the actual shape offset.
Twelve enclosed-rock query volumes on layer64 reject cold-load positions and
navigation endpoints wholly inside concave shells. Live body and weapon masks
ignore these query volumes; their collision still uses the physical surfaces.
The focused actor proof derives any slope support allowance from the measured
normal and capsule radius; ordinary flat spawns must be within4cm of the floor.

Navigation coverage must establish physical clearance and successful movement.
The number of sampled graph points is diagnostic rather than a substitute for
those behavior checks. Any replacement of an inherited point-count assertion
must document the actual navigation implementation change and retain the former
wall, gate, terrace, patrol, search, projectile and save-ID acceptance.

## Supporting hand

Keep the actual CEDAR gun identity, fixed muzzle socket, source attribution,
three opaque batches, bounded mesh budget and first-person render-layer policy.
The authorized change is the anatomical support pose and its material finish:
relax the wrist, place the thumb along the foregrip, curl fingers at their joints
with real grip contact, and fit the cuff to the forearm. Preserve continuous
source skin, a bounded contact gap/penetration, walking bob and real shot recoil.
Review native front, side, support-hand and gameplay views, including wide-phone
framing. Geometry/contact metrics supplement the visual review.

## Damage feedback

Accepted damage must produce a clear visible cue in the real gameplay framebuffer
without obscuring aim or touch controls. Rejected hits must not advertise damage
that was not applied. Feedback must respect pause and screen/modal lifecycle,
return to a clear state, and remain consistent with real health changes, retry,
save/load and the existing protected damage sound. Focused native captures must
show onset, fade and cleanup; numerical state alone does not establish visibility.

## Preserved gameplay and release proof

Retain all 25 stable squirrel IDs, five mandatory encounter groups, optional
rewarded groups, one nearby fuse and panel action, western glass-gallery route,
two-phase guardian with at least five openings, six earned acorns, physical
escape, car boarding and the existing manga-to-Level2 transition. Preserve all
sixteen living clips, five death clips, thirty animal vocal files, the original
35 PCM recordings, and unrelated Level2/3, intro, manga, touch, pause, map, save
and migration checks.

Fresh normal-input acceptance must walk around repaired obstacles using ordinary
movement, fire, dash and interaction. No health/ammunition, quest, actor-state or
position overrides may be used in that full-route evidence. Isolated geometry,
AI, weapon and feedback fixtures must identify their staged scope explicitly.
Native PNGs, JSON and sampled footage are evidence from actual rendering; they
are not generated reference images or a phone FPS measurement.

Keep all retained 1.47/1.48/1.49 CI checks and finite timeouts. Add focused
headless/native collision, support-hand and damage-feedback checks and upload
their output beside the retained evidence. Preserve the neutral baked-world-only
ABBA renderer scope and its original structural/CPU/traffic thresholds. The
complete expanded mission has separate production/input validation.

Release target: Godot4.7.2, Android1.50/code51, arm64,
`com.acornhunter.carolina`, existing signing certificate. Final release acceptance
requires the exact committed source/merge tree, all three CI jobs, all four
canonical artifact digests/CRCs, strict complete-log scans, full uploaded
PNG/media/JSON review and independent inspection of the actual signed APK.
Local Godot4.7.2 acceptance passed the imported support-hand gate, legacy tank
and guard fixtures, physical AI/navigation, rules, evening, five save/migration
cases, bridge, damage feedback and a fresh normal-input route. The route used
74 actual shots/hits, five guardian openings and all21 animated/settled mandatory
defeats, then earned six acorns, crossed the bridge, cleared escape and boarded
into the existing manga and Level2. All17 recorded source fingerprints matched
the current working tree. Legitimate steering uses the glass wing's clear
northern aisle and approaches the solid reward plinth/car from outside.

The final focused collision gate also passed25 source-backed spawns, measured
flat/slope support, both scout/guardian bridge directions, both thresholds,
actual garden headroom, enclosed-rock clearance and a blocked flanker order's
cached, physically reached fallback. Only guard4 moved, from `(25,3,8)` to
`(25,3,10)`, clearing a planter rim; its stable save ID, role and group remain.
Matched headless/native collider data and native GPU-transform checks, approved
source-model hand views, and16 damage captures/pixel checks are separate local
evidence. These local checks are not
final signed-package acceptance. Final-source CI must repeat every retained
check and upload allfour official artifacts before delivery; PR11 records the
canonical results and independent actual-APK review.
