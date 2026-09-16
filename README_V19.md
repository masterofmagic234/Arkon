# ACORN HUNTER — V19 CANONICAL MAP / V11 INPUT

V19 is a conservative fork of the user-confirmed working V11.

The V11 gameplay script and touch UI input architecture are preserved. The canonical 20x14 Level 1 map is authored directly in game.tscn as static wall bodies, so map creation cannot abort _ready() before the V11 input connections are made.

Changes:
- canonical 20x14 map: 107 wall cells;
- static wall visuals and collisions;
- 9 oak trees, 4 acorns, 2 squirrels, 1 fake pine cone;
- ammo 38;
- _is_wall() uses the same canonical map;
- minimap draws the canonical walls.
