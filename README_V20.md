# ACORN HUNTER — V21

Based directly on V20.

Changes:
- canonical 20x14 map scaled to 1.8 world units per cell for a larger playable space;
- procedural night sky via Godot Environment + Sky + ProceduralSkyMaterial;
- world sprites use QuadMesh materials with billboard mode instead of manual look_at rotation;
- squirrel combat is canon: 2 HP each; first hit wounds, second hit defeats the enemy and swaps to squirrel_stunned.png;
- stunned squirrels stop moving and remain visible as the friendly non-gory defeated state;
- minimap updated for scaled map;
- all previous wall texture assets were removed and replaced by a new six-texture generated wall set based on the supplied ACORN HUNTER wall reference.
