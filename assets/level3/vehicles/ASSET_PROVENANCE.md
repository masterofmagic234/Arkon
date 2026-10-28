# Level 3 top-down vehicles · 1.46

The new player vehicle is an original pixel-art adaptation of the game's actual
`240_sx_nfs_pro_street.glb`: mint body, black hood, small red hood emblem and
fastback hatch/spoiler. It replaces the unrelated supplied player-car sprite.
ImageGen produced the two-part source using the actual native top-down/quarter
model renders plus the existing `sprPlayerCar_strip13.png` style reference.
The exact generation prompt and immutable source are retained in `source/`.
No private character photograph is used in this vehicle asset.

`tools/bake_level3_240.gd` extracts the reviewed source body/door, prepares native
107×70 / 33×12 canvases with nearest sampling, a 26-color palette and binary
alpha. Its manifest records source bounds/hashes and the actual hinge/socket.
This is offline asset preparation, with no generation or texture editing during
play. The front points right (+X); the driver side is north (-Y). The door is a
separate sprite whose fixed front hinge rotates outward to 68 degrees.

The van reuses the supplied pure vehicle-only animation
`assets/level3/source/Vehicles/sprVanOpenDoor_strip13.png`. Those thirteen frames
show the north-side sliding door exposing its genuine central doorway. The
existing detached `sprVanDoor.png` is retained as its authored door reference.
The similarly named 66-frame `sprVanDoorsOpen_strip66.png` contains an embedded
old human actor and is deliberately excluded from the vehicle runtime module.
Our armed squirrel actors are separate gameplay entities emerging through the
north-side socket, not that old animation's baked people.

`source/.gdignore` prevents authoring import; the Android preset excludes the
whole `assets/level3/vehicles/source/` directory. The game ships only the baked
240 parts and the existing van art. `tools/level3_vehicle_art_test.gd` checks
native sizes, livery/alpha, the fixed pivot, actual door movement, clean van
frame selection and physically coherent boarding/deployment sockets.
