extends RefCounted
# Species presentation only. The original weapon poses, orientation, scale,
# animation cadence, hitboxes and combat state remain owned by Level3Enemy.
const ROOT := "res://assets/level3/squirrels/"
const RESTING := ROOT+"resting_strip2.png"
const WALK := {
    &"gunman":ROOT+"walk_gunman_strip8.png",
    &"melee":ROOT+"walk_melee_strip8.png",
    &"butcher":ROOT+"walk_butcher_strip8.png",
}
static func walk_strip(kind: StringName) -> String:
    return WALK.get(kind,WALK[&"gunman"])
