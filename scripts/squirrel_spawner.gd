extends RefCounted

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

# Five archetypes placed on the existing 20x14 canonical map.
# Coordinates are chosen on walkable cells; the map itself is unchanged.
const DEFAULT_LAYOUT := [
    [SquirrelTypes.Kind.SCOUT, "Squirrel01", Vector3(-1.44, 0.95, -3.24)],
    [SquirrelTypes.Kind.TANK, "Squirrel02", Vector3(11.34, 0.95, -0.54)],
    [SquirrelTypes.Kind.THROWER, "Squirrel03", Vector3(-4.50, 0.95, 4.50)],
    [SquirrelTypes.Kind.THIEF, "Squirrel04", Vector3(6.30, 0.95, 8.10)],
    [SquirrelTypes.Kind.RUNNER, "Squirrel05", Vector3(-6.30, 0.95, 6.30)],
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
