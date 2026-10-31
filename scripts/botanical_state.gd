extends RefCounted
## Version 3 keeps earned campaign facts and separates live saves from retries.
## New key/lever facts are additive: old earned openings remain earned.
const PATH="user://botanical_garden.json"
const ENTRY_SPAWN=preload("res://scripts/botanical_layout.gd").ENTRY_PLAYER_SPAWN
const CHAPTERS=["entry","pump_repair","pump","gallery","guardian","escape"]
var journal:=false
var water:=false
var valves: Array[bool]=[false,false,false]
# Kept for v1/v2 fixtures and migration. Only parts[0] is used by the mission.
var parts: Array[bool]=[false,false,false]
var installed:=false
var gate_unlatched:=false
var service_key:=false
var guardian_started:=false
var seeds: Array[bool]=[false,false,false]
var mirrors: Array[int]=[0,0]
var guide_step:=0
var guardian:=false
var reward:=false
var position:=ENTRY_SPAWN
var hp:=100
var ammo:=38
var defeated: Array[int]=[]
var encounters_completed: Array[String]=[]
var used_supplies: Array[int]=[]
var checkpoint_id:="entry_start"
var checkpoint_position:=ENTRY_SPAWN
var checkpoint_hp:=100
var checkpoint_ammo:=38
var checkpoint_defeated: Array[int]=[]
var checkpoint_supplies: Array[int]=[]
var loaded_version:=3

func load_save() -> void:
    if not FileAccess.file_exists(PATH):return
    var raw=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not raw is Dictionary:return
    var version=raw.get("version",0)
    if not _numeric(version) or float(version) not in [1.0,2.0,3.0]:return
    loaded_version=int(version)
    journal=_flag(raw.get("journal",false));reward=_flag(raw.get("reward",false))
    guardian=reward or _flag(raw.get("guardian",false)) and loaded_version>=2
    _read_flags(raw.get("parts",[]),parts);_read_flags(raw.get("valves",[]),valves)
    installed=_flag(raw.get("installed",false)) and (parts[0] if loaded_version==3 else parts.count(true)==3)
    gate_unlatched=reward or guardian or _flag(raw.get("gate_unlatched",false)) and installed
    # Power is one deliberate repair action now. An old valve pattern cannot
    # take away a repair, an opened latch, a guardian victory or earned acorns.
    installed=installed or gate_unlatched or guardian or reward
    if installed:parts[0]=true
    water=installed
    hp=_resource(raw.get("hp",100),100,1,100);ammo=_resource(raw.get("ammo",38),38,0,38)
    position=_read_position(raw.get("position",[ENTRY_SPAWN.x,ENTRY_SPAWN.y,ENTRY_SPAWN.z]),position)
    _read_ids(raw.get("defeated",[]),defeated,25 if loaded_version==3 else (6 if loaded_version==2 else 4))
    if loaded_version==1:defeated.erase(3)
    if loaded_version==3:
        var completed=raw.get("encounters_completed",[])
        if completed is Array:
            for id in completed:
                if not id is String:continue
                var key=str(id)
                if key in CHAPTERS+ ["grove","pavilion"] and not encounters_completed.has(key):encounters_completed.append(key)
        _read_ids(raw.get("used_supplies",[]),used_supplies,16)
        checkpoint_id=str(raw.get("checkpoint_id","entry_start"))
        checkpoint_position=_read_position(raw.get("checkpoint_position",[position.x,position.y,position.z]),position)
        checkpoint_hp=_resource(raw.get("checkpoint_hp",hp),hp,1,100)
        checkpoint_ammo=_resource(raw.get("checkpoint_ammo",ammo),ammo,0,38)
        _read_ids(raw.get("checkpoint_defeated",defeated),checkpoint_defeated,25)
        _read_ids(raw.get("checkpoint_supplies",used_supplies),checkpoint_supplies,16)
    else:
        # Old progress earns the corresponding new chapter; it never sends a
        # finished player back through newly introduced patrols or objectives.
        if parts.count(true)>0 or installed:_complete_through("pump_repair")
        if installed:_complete_through("pump")
        if gate_unlatched:_complete_through("gallery")
        if guardian:_complete_through("guardian")
        if reward:_complete_through("escape")
        checkpoint_id="legacy_resume"
        checkpoint_position=position;checkpoint_hp=hp;checkpoint_ammo=ammo
        checkpoint_defeated.assign(defeated);checkpoint_supplies.assign(used_supplies)
    if gate_unlatched:_complete_through("gallery")
    if guardian:_complete_through("guardian")
    if reward and loaded_version<3:_complete_through("escape")
    service_key=_flag(raw.get("service_key",false)) or encounters_completed.has("gallery") or gate_unlatched or guardian or reward
    guardian_started=guardian or reward or (_flag(raw.get("guardian_started",false)) and gate_unlatched)
    # Saved actors cannot resume inside the newly physical acorn pedestal.
    # Earned guardian/reward/latch/resources are retained during this load-only
    # position repair; broader prop overlap is checked against real physics.
    if position.y<9.4 and ((not guardian and absf(position.x)<2.8 and position.z< -33.1 and position.z> -39) or (absf(position.x)<1.65 and absf(position.z+36)<1.65)):
        var previous_position=position;position=Vector3(0,7.7,-31.5)
        if checkpoint_position==previous_position or absf(checkpoint_position.x)<1.65 and absf(checkpoint_position.z+36)<1.65 and checkpoint_position.y<9.4:checkpoint_position=position
    # 1.50 had no physical outer doors. An unfinished player may have saved
    # beside the dormant guardian without earning the key/lever opening.
    # Repair only those now-locked interior poses, never valid retry resources.
    if not gate_unlatched:
        if _inside_locked_conservatory(position):position=Vector3(0,7.7,-20)
        if _inside_locked_conservatory(checkpoint_position):checkpoint_position=Vector3(0,7.7,-20)

static func _inside_locked_conservatory(at: Vector3) -> bool:
    # The wall cornice is not the roof: clear old saves above y13 can still
    # fall into the sealed interior. Bound recovery by the authored dome and
    # the separate front canopy, so an above-roof or exterior save stays put.
    if at.z< -22.3 and at.z> -23.913445:
        var depth:=(-22.3-at.z)/1.613445
        var half_width:=lerpf(3.0,4.592201,depth)
        if absf(at.x)<half_width and at.y<13.25:return true
    var radial_squared:=Vector2(at.x,at.z+35).length_squared()
    if radial_squared>=12.2*12.2:return false
    var roof_height:=13.2+7.3*sqrt(maxf(0.0,1.0-radial_squared/(12.2*12.2)))
    return at.y<roof_height

func _complete_through(last: String) -> void:
    for id in CHAPTERS:
        if not encounters_completed.has(id):encounters_completed.append(id)
        if id==last:break

func _read_flags(raw: Variant,target: Array[bool]) -> void:
    if raw is Array and raw.size()==3:
        for i in range(3):target[i]=_flag(raw[i])

func _flag(raw: Variant) -> bool:return raw is bool and raw
func _numeric(raw: Variant) -> bool:return (raw is int or raw is float) and is_finite(float(raw))
func _resource(raw: Variant,fallback: int,minimum: int,maximum: int) -> int:
    return int(clampf(float(raw),minimum,maximum)) if _numeric(raw) else fallback

func _read_ids(raw: Variant,target: Array[int],limit: int) -> void:
    if not raw is Array:return
    for index in raw:
        if not index is int and not index is float:continue
        if not is_finite(float(index)) or float(index)!=floorf(float(index)):continue
        var id=int(index)
        if id>=0 and id<limit and not target.has(id):target.append(id)

func _read_position(raw: Variant,fallback: Vector3) -> Vector3:
    if not raw is Array or raw.size()!=3:return fallback
    for component in raw:
        if not component is int and not component is float:return fallback
    var result=Vector3(float(raw[0]),float(raw[1]),float(raw[2]))
    if not result.is_finite():return fallback
    return Vector3(clampf(result.x,-85,85),clampf(result.y,.6,30),clampf(result.z,-96,97.4))

func capture_checkpoint(id: String,at: Vector3) -> void:
    checkpoint_id=id;checkpoint_position=at
    checkpoint_hp=hp;checkpoint_ammo=ammo
    checkpoint_defeated.assign(defeated);checkpoint_supplies.assign(used_supplies)

func restore_checkpoint() -> void:
    position=checkpoint_position;hp=checkpoint_hp;ammo=checkpoint_ammo
    defeated.assign(checkpoint_defeated);used_supplies.assign(checkpoint_supplies)

func save() -> bool:
    var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify({"version":3,"journal":journal,"water":water,"valves":valves,"parts":parts,"installed":installed,"gate_unlatched":gate_unlatched,"service_key":service_key,"guardian_started":guardian_started,"guardian":guardian,"reward":reward,"position":[position.x,position.y,position.z],"hp":hp,"ammo":ammo,"defeated":defeated,"encounters_completed":encounters_completed,"used_supplies":used_supplies,"checkpoint_id":checkpoint_id,"checkpoint_position":[checkpoint_position.x,checkpoint_position.y,checkpoint_position.z],"checkpoint_hp":checkpoint_hp,"checkpoint_ammo":checkpoint_ammo,"checkpoint_defeated":checkpoint_defeated,"checkpoint_supplies":checkpoint_supplies}));file.close()
    return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK

static func clear() -> void:
    for path in [PATH,PATH+".tmp"]:
        if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
