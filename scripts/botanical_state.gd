extends RefCounted
const PATH="user://botanical_garden.json"
var journal:=false
var water:=false
var valves: Array[bool]=[false,false,false]
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
    if not raw is Dictionary or raw.get("version")!=1:return
    for key in ["valves","seeds","mirrors"]:
        var values=raw.get(key,[])
        if not values is Array or values.size()!=(2 if key=="mirrors" else 3):return
    journal=bool(raw.get("journal",false));water=bool(raw.get("water",false));guardian=bool(raw.get("guardian",false));reward=bool(raw.get("reward",false))
    for i in range(3):
        seeds[i]=bool(raw.get("seeds",[false,false,false])[i]);valves[i]=bool(raw.get("valves",[false,false,false])[i])
    for i in range(2):mirrors[i]=clampi(int(raw.get("mirrors",[0,0])[i]),0,2)
    guide_step=clampi(int(raw.get("guide_step",0)),0,5);hp=clampi(int(raw.get("hp",100)),60,100);ammo=clampi(int(raw.get("ammo",38)),24,38)
    var xyz=raw.get("position",[0,.7,65])
    if xyz is Array and xyz.size()==3:position=Vector3(clampf(float(xyz[0]),-85,85),clampf(float(xyz[1]),.6,30),clampf(float(xyz[2]),-96,73))
    for index in raw.get("defeated",[]):
        if int(index)>=0 and int(index)<4:defeated.append(int(index))
func save() -> bool:
    var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify({"version":1,"journal":journal,"water":water,"valves":valves,"seeds":seeds,"mirrors":mirrors,"guide_step":guide_step,"guardian":guardian,"reward":reward,"position":[position.x,position.y,position.z],"hp":hp,"ammo":ammo,"defeated":defeated}));file.close()
    return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK
static func clear() -> void:
    for path in [PATH,PATH+".tmp"]:
        if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
