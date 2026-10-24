extends RefCounted
## Checkpoints contain only progress and resources, never runtime nodes.
const PATH := "user://woodland_journey.json"
const COUNT := 8
const TITLES := ["ЛЕСНОЙ ДОЗОР","ЯБЛОНЕВЫЙ САД","МЕЛЬНИЧНЫЙ ПРУД","СТЕКЛЯННЫЙ САД","МШИСТЫЙ ОВРАГ","ЛАГЕРЬ СБОРЩИКОВ","КАМЕННЫЙ КРУГ","ДРЕВНЯЯ РОЩА"]
const REWARDS := ["Карта лесничества","Компас разведчика","Мельничный ключ","Солнечная печать","Верёвка проводника","План караула","Лесная руна","Шесть древних жёлудей"]
var region := 0
var completed: Array[int] = []
var hp := 100
var ammo := 38

func load_checkpoint() -> void:
    if not FileAccess.file_exists(PATH): return
    var raw = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not raw is Dictionary or int(raw.get("version",0))!=1: return
    var values=raw.get("completed",[])
    if not values is Array: return
    completed.clear()
    for value in values:
        if int(value)>=0 and int(value)<COUNT and not completed.has(int(value)): completed.append(int(value))
    region=clampi(int(raw.get("region",0)),0,COUNT-1)
    # A corrupted checkpoint can never unlock a region ahead of the frontier.
    region=mini(region,frontier())
    hp=clampi(int(raw.get("hp",100)),40,100)
    ammo=clampi(int(raw.get("ammo",38)),18,38)

func frontier() -> int:
    for i in range(COUNT):
        if not completed.has(i): return i
    return COUNT-1

func save_checkpoint() -> bool:
    var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify({"version":1,"region":region,"completed":completed,"hp":hp,"ammo":ammo}))
    file.close()
    return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK

static func clear_checkpoint() -> void:
    if FileAccess.file_exists(PATH):DirAccess.remove_absolute(PATH)
    if FileAccess.file_exists(PATH+".tmp"):DirAccess.remove_absolute(PATH+".tmp")
