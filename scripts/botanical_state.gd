extends RefCounted
const PATH="user://botanical_garden.json"
var journal:=false
var water:=false
var valves: Array[bool]=[false,false,false]
var parts: Array[bool]=[false,false,false]
var installed:=false
var gate_unlatched:=false
# Legacy fields remain readable for existing cinematic/save fixtures only.
# They no longer unlock the garden or offer a peaceful route.
var seeds: Array[bool]=[false,false,false]
var mirrors: Array[int]=[0,0]
var guide_step:=0
var guardian:=false
var reward:=false
var position:=Vector3(0,.7,65)
var hp:=100
var ammo:=38
var defeated: Array[int]=[]
func load_save() -> void:
    if not FileAccess.file_exists(PATH):return
    var raw=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not raw is Dictionary or int(raw.get("version",0)) not in [1,2]:return
    journal=bool(raw.get("journal",false));reward=bool(raw.get("reward",false))
    guardian=bool(raw.get("guardian",false)) and (int(raw.version)==2 or reward)
    if int(raw.version)==2:
        var saved_parts=raw.get("parts",[]);var saved_valves=raw.get("valves",[])
        if saved_parts is Array and saved_parts.size()==3:
            for i in range(3):parts[i]=bool(saved_parts[i])
        if saved_valves is Array and saved_valves.size()==3:
            for i in range(3):valves[i]=bool(saved_valves[i])
        installed=bool(raw.get("installed",false)) and parts.count(true)==3
    gate_unlatched=reward or (int(raw.version)==2 and installed and bool(raw.get("gate_unlatched",false)))
    water=installed and valves==[true,false,true]
    hp=clampi(int(raw.get("hp",100)),60,100);ammo=clampi(int(raw.get("ammo",38)),24,38)
    var xyz=raw.get("position",[0,.7,65])
    if xyz is Array and xyz.size()==3:position=Vector3(clampf(float(xyz[0]),-85,85),clampf(float(xyz[1]),.6,30),clampf(float(xyz[2]),-96,73))
    # Old saves could stand inside the newly added physical store enclosure.
    # Preserve earned acorns with an open latch; unfinished legacy runs leave
    # the unearned locked cage at its nearest safe entrance instead.
    if int(raw.version)==1 and not reward and absf(position.x)<2.8 and position.z< -33.1 and position.z> -39:
        position=Vector3(0,7.65,-31.5)
    for index in raw.get("defeated",[]):
        if int(index)>=0 and int(index)<(6 if int(raw.version)==2 else 4) and (int(raw.version)==2 or int(index)!=3):
            if not defeated.has(int(index)):defeated.append(int(index))
func save() -> bool:
    var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify({"version":2,"journal":journal,"water":water,"valves":valves,"parts":parts,"installed":installed,"gate_unlatched":gate_unlatched,"guardian":guardian,"reward":reward,"position":[position.x,position.y,position.z],"hp":hp,"ammo":ammo,"defeated":defeated}));file.close()
    return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK
static func clear() -> void:
    for path in [PATH,PATH+".tmp"]:
        if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
