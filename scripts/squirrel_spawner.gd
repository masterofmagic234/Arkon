extends RefCounted

const SquirrelTypes = preload("res://scripts/squirrel_types.gd")

# Current #149 scene has two existing squirrels; do not alter the map by spawning extra nodes.
const DEFAULT_LAYOUT := [
    [SquirrelTypes.Kind.SCOUT, "Squirrel01"],
    [SquirrelTypes.Kind.SCOUT, "Squirrel02"],
]

static func build_spawn_list() -> Array:
    var out: Array = []
    for entry in DEFAULT_LAYOUT:
        out.append({"id": str(entry[1]), "kind": int(entry[0])})
    return out
