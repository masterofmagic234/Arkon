extends RefCounted
## Explicit staged setup for isolated rules/renderer/AI fixtures.
## Full-route acceptance uses botanical_playthrough and never calls this helper.
const GROUPS={"entry":[6,7,8,9],"pump_repair":[0,4,10,11],"pump":[12,13,14,15],"gallery":[1,16,17,18],"grove":[2,19],"pavilion":[5,20],"escape":[21,22,23,24]}

static func complete(game: Node3D,id: String) -> void:
    game.encounter_director.trigger(id)
    for index in GROUPS[id]:game.guards[index].restore_defeated()
    game.encounter_director.update(1.0)

static func freeze(game: Node3D) -> void:
    game.player.set_physics_process(false)
    for guard in game.guards:guard.set_physics_process(false)
