extends Node
## Actors are prepositioned; completed groups and individual IDs survive reloads.
const GROUPS={
    "entry":[6,7,8,9],"pump_repair":[0,4,10,11],"pump":[12,13,14,15],
    "gallery":[1,16,17,18],"grove":[2,19],"pavilion":[5,20],"escape":[21,22,23,24],
}
var director: Node3D
var active: Dictionary={}
var completed: Dictionary={}
var _poll:=0.0
var _elapsed:=0.0
var _escape_started_at:=-1.0

func setup(owner_: Node3D) -> void:
    director=owner_
    _make_cover()
    for id: String in director.progress.encounters_completed:
        if not GROUPS.has(id):continue
        completed[id]=true
        for index: int in GROUPS[id]:
            if not director.guards[index].defeated:director.guards[index].restore_defeated()

func trigger(id: String) -> void:
    if not GROUPS.has(id) or active.has(id) or is_complete(id):return
    active[id]=true
    if id=="escape":_escape_started_at=_elapsed
    var leader: Node3D
    for index: int in GROUPS[id]:
        var guard=director.guards[index]
        if guard.defeated:continue
        guard.activate_encounter(director.player.global_position)
        if id=="escape":
            var interception:=Vector3(0,3,8) if index<=22 else Vector3(0,0,45)
            interception.y=director.world.surface_height_at(interception.x,interception.z)+.05
            guard.deploy_to(interception)
        if leader==null:leader=guard
    # Main chapter cues have a matching mission caption and own their voice.
    if leader!=null and id not in ["entry","pump","gallery","escape"]:
        SignalBus.emit_audio_event(&"squirrel_rally",leader.global_position)

func leader_position(id: String) -> Vector3:
    for index: int in GROUPS.get(id,[]):
        if not director.guards[index].defeated:return director.guards[index].global_position
    return director.player.global_position

func is_complete(id: String) -> bool:
    return completed.has(id)

func on_objective_event(event: String) -> void:
    match event:
        "entry_approach":trigger("entry")
        "fuse_collected":pass
        "pump_started":trigger("pump")
        "gallery_approach":
            if is_complete("pump"):trigger("gallery")
        "reward_collected":trigger("escape")
        "guardian_started","guardian_defeated","car_approach":pass

func update(delta: float) -> void:
    _elapsed+=delta
    _poll-=delta
    if _poll>0:return
    _poll=.16
    var player_position: Vector3=director.player.global_position
    # Reconstruct an interrupted battle from earned mission progress.
    if not is_complete("entry"):trigger("entry")
    if is_complete("entry") and player_position.distance_to(Vector3(28,3,11))<36:trigger("pump_repair")
    if director.progress.installed:trigger("pump")
    if is_complete("pump") and director.gallery_approach_reached():trigger("gallery")
    if director.progress.reward:trigger("escape")
    if player_position.distance_to(Vector3(-43,12,-81))<29:trigger("grove")
    if player_position.distance_to(Vector3(41,12,-79))<29:trigger("pavilion")
    for id: String in active.keys():
        var cleared:=true
        for index: int in GROUPS[id]:
            if not director.guards[index].defeated:
                cleared=false;break
        # Seeing/defending a post is independent of earning its mission step.
        # Early contact may clear reserves, but cannot bypass the physical fuse
        # installation, award its checkpoint, or grant the gallery key early.
        if cleared and _completion_unlocked(id):
            completed[id]=true
            active.erase(id)
            director.on_encounter_completed(id)

func _completion_unlocked(id: String) -> bool:
    match id:
        "pump_repair":return is_complete("entry")
        "pump":return bool(director.progress.installed)
        "gallery":return bool(director.progress.installed) and is_complete("pump")
        "escape":return bool(director.progress.reward)
    return true

func on_guard_damaged(guard: Node3D, point: Vector3) -> void:
    if guard.is_tank:return
    trigger(guard.encounter_group)
    alert_group(guard,point)

func alert_group(source: Node3D, point: Vector3) -> void:
    for guard in director.guards:
        if guard==source or guard.is_tank or guard.defeated or not guard.encounter_active:continue
        if guard.encounter_group==source.encounter_group:guard.investigate(point)

func attack_allowed(source: Node3D) -> bool:
    # Up to two ranged tells plus one close attack in the same arena.
    # Distant encounters do not share a global one-enemy attack queue.
    var attacks:=0
    var ranged:=0
    var melee:=0
    for guard in director.guards:
        if guard==source or guard.defeated or not guard.encounter_active:continue
        if guard.global_position.distance_to(source.global_position)>27:continue
        if guard.state in ["aim","fire"]:ranged+=1;attacks+=1
        elif guard.state in ["melee","windup","charge","stomp_windup","shockwave"]:melee+=1;attacks+=1
    if attacks>=3:return false
    if source.is_tank:return melee<1
    var distance: float=Vector2(source.global_position.x-director.player.global_position.x,source.global_position.z-director.player.global_position.z).length()
    return melee<1 if distance<2.2 else ranged<2

func can_depart() -> bool:
    return director.progress.reward and is_complete("escape")

func escape_seconds() -> float:
    return maxf(0,_elapsed-_escape_started_at) if _escape_started_at>=0 else 0.0

func remaining(id: String) -> int:
    var count:=0
    for index: int in GROUPS.get(id,[]):
        if not director.guards[index].defeated:count+=1
    return count

func _make_cover() -> void:
    # Real cover splits firing lanes; stairs and the escape bridge stay open.
    for spec in [
        [Vector3(-5,0,52),Vector3(2.8,1.15,1.1)],
        [Vector3(12,0,43),Vector3(2.4,1.15,1.2)],
        [Vector3(32,3,16),Vector3(1.2,1.25,3.0)],
        [Vector3(37,3,7),Vector3(3.0,1.25,1.2)],
        [Vector3(-28,7,-36.8),Vector3(2.0,1.15,1.0)],
        [Vector3(-20,7,-31.2),Vector3(1.0,1.15,2.2)],
    ]:
        var position_: Vector3=spec[0]
        var size_: Vector3=spec[1]
        position_.y=director.world.surface_height_at(position_.x,position_.z)+size_.y*.5
        var body: StaticBody3D=director.world.solid(position_,size_,"GardenSupplyCover")
        body.set_meta("mission149_dynamic",true)
        body.set_meta("audio_surface",&"wood")
        var mesh:=MeshInstance3D.new()
        var box:=BoxMesh.new();box.size=size_;mesh.mesh=box
        mesh.material_override=director.world.mats.wood
        mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
        body.add_child(mesh)
