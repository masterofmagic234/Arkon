# ACORN HUNTER — PROJECT CONTEXT HANDOFF

> **Purpose:** this file is the continuity document for future ChatGPT chats working on ACORN HUNTER. Read this before changing the project. It summarizes the creative context, relationship/lore context relevant to the game, the history of the game and related gifts/sites, the technical architecture, current assets, known failures, current implementation, and the agreed development rules.
>
> **Repository:** `masterofmagic234/Arkon`
> **Branch:** `main`
> **Engine:** Godot 4.7
> **Renderer:** GL Compatibility
> **Primary platform:** Android
>
> ---
>
> ## IMPORTANT PRIVACY NOTE
>
> This repository is public. The original private Telegram correspondence, private screenshots, contact information, and other personal/private source material must **not** be copied into this public repository verbatim. This handoff preserves only the relationship/lore information that is relevant to understanding the creative intent of ACORN HUNTER. If exact private messages or screenshots are needed, retrieve them from the private conversation/files rather than putting them here.

---

# 1. WHAT ACORN HUNTER IS

ACORN HUNTER is a personal, deliberately absurd game built around an inside joke involving Carolina and her younger sister Darina.

The central joke escalates from an ordinary domestic problem into an absurd action-game adventure:

`поделка на завтра → нужны жёлуди → Каролина идёт за желудями → белки мешают → белки преследуют Каролину → белка-мобили → синяя Ока → гоночная игра → выясняется, что всё было кошмаром → белки всё равно стоят за окном`

The game should feel simultaneously:

- personal;
- affectionate;
- ridiculous;
- unexpectedly cinematic;
- like a serious game that takes an obviously unserious premise completely seriously.

Do **not** turn it into a generic "AI gift website" or meta presentation. The core joke is the story itself.

---

# 2. CAROLINA / DARINA CREATIVE CONTEXT

Carolina is the main character of the story. Darina is her younger sister and the direct cause of the initial quest.

Relevant established lore:

- Carolina is tired/sleeping at night in her room.
- Darina comes to her because they have been assigned a craft/project for the next day.
- The required craft becomes the trigger for the acorn hunt.
- Carolina reluctantly decides to deal with it.
- The hunt for acorns is treated as a legendary operation rather than a mundane errand.
- Squirrels are the recurring comic antagonists.
- Darina is associated with the acorn quest and the emotional motivation behind it.
- The recurring joke language includes `ОПЕРАЦИЯ «ЖЁЛУДЬ»`, `ЖЁЛУДЬ`, `КОНТУЖЕННЫЕ БЕЛКИ`, and `ШИШКА`.

The game originated from real personal jokes and gifts. The emotional context matters for the writing and visual tone, but private relationship details should not be reproduced publicly unless explicitly required and safe to do so.

---

# 3. RELATED PERSONAL PROJECT HISTORY

Before ACORN HUNTER, several creative gifts/projects were made around Carolina and her family.

Known project history:

1. A presentation made for Carolina.
2. A personal website for Carolina, developed through multiple versions (the history was referred to as v1 through later versions, including v9/v10 in prior discussions).
3. A separate website made for Carolina's mother.
4. Later, ACORN HUNTER became the larger interactive game project.

The important continuity point is that ACORN HUNTER is **not an unrelated generic game**. It is the latest and most elaborate form of a long-running personal creative project.

The exact source files for every historical presentation/site version are not all present in the current public repository. Do not invent missing details. If exact historical wording/design is required, retrieve the original file from the private conversation/library.

One related HTML artifact currently exists in the private file library and is a site for Carolina's mother, titled `Для мамы — с любовью от Каролины`. It contains sections about the mother, a letter from Carolina, a promise/modal, animated stars/petals, and a sentimental visual design. It is useful evidence of the style and emotional continuity of the earlier gift projects, but it should not be mistaken for Carolina's own personal site.

---

# 4. ORIGINAL GAME CONCEPT

The original multi-level concept was intentionally built as a mash-up of different game eras/styles.

## Level 1 — Wolfenstein-style FPS

- Night park/forest.
- First-person perspective.
- Fixed camera height; no free vertical camera look.
- Wolfenstein 3D / raycasting spirit.
- Player searches for acorns.
- Oak trees are part of the environment.
- Squirrels are enemies.
- Squirrels have 2 HP.
- They are stunned rather than killed.
- Pinecone (`ШИШКА`) is a false pickup/trap and causes HP loss.
- Canonical baseline included a 20×14 map.
- Canonical baseline included 9 oak trees.
- Canonical baseline included 4 acorns.
- Canonical baseline included 2 squirrels.
- Night atmosphere.
- HUD.
- Minimap.
- Carolina portrait.
- Weapon.
- Music.

Known humorous lines include variations of:

- `Парк открыт. Ищи дубы — жёлуди рядом.`
- `ЖЁЛУДЬ! Дарина одобряет.`
- `ЖЁЛУДЬ НАЙДЕН. ОПЕРАЦИЯ ЗАВЕРШЕНА`
- `ШИШКА`
- `контуженные белки`

The old working build `acorn_hunter_CAROLINA_v7_THREE_ERAS.zip` was the main conceptual reference for Level 1. The later Godot rebuild should preserve its gameplay essence, object relationships, atmosphere, jokes, and overall character, but should **not literally port the old raycaster implementation**.

## Level 2 — NES racing homage

The intended second level is a direct style homage to `Ferrari Grand Prix Challenge` for NES.

- Carolina gets into her blue Oka.
- Squirrels chase her in squirrel-mobiles.
- The level becomes a retro racing game.
- `Race Theme 1.mp3` is associated with the racing level.

The point is the absurd genre transition: the player goes from a Wolfenstein-like FPS to a NES-era racing game because the squirrels have escalated the situation.

## Later / Level 3 concept

Older versions contained a third modern-3D/OpenGL-style era. Earlier V7 planning described three engines/eras in one APK:

1. Level 1 — raycast/Wolfenstein-style FPS.
2. Level 2 — NES-style racing.
3. Level 3 — modern OpenGL ES 3D scene.

However, the current rebuild effort is focused first on Level 1 and the surrounding story/cutscenes. Do not start implementing Level 3 unless explicitly requested.

---

# 5. FULL INTENDED STORY

The intended narrative sequence is:

## Opening

1. Title screen.
2. Opening cinematic in Carolina's bedroom at night.
3. Carolina is sleeping in bed.
4. Darina appears at the bedroom door.
5. Darina says:

   `Оййй, а нам кстати поделку на завтра задали..........`

6. Carolina is annoyed but agrees to deal with it.
7. The story transitions into Level 1.

## Level 1

Carolina goes on the absurd acorn hunt.

The player collects acorns, encounters squirrels, and can be hurt by the pinecone trap. Squirrels are stunned instead of dying.

When the acorn objective is completed, the story continues.

## Post-Level-1 cutscene

- Squirrels chase Carolina.
- The squirrels jump into squirrel-mobiles.
- Carolina gets into her blue Oka.
- The situation turns into a racing game.

## Level 2

A full NES-style racing sequence inspired by Ferrari Grand Prix Challenge.

## Final cutscene

After Carolina wins:

1. Carolina wakes up in bed in a cold sweat.
2. The camera slowly pulls away from her.
3. The camera moves toward the bedroom window.
4. The narrative text explains the strange relief after a nightmare — realizing that none of it actually happened.
5. The camera flies outside the window.
6. Squirrels are waiting outside, watching.
7. Final text:

   `Ну или почти ничего.....`

The ending should preserve the joke that the nightmare was supposedly unreal, except the squirrels prove otherwise.

---

# 6. VISUAL STYLE OF THE INTRO

The intro should look like a polished anime/visual-novel cutscene rather than a developer prototype.

The target visual reference is the established anime bedroom artwork:

- deep blue/purple night palette;
- warm bedside lamp;
- moonlit window;
- bookshelves;
- plants;
- desk and monitor;
- sleeping Carolina;
- cat on/near the bed;
- ghost paper garland on the wall;
- detailed lived-in bedroom;
- VN dialogue box at the bottom;
- cinematic, cozy, slightly dreamy lighting.

The user explicitly rejected:

- flat blocky SVG rooms;
- generic placeholder rectangles;
- crude character approximations;
- giant mural planes replacing the existing world systems;
- meta "gift website continuation" concepts.

The room artwork itself is the visual foundation. Character sprites should be layered on top of it.

---

# 7. CURRENT INTRO ARTWORK ASSETS

## Closed-door master background

Repository file:

`a_cozy_highly_detailed_anime_style_night_bedroom (3).png`

This is the approved closed-door room artwork.

It contains:

- Carolina sleeping on the left;
- cat;
- bookshelf;
- warm lamp;
- moonlit window;
- plants;
- desk/monitor;
- ghost garland;
- closed door on the right.

It must remain visually unchanged unless the user explicitly requests an artwork change.

## Open-door master background

Repository file:

`f2085a70-3c6b-47ad-aac0-1563a31517a2.png`

This is the matching room with the existing door slightly open and a dark hallway visible.

It was created by editing the approved closed-door master while preserving the rest of the composition.

The two images are intended to crossfade for the door-opening beat.

## Darina source sheet

Repository file:

`IMG_20260917_103543.png`

The source sheet is 718×1023 and contains six Darina poses/variants arranged as a montage.

Visible source states:

- upper-left: doorway peek, shy/curious;
- upper-middle: doorway peek, more open expression;
- upper-right: happy, holding a plush/toy;
- lower-left: thoughtful/sad pose;
- lower-middle: crying/upset pose;
- lower-right: happy/excited pose.

For the current cinematic we only need the relevant four beats:

1. peek;
2. enter holding the toy;
3. sad;
4. happy.

Do not display the entire sheet as one sprite. It must be cropped/regioned into individual poses or converted into separate transparent assets.

---

# 8. CURRENT INTRO IMPLEMENTATION

The intro is implemented in:

- `intro_cutscene.tscn`
- `scripts/intro_cinematic_v2.gd`

The current scene uses:

- closed room background;
- open room background;
- four Darina sprite nodes;
- doorway clipping/mask for the peek pose;
- VN dialogue panel;
- fade transition.

The intended timeline is approximately 17 seconds:

### 0–2.2 sec
Quiet establishing shot with door closed.

### 2.2–2.9 sec
Crossfade from closed-door room to open-door room.

### 3–5 sec
Darina peeks out from the doorway.

### 5–8.8 sec
Darina enters holding the toy.

### 8.8–12.5 sec
Darina changes to sad pose.

### 12.5–17 sec
Darina changes to happy pose.

Dialogue currently follows these visual beats:

1. Darina:
   `Оййй...`
   `А нам, кстати, поделку на завтра задали..........`

2. Darina:
   `А я уже хотела с игрушкой играть...`

3. Carolina:
   `...Ладно. Сделаем эту поделку.`

4. Darina:
   `УРААА! А жёлуди потом найдём?`

Then the scene fades into `game.tscn`.

The user wants the character movement to visibly originate from the doorway. The previous implementation repeatedly failed because the coordinate system and mask were wrong. The current approach uses a dedicated `PeekMask` with `clip_contents=true` and coordinates over the actual doorway region.

---

# 9. IMPORTANT INTRO BUG HISTORY

This is worth remembering because it caused repeated regressions.

Earlier, Darina appeared beside the computer chair rather than from the door. The first fix merely moved her coordinates, but that did not solve the underlying problem.

The actual issue was a coordinate-system/masking mistake.

The later solution introduced a clipped doorway mask. Another bug occurred because `Control.position` was being used incorrectly for a node whose layout was defined with offsets. The final fix updates the mask's offsets rather than replacing its layout position.

Do not revert to the old approach of simply changing `darina_start`/`darina_rest` screen coordinates.

The user also uploaded screenshots showing the failure. Those screenshots are useful as debugging history, not as visual targets.

---

# 10. TITLE → INTRO → GAME FLOW

This flow was explicitly confirmed working on the user's Android phone:

`TITLE SCREEN → INTRO CUTSCENE → LEVEL 1`

It is a protected baseline.

Any future changes must preserve this sequence.

The user previously said, in substance, that the title, cutscene, and game all worked together perfectly. Do not break that chain while making unrelated changes.

---

# 11. LEVEL 1 TECHNICAL BASELINE

The project was rebuilt from the old working concept into Godot 4.7 rather than literally porting the raycaster.

The working architecture is modular.

Important modules include:

- `GameState`
- `GameplayController`
- `PlayerController`
- `EnemyController`
- `PickupController`
- `AudioController`
- `NavigationController`
- `PresentationSync`
- query/math modules
- `LevelData`
- canonical map data
- `game.gd` as coordinator

The separation between gameplay and presentation is intentional.

The player camera is fixed-height / Wolfenstein-like. Do not introduce free vertical look unless explicitly requested.

Reasons for fixed camera:

- closer to Wolfenstein spirit;
- easier mobile controls;
- simpler sprite placement;
- fewer floating-object problems.

---

# 12. MAP ARCHITECTURE — NEXT REFACTOR

The repository previously had a huge `game.tscn` with hundreds of individually authored wall nodes.

The agreed next architecture improvement is:

`LevelData / ASCII map → deterministic level generator → wall/objects/collisions`

Rather than keeping hundreds of hand-authored `StaticBody3D` wall nodes directly in the scene.

Preferred approach for this project:

- use `res://scripts/level_data.gd` or equivalent data structure;
- represent the map as an ASCII/2D array;
- generate the existing wall meshes and collision bodies deterministically;
- preserve the exact existing gameplay layout first;
- only then simplify/edit the map.

Do **not** immediately replace the whole system with GridMap just because GridMap exists. ASCII/array data is currently the clearer fit for this maze-like level.

The refactor must be behavior-preserving:

- same map;
- same wall positions;
- same pickups;
- same enemies;
- same player spawn;
- same gameplay result.

The player should not notice that the internal representation changed.

---

# 13. WALL / FENCE HISTORY

A metal park fence experiment was previously implemented through `scripts/forest_perimeter.gd`.

It caused visual problems and made the walls disappear. The user eventually rejected that experiment.

The fence experiment was removed in commit:

`85748a21d57418c548cf05b7cbf304de616a6acf`

Message:

`Remove abandoned fence experiment`

**Do not reintroduce the fence system unless explicitly requested.**

Existing wall modules should remain normal wall mesh/collision systems. New wall textures, if needed, should be applied to existing wall meshes rather than creating giant new mural planes or a new wall architecture.

---

# 14. OLD BIG-REFACTOR FAILURE

The project has a history of a large modular refactor that broke gameplay and was rolled back.

The important lesson is not that modularity is bad. The lesson is that the refactor was too large and insufficiently tested.

The current V20 architecture was later restored/cleaned up with small, controlled changes.

A remembered cleanup milestone:

- 17 unused preloads removed;
- `game.gd` reduced from roughly 199 lines to 182;
- architecture cleanup build had SHA-256:
  `4c0e8c21637b34bc63e48b48dd1d2ad1efa34fd53f095df5e6f61eb4e517dc9b`

Do not repeat the "Big Step" approach.

Preferred workflow:

`small change → build → test → commit → next small change`

---

# 15. VERSION / ARCHIVE HISTORY

The project went through many iterations:

- V1
- V2
- V3
- V4
- V5
- V6.2
- V7 / THREE ERAS
- later Godot clean/rebuild iterations
- V19 canonical map
- V20 modular baseline
- current post-V20 intro/artwork work

`v6.2` was remembered as the last really reliable old baseline for the FPS implementation.

`acorn_hunter_CAROLINA_v7_THREE_ERAS.zip` was the main conceptual reference for the old multi-era game.

`ACORN_HUNTER_V20_NIGHT_SKY_TWINKLE_V2.zip` was the source archive used to rebuild the GitHub repository into the current V20 baseline.

The principle remains:

> Preserve the essence and working gameplay, but rebuild cleanly rather than blindly porting historical technical debt.

---

# 16. REPOSITORY CLEANUP PLAN

The agreed cleanup has four broad stages.

## Stage 1 — Map into data

Move the hand-authored wall map into `LevelData` / ASCII or array data and generate the existing level deterministically.

## Stage 2 — Smoke checks / CI

The project already has an Android APK build workflow. The next improvement is to add a lightweight project validation/smoke-check stage before the full Android export where practical.

Minimum conceptual checks:

- project opens/headless check passes;
- main scene exists;
- intro scene exists;
- game scene exists;
- no obvious script parse errors;
- Android export succeeds.

## Stage 3 — Repository cleanup

Reduce the repository's collection of historical README files and temporary artifacts.

Preferred structure:

- `README.md` — current project documentation;
- optional `ARCHITECTURE.md` — technical architecture;
- Git history/tags for version history.

Do not keep many historical README files as if they were the version-control system.

## Stage 4 — Balance configuration

Move easy-to-tune gameplay constants into a clean configuration area.

Start simply with constants near the top of the relevant controller scripts:

- squirrel HP;
- squirrel speed;
- player damage;
- pickup behavior;
- other tuning values.

A full `.tres`/`Resource` data model can come later if multiple levels/enemy types make it useful. Do not introduce abstraction merely for abstraction's sake.

---

# 17. GITHUB ACTIONS / ANDROID BUILD

Current workflow:

`.github/workflows/build-v20-apk.yml`

It is named:

`Build V20 APK`

It runs on pushes to `main` and can be manually dispatched.

The workflow:

1. checks out the repository;
2. installs Java 17;
3. installs Android SDK platform/build tools;
4. installs Godot 4.7;
5. installs Godot Android export templates;
6. exports a debug APK;
7. uploads the APK as an Actions artifact.

The expected APK artifact name is:

`AcornHunter-V20-APK`

The export path is:

`build/AcornHunter-V20.apk`

A previous failure happened because the Android preset had an empty export path. This was fixed by setting the export path in `export_presets.cfg`.

Another previous failure involved ETC2/ASTC texture compression requirements. The project now has:

`rendering/textures/vram_compression/import_etc2_astc=true`

in `project.godot`.

A previous workflow implementation using an unavailable third-party action also failed. The current workflow uses explicit Godot/Android setup instead.

Do not claim an APK is ready without checking the current Actions run/artifact.

---

# 18. CURRENT DIRECTION OF THE PROJECT

The immediate creative priority is the intro cinematic.

The immediate technical priority after the intro is the four-stage cleanup/refactor:

1. map → data;
2. smoke checks/CI;
3. repository cleanup;
4. balance configuration.

However, these refactors must not destabilize the current playable baseline.

The user prefers actually doing the work in GitHub rather than receiving a long explanation of what could be done.

When a change is requested and the repository connector allows it, make the change directly, commit it, and report the commit/build status.

---

# 19. USER'S DEVELOPMENT STYLE / EXPECTATIONS

The user wants hands-on collaboration.

Preferred behavior:

- inspect the repository first;
- make concrete changes;
- use Git commits as checkpoints;
- build an APK when relevant;
- test/verify before saying it works;
- avoid asking the user to manually edit many files;
- do not make them repeatedly upload project archives if direct GitHub editing is possible;
- preserve working functionality while improving structure;
- explain failures honestly and fix them rather than hand-waving.

The user often says simply `Делай`. In that context it means: proceed with the implementation, not merely describe a plan.

---

# 20. KNOWN ART / SPRITE PROBLEM TO AVOID

The Darina source sheet contains black background around the characters in the original source image.

A previous attempt used a black-key shader to turn dark pixels transparent. That approach was fragile and also exposed the wrong regions of the sprite sheet, producing bizarre vertical fragments in the game.

The correct approach is:

- crop each source pose to its actual character bounds;
- create proper transparent PNGs when possible;
- use each pose as an independent sprite;
- use a doorway mask only for the peek pose;
- never display the whole source sheet as a sprite.

The user has already seen the failure where the game showed what looked like two vertical legs/door fragments instead of Darina. That is a known regression pattern.

---

# 21. APPROVED CURRENT INTRO COMPOSITION

The bedroom composition should remain approximately:

- sleeping Carolina on left;
- cat on/near bed;
- bookshelf and warm lamp left/center;
- moonlit window center-right;
- desk and monitor on right;
- door on far right;
- Darina emerging from the doorway;
- dialogue box along lower portion of screen.

The approved artwork has a strong blue-purple nighttime palette with warm orange/pink light sources.

The user explicitly liked the full anime bedroom illustration and wants the cutscene to look like the polished reference, not like a technical prototype.

---

# 22. DIALOGUE / WRITING TONE

The dialogue should sound like two real sisters speaking casually, while the game itself treats the acorn hunt as absurdly important.

The opening should not over-explain the joke.

The humor comes from the escalation.

A good tonal progression is:

`обычная домашняя реплика → раздражённое согласие → совершенно серьёзная операция → белки → Ока → гоночная игра → кошмар → белки за окном`

Do not replace this with generic fantasy exposition.

---

# 23. HISTORICAL MUSIC / ASSET CONTEXT

Known music references from older versions:

- Level 1: `Spear of Destiny - Get Them Before They Get You` (user-provided in the earlier project; roughly 76.5 seconds, looped in an older build).
- Level 2: `Race Theme 1.mp3`.

The old game also had a Carolina portrait, HUD, minimap, weapon presentation, and level-specific atmosphere.

Do not remove these baseline elements while refactoring the underlying map architecture.

---

# 24. HISTORICAL GAMEPLAY DETAILS TO PRESERVE

Unless the user explicitly changes them, preserve these Level 1 expectations:

- acorn collection is the objective;
- squirrels are enemies;
- squirrels have 2 HP;
- damage/stun behavior is comedic rather than lethal;
- pinecone is a false pickup/trap;
- the level is nighttime;
- oak trees matter visually/gameplay-wise;
- minimap exists;
- HUD exists;
- mobile controls matter;
- camera height is fixed;
- Wolfenstein spirit is intentional.

---

# 25. WHAT NOT TO DO

Do not:

- reintroduce the abandoned forest fence experiment;
- replace the approved anime room with a blocky SVG room;
- use giant wall planes to fake the entire environment;
- blindly port the old raycaster architecture;
- perform another huge refactor in one commit;
- break title → intro → game;
- expose the entire Darina source sheet in-game;
- assume coordinates are correct without checking the Godot node coordinate system;
- claim an APK exists without verifying the workflow artifact;
- invent missing historical details about the presentation, Carolina's website, or private correspondence;
- publish private Telegram screenshots or private contact information into this public repository.

---

# 26. CURRENT REPOSITORY STATE — IMPORTANT RECENT COMMITS

Selected recent history relevant to continuity:

- `8bf606a07a413937b22aac85bcf9ed8027251ee1` — fixed Android export preset path.
- `87fa2a38aa263a42180bf60c18c47e8ec2226c2d` — enabled ETC2/ASTC texture import compatibility.
- `85748a21d57418c548cf05b7cbf304de616a6acf` — removed abandoned fence experiment.
- `734cdcdd1422a6fdd1eb36c40b1391d33d4b732b` — fixed Darina doorway mask coordinate handling.
- `627c7dbc21f61256e0fbafbbb6dbdef6eee4b637` — most recent cleanup point before the final Darina source/pose work recorded during this chat.

The repository also contains the approved room artwork and current intro scene/script described above.

Always inspect `main` before relying on an older SHA because the branch moves frequently during development.

---

# 27. CURRENT TASK STATUS AT HANDOFF

At the moment of this handoff, the project has:

- working title screen;
- working intro-to-game scene transition;
- approved closed-door bedroom artwork;
- approved open-door bedroom artwork;
- Darina source sheet uploaded to the repository;
- intro scene wired to use the Darina source poses;
- GitHub Actions Android build workflow;
- modular V20 gameplay foundation;
- known plan to refactor the map representation;
- known plan to add/strengthen smoke checks;
- known plan to clean historical README clutter;
- known plan to centralize gameplay balance constants.

The immediate Darina cinematic implementation is still a work-in-progress and should be tested on the user's Android device before considering it visually locked.

---

# 28. THE FOUR-STEP ENGINEERING PLAN

## STEP 1 — MAP DATA REFACTOR

Goal: make the Level 1 map human-readable and deterministic without changing gameplay.

Deliverables:

- `level_data.gd` or equivalent;
- ASCII/array map;
- deterministic wall generation;
- preserved object placements;
- preserved collisions;
- preserved player spawn.

Checkpoint: APK/build + gameplay smoke test.

## STEP 2 — SMOKE TESTS / CI

Goal: catch obvious breakage before a full manual phone test.

Deliverables:

- Godot headless validation/check-only where supported;
- scene existence checks;
- script parse checks;
- Android export remains mandatory.

Checkpoint: clean GitHub Actions run.

## STEP 3 — REPOSITORY CLEANUP

Goal: stop treating README files as version history.

Deliverables:

- one current `README.md`;
- optional architecture document;
- remove obsolete duplicate historical README files where safe;
- remove temporary artifacts.

Checkpoint: project still builds.

## STEP 4 — BALANCE CONFIG

Goal: make tuning values easy to find and change.

Deliverables:

- squirrel HP/speed;
- player damage;
- pickup behavior values;
- other obvious tuning constants;
- no unnecessary Resource abstraction yet.

Checkpoint: project builds and Level 1 behavior is unchanged.

---

# 29. HOW TO CONTINUE IN A NEW CHAT

The next assistant should treat this document as the primary continuity brief for ACORN HUNTER.

First actions in a new chat should be:

1. Read this file.
2. Inspect current `main`.
3. Check current GitHub Actions state if discussing builds.
4. Inspect the exact files involved in the requested change.
5. Preserve the protected title → intro → game flow.
6. Make small commits.
7. Build/check after each meaningful change.

If the user says `продолжаем ACORN HUNTER`, this file should be enough to reconstruct the high-level context without requiring the user to re-explain the project from scratch.

---

# 30. WHAT THIS FILE DOES NOT CLAIM

This document is intentionally comprehensive but not omniscient.

It does **not** claim to contain every exact sentence from the private Telegram correspondence, every screenshot pixel, every historical version of the presentation, or every version of Carolina's website. Those materials may exist in private conversation/library files but are not reproduced here, especially because this repository is public.

Where exact historical source material matters, retrieve it rather than inventing it.

The central creative facts, game lore, technical architecture, current intro design, known failure modes, and next engineering steps above are the continuity baseline.

---

# 31. ONE-SENTENCE PROJECT DEFINITION

> **ACORN HUNTER is a deliberately over-serious, absurd multi-genre adventure born from a personal joke: Darina needs a craft for tomorrow, Carolina needs acorns, squirrels turn the errand into a nightmare, and somehow a blue Oka and a NES racing game become involved.**
