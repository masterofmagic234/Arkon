extends RefCounted
## Checkpoints contain only progress and resources, never runtime nodes.
const PATH := "user://woodland_journey.json"
const COUNT := 8
const TITLES := ["ЛЕСНОЙ ДОЗОР","ЯБЛОНЕВЫЙ САД","МЕЛЬНИЧНЫЙ ПРУД","СТЕКЛЯННЫЙ САД","МШИСТЫЙ ОВРАГ","ЛАГЕРЬ СБОРЩИКОВ","КАМЕННЫЙ КРУГ","ДРЕВНЯЯ РОЩА"]
const REWARDS := ["Карта лесничества","Компас разведчика","Мельничный ключ","Солнечная печать","Верёвка проводника","План караула","Лесная руна","Шесть древних жёлудей"]
var region := 0
var completed: Array[int] = []
var visited: Array[int] = [0]
var entry := "start"
var hp := 100
var ammo := 38

func load_checkpoint() -> void:
    if not FileAccess.file_exists(PATH): return
    var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not raw is Dictionary or int(raw.get("version",0)) not in [1,2]: return
    var values=raw.get("completed",[])
    if not values is Array: return
    completed.clear()
    for value in values:
        if int(value)>=0 and int(value)<COUNT and not completed.has(int(value)): completed.append(int(value))
    region=clampi(int(raw.get("region",0)),0,COUNT-1)
    visited.clear()
    var explored=raw.get("visited",[0,region])
    if not explored is Array:explored=[0,region]
    for value in explored:
        if int(value)>=0 and int(value)<COUNT and not visited.has(int(value)):visited.append(int(value))
    if not visited.has(region):visited.append(region)
    entry=str(raw.get("entry","start"))
    if entry not in ["start","south","north"]:entry="start"
    hp=clampi(int(raw.get("hp",100)),40,100)
    ammo=clampi(int(raw.get("ammo",38)),18,38)

func save_checkpoint() -> bool:
    var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify({"version":2,"region":region,"completed":completed,"visited":visited,"entry":entry,"hp":hp,"ammo":ammo}))
    file.close()
    return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK

static func clear_checkpoint() -> void:
    if FileAccess.file_exists(PATH):DirAccess.remove_absolute(PATH)
    if FileAccess.file_exists(PATH+".tmp"):DirAccess.remove_absolute(PATH+".tmp")
