extends RefCounted

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

# Five archetypes distributed along the new long linear Level 1 progression.
const DEFAULT_LAYOUT := [
    [SquirrelTypes.Kind.SCOUT, "Squirrel01", Vector3(-36.0, 0.95, -0.9)],
    [SquirrelTypes.Kind.TANK, "Squirrel02", Vector3(-27.0, 0.95, -2.7)],
    [SquirrelTypes.Kind.THROWER, "Squirrel03", Vector3(-7.2, 0.95, -0.9)],
    [SquirrelTypes.Kind.THIEF, "Squirrel04", Vector3(16.2, 0.95, -0.9)],
    [SquirrelTypes.Kind.RUNNER, "Squirrel05", Vector3(43.2, 0.95, -0.9)],
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
