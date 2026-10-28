extends RefCounted
## Stable save IDs: the original three scouts remain 0..2, guardian remains3.
## New pond/pavilion actors are appended, never inserted before the guardian.
const ENCOUNTERS = [
    {"id":0,"role":"flanker","name":"PumpPatrol","at":Vector3(38,3,16),"patrol":[Vector3(38,3,16),Vector3(46,3,5),Vector3(37,3,5),Vector3(33,3,14)]},
    {"id":1,"role":"rifleman","name":"WestServiceGuard","at":Vector3(-42,7,-31),"patrol":[Vector3(-42,7,-31),Vector3(-46,7,-42),Vector3(-33,7,-44),Vector3(-33,7,-26)]},
    {"id":2,"role":"lookout","name":"OrchardLookout","at":Vector3(-45,12,-83),"patrol":[Vector3(-45,12,-83),Vector3(-32,12,-86),Vector3(-24,12,-79),Vector3(-39,12,-77)]},
    {"id":3,"role":"guardian","name":"Tank","at":Vector3(0,7,-27),"patrol":[Vector3(-3,7,-27),Vector3(3,7,-27),Vector3(3,7,-30),Vector3(-3,7,-30)]},
    {"id":4,"role":"skirmisher","name":"PondServicePatrol","at":Vector3(-27,3,8),"patrol":[Vector3(-27,3,8),Vector3(-25,3,17),Vector3(-35,3,18),Vector3(-37,3,7)]},
    {"id":5,"role":"reserve","name":"PavilionReserve","at":Vector3(43,12,-80),"patrol":[Vector3(43,12,-80),Vector3(32,12,-86),Vector3(27,12,-78),Vector3(40,12,-75)]},
]

static func populate(director: Node3D) -> void:
    for spec in ENCOUNTERS:
        director._spawn_guard(spec.at,spec.patrol,spec.id==3,spec.id==3)
        var guard = director.guards.back()
        guard.name=spec.name
        guard.encounter_id=spec.id
        guard.tactical_role=spec.role
    director.tank.visual.scale=Vector3.ONE*.88
