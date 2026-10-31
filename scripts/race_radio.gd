extends RefCounted
# One fixed-clock radio channel. Short-lived tactical calls cannot sit in a
# backlog and describe a maneuver which has already finished.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const CLIP_SECONDS := 3.2
const VOICE_SECONDS := 3.0
const MAX_QUEUE := 6
var clock := 0.0
var current: Dictionary={}
var queue: Array[Dictionary]=[]
var remaining := 0.0
var serial := 0
var spoken := 0
var _gap := 0.0
var _intro := false
var _sector := -1
var _warning := 0
var _drops := 0
var _hits := 0
var _next_ambient := 19.0
var _ambient := 0
var _maneuvers := [0,0,0]
var _brakes := [0,0,0]
var _spoken_keys: Dictionary={}

func say(key: String,speaker: String,text: String,voice: int,priority: int=0,ttl: float=12.0,reply_to: String="") -> void:
    if not current.is_empty() and current.key==key: return
    for line in queue:
        if line.key==key: return
    var line := {"key":key,"speaker":speaker,"text":text,"voice":voice,"variant":posmod(spoken+queue.size(),3),"priority":priority,"expires":clock+ttl,"reply_to":reply_to}
    # Air/attack traffic may interrupt idle banter, but never another tactical
    # sentence or the other half of a dispatcher/pilot exchange.
    if priority>=2 and not current.is_empty() and int(current.priority)==0:
        current.clear();remaining=0;_gap=.12
    if queue.size()>=MAX_QUEUE:
        var remove := -1
        for i in range(queue.size()):
            if int(queue[i].priority)<priority: remove=i;break
        if remove<0: return
        queue.remove_at(remove)
    var insertion := queue.size()
    for i in range(queue.size()):
        if int(queue[i].priority)<priority: insertion=i;break
    queue.insert(insertion,line)

func advance(delta: float) -> void:
    clock+=delta
    remaining=maxf(0,remaining-delta)
    if not current.is_empty() and remaining<=0:
        current.clear();_gap=.36
    if not current.is_empty(): return
    _gap=maxf(0,_gap-delta)
    if _gap>0: return
    while not queue.is_empty():
        var line: Dictionary=queue.pop_front()
        if float(line.expires)<clock: continue
        if not String(line.reply_to).is_empty() and not _spoken_keys.has(line.reply_to): continue
        current=line
        remaining=clampf(1.0+String(line.text).length()*.047,3.35,5.2)
        current.duration=remaining
        serial+=1;spoken+=1
        _spoken_keys[line.key]=clock
        for key in _spoken_keys.keys():
            if clock-float(_spoken_keys[key])>40: _spoken_keys.erase(key)
        return

func tick(delta: float,state,player,ais: Array,pursuit,track: PackedFloat32Array) -> void:
    if not state.race_started or state.race_finished: return
    advance(delta)
    var sector := Data.sector_at(player.world_z)
    if not _intro and state.race_time>1.5:
        _intro=true;_sector=sector
        say("stolen","БЕЛКА-2","Она увезла наши жёлуди! Весь зимний запас!",0,1)
        say("dispatch-start","ДУПЛО · ДИСПЕТЧЕР","Всем хвостам: держать машину в поле зрения. Вернём каждый жёлудь.",1,1,14,"stolen")
    if pursuit.warning_serial!=_warning:
        _warning=pursuit.warning_serial
        var take := posmod(_warning-1,3)
        var requests := ["Дупло, она уходит! Нужна поддержка с воздуха!","Орех-1, перекрой ей полосу! Она опять прибавила!","Наземным не удержать! Орех-1, заходи ещё раз!"]
        var replies := ["Орех-1 на связи. Вижу беглянку. Захожу сзади, готовлю шипы.","Вижу её багажник. Там наши жёлуди! Готовлю полосу шипов.","Принял. Выше ёлок, ниже луны. Захожу на повторный сброс."]
        say("air-call-%d"%_warning,"БЕЛКА-1",requests[take],0,2)
        say("air-answer-%d"%_warning,"ОРЕХ-1 · ПИЛОТ",replies[take],2,2,12,"air-call-%d"%_warning)
    if pursuit.drops!=_drops:
        _drops=pursuit.drops
        say("air-drop-%d"%_drops,"ОРЕХ-1 · ПИЛОТ","Шипы на дороге. Наземным: оставил проход, смотрите под колёса!",2,2,7)
    if pursuit.spike_hits!=_hits:
        _hits=pursuit.spike_hits
        say("tire-%d"%_hits,"БЕЛКА-3","Есть! Зацепила шипы! Прижимаем, пока не набрала ход!",0,2,5)
    for i in range(ais.size()):
        var ai=ais[i];var call := "БЕЛКА-%d"%(i+1)
        if ai.maneuver_serial!=_maneuvers[i]:
            _maneuvers[i]=ai.maneuver_serial
            if ai.brake_maneuver(): say("pass-%d-%d"%[i,ai.maneuver_serial],call,"Обойду сбоку. Зайду вперёд и заставлю её тормозить!",0,2,3)
            else: say("ram-%d-%d"%[i,ai.maneuver_serial],call,"Я %s от неё. Иду на таран!"%("справа" if ai.attack_side>0 else "слева"),0,2,1.5)
        if ai.brake_serial!=_brakes[i]:
            _brakes[i]=ai.brake_serial
            say("brake-%d-%d"%[i,ai.brake_serial],call,"Я впереди! Сейчас резко заторможу — пусть догоняет!",0,2,1.3)
    if sector!=_sector and _intro:
        _sector=sector
        var reports := ["Она снова в лесу. Держится основной дороги!","Выехала к полям. Несётся к мосту!","Беглянка на мосту! Не дайте ей уйти!","Прошла мост. Уходит вниз, к тоннелю!","Она в тоннеле! Орех-1, видишь второй выход?","Вышла из тоннеля. Курс на окраину!","Она уже в городе! Дупло, перекройте дорогу!"]
        say("route-%d"%sector,"БЕЛКА-2",reports[sector],0,1,10)
        if sector==4:
            say("tunnel-pilot","ОРЕХ-1 · ПИЛОТ","Под крышей её не вижу. Проверю дорогу за тоннелем.",2,1,13,"route-4")
        elif sector in [2,6]:
            if sector==2: say("block-request","БЕЛКА-3","Запрашиваю перекрытие после моста. Она везёт наши жёлуди!",0,1,14)
            say("block-denied-%d"%sector,"ДУПЛО · ДИСПЕТЧЕР","Перекрытие не готово: на дороге гражданские. Продолжайте погоню.",1,1,18,"block-request" if sector==2 else "route-6")
        else: say("route-reply-%d"%sector,"ДУПЛО · ДИСПЕТЧЕР","Принято. Не теряйте её. Остальные экипажи, держите дистанцию.",1,1,15,"route-%d"%sector)
    if clock>=_next_ambient and current.is_empty() and queue.is_empty():
        _next_ambient=clock+18
        var tangent := atan2(Math.track_center_slope(player.track_phase()+3,track),40)
        var turn := wrapf(tangent-player.heading_yaw,-PI,PI)
        match _ambient%4:
            0: say("banter-turn-%d"%_ambient,"БЕЛКА-1","Впереди %s. Она идёт по главной!"%("левый поворот" if turn<-.025 else ("правый поворот" if turn>.025 else "прямая")),0)
            1: say("banter-acorns-%d"%_ambient,"БЕЛКА-3","Я эти жёлуди всё лето собирал! Только попробуй их съесть!",0)
            2: say("banter-dispatch-%d"%_ambient,"ДУПЛО · ДИСПЕТЧЕР","Хвосты, спокойнее в эфире. Сначала остановите машину.",1)
            3: say("banter-angry-%d"%_ambient,"БЕЛКА-2","Она опять вывернулась! Кто вообще научил её водить?!",0)
        _ambient+=1

func stop() -> void:
    queue.clear();current.clear();remaining=0;_gap=0;_spoken_keys.clear()
