extends RefCounted

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

# Fallback spawn list mirrors the 12-squirrel experimental Level 1.
const DEFAULT_LAYOUT := [
    [SquirrelTypes.Kind.TANK, "Squirrel01", Vector3(-32.4, 1.25, -0.9)],
    [SquirrelTypes.Kind.SCOUT, "Squirrel02", Vector3(-41.4, 1.25, -8.1)],
    [SquirrelTypes.Kind.SCOUT, "Squirrel03", Vector3(-39.6, 1.25, 8.1)],
    [SquirrelTypes.Kind.THROWER, "Squirrel04", Vector3(-14.4, 1.25, -9.9)],
    [SquirrelTypes.Kind.RUNNER, "Squirrel05", Vector3(-14.4, 1.25, 8.1)],
    [SquirrelTypes.Kind.SCOUT, "Squirrel06", Vector3(-14.4, 1.25, 0.9)],
    [SquirrelTypes.Kind.THIEF, "Squirrel07", Vector3(3.6, 1.25, -6.3)],
    [SquirrelTypes.Kind.SCOUT, "Squirrel08", Vector3(12.6, 1.25, -4.5)],
    [SquirrelTypes.Kind.TANK, "Squirrel09", Vector3(19.8, 1.25, 0.9)],
    [SquirrelTypes.Kind.THROWER, "Squirrel10", Vector3(36.0, 1.25, -9.9)],
    [SquirrelTypes.Kind.RUNNER, "Squirrel11", Vector3(36.0, 1.25, 8.1)],
    [SquirrelTypes.Kind.TANK, "Squirrel12", Vector3(45.0, 1.25, -0.9)],
]

static func build_spawn_list() -> Array:
    var out: Array = []
    for entry in DEFAULT_LAYOUT:
        out.append({
            "id": str(entry[1]),
            "kind": int(entry[0]),
            "position": entry[2],
        })
    return out
