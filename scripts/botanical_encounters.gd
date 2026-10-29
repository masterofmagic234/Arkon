extends RefCounted
## Save identity is the array index. Keep the original 0..5, including guardian3.
## Every reinforcement exists before play; activation never moves or spawns it.
const ENCOUNTERS = [
    {"id":0,"group":"pump_repair","role":"flanker","name":"PumpPatrol","at":Vector3(37,3,16)},
    {"id":1,"group":"gallery","role":"thrower","name":"WestServiceGuard","at":Vector3(-30.2,7,-35.8)},
    {"id":2,"group":"grove","role":"suppressor","name":"OrchardLookout","at":Vector3(-45,12,-83)},
    {"id":3,"group":"guardian","role":"guardian","name":"Tank","at":Vector3(0,7,-27)},
    {"id":4,"group":"pump_repair","role":"thrower","name":"PondServicePatrol","at":Vector3(25,3,10)},
    {"id":5,"group":"pavilion","role":"suppressor","name":"PavilionReserve","at":Vector3(43,12,-80)},
    {"id":6,"group":"entry","role":"assault","name":"EntryRunner","at":Vector3(-3,0,49)},
    {"id":7,"group":"entry","role":"thrower","name":"EntryThrower","at":Vector3(-9,0,46)},
    {"id":8,"group":"entry","role":"flanker","name":"EntryFlanker","at":Vector3(9,0,46)},
    {"id":9,"group":"entry","role":"suppressor","name":"EntryRearGuard","at":Vector3(16,0,48)},
    {"id":10,"group":"pump_repair","role":"assault","name":"PumpRunner","at":Vector3(42,3,11)},
    {"id":11,"group":"pump_repair","role":"suppressor","name":"PumpLookout","at":Vector3(30,3,3)},
    {"id":12,"group":"pump","role":"assault","name":"CounterRunnerEast","at":Vector3(47,3,5)},
    {"id":13,"group":"pump","role":"flanker","name":"CounterFlanker","at":Vector3(44,3,1)},
    {"id":14,"group":"pump","role":"thrower","name":"CounterThrower","at":Vector3(38,3,1)},
    {"id":15,"group":"pump","role":"assault","name":"CounterRunnerWest","at":Vector3(24,3,1)},
    {"id":16,"group":"gallery","role":"assault","name":"GalleryRunner","at":Vector3(-32.0,7,-31.5)},
    {"id":17,"group":"gallery","role":"flanker","name":"GalleryFlanker","at":Vector3(-24,7,-31.2)},
    {"id":18,"group":"gallery","role":"suppressor","name":"GalleryLookout","at":Vector3(-16,7,-36.6)},
    {"id":19,"group":"grove","role":"flanker","name":"OrchardFlanker","at":Vector3(-35,12,-78)},
    {"id":20,"group":"pavilion","role":"assault","name":"PavilionRunner","at":Vector3(34,12,-77)},
    {"id":21,"group":"escape","role":"flanker","name":"EscapeUpperFlanker","at":Vector3(-40,3,11)},
    {"id":22,"group":"escape","role":"thrower","name":"EscapeUpperThrower","at":Vector3(-45,3,11)},
    {"id":23,"group":"escape","role":"suppressor","name":"EscapeStairGuard","at":Vector3(-40,1.05,38)},
    {"id":24,"group":"escape","role":"assault","name":"EscapeLowerRunner","at":Vector3(-45,0,46)},
]

static func populate(director: Node3D) -> void:
    for spec in ENCOUNTERS:
        var at := _floor_point(director,spec.at)
        var route: Array=[]
        for offset: Vector3 in [Vector3.ZERO,Vector3(2.4,0,0),Vector3(0,0,2.4)]:
            var point:=at+offset
            point=_floor_point(director,point)
            route.append(point)
        if spec.id==3:route=[Vector3(-3,7,-27),Vector3(3,7,-27),Vector3(3,7,-30),Vector3(-3,7,-30)]
        for index in range(route.size()):route[index]=_floor_point(director,route[index])
        director._spawn_guard(at,route,spec.id==3,spec.id==3)
        var guard = director.guards.back()
        guard.name=spec.name
        guard.encounter_id=spec.id
        guard.encounter_group=spec.group
        guard.tactical_role=spec.role
        if spec.group=="gallery":
            guard.combat_anchor=Vector3(-27,7,-33)
            guard.combat_radius=18.0
        guard.encounter_active=spec.id==3
        if spec.id!=3:guard.state="waiting"
    director.tank.visual.scale=Vector3.ONE*.88
    director.encounter_director=preload("res://scripts/botanical_encounter_director.gd").new()
    director.encounter_director.name="EncounterDirector"
    director.add_child(director.encounter_director)
    director.encounter_director.setup(director)

static func _floor_point(director: Node3D,point: Vector3) -> Vector3:
    var floor_y: float=director.world.surface_height_at(point.x,point.z)
    # Garden startup registers the physical world before creating actors.
    # Start on the real deck/tread instead of spawning below its visible top.
    # Large props are obstacles, never an excuse to spawn on a pot or boulder.
    if director.world.has_method("physical_support_at"):
        var hit: Dictionary=director.world.physical_support_at(Vector3(point.x,floor_y,point.z),.6,.6)
        if not hit.is_empty() and hit.normal.y>=.61566 and absf(hit.position.y-floor_y)<=.35:floor_y=hit.position.y
    point.y=floor_y+.05
    return point
