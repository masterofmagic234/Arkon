extends RefCounted
const Visual=preload("res://scripts/squirrel_3d_visual.gd")
const Target=preload("res://scripts/woodland_target.gd")
const GUIDE_ROUTE=[Vector3(-15,0,7),Vector3(-16,0,-9),Vector3(0,0,-13),Vector3(16,0,-19)]
const MIRROR_POINTS=[Vector3(-12,2,-2),Vector3(12,2,-2)]
const RUNE_SEQUENCE=[0,1,2,1]
var host: Node3D
var index := 1
var complete := false
var objects: Array[Dictionary]=[]
var guide: Node3D
var guide_step := 0
var guide_clock := 0.0
var valves: Array[bool]=[false,false,false]
var mirror_states: Array[int]=[0,0]
var light_reaches_flower := false
var bell_cooldown := 0.0
var wind_time := 0.0
var gust := false
var rescue_cooldown := 0.0
var alarm := 0.0
var alarm_silenced := false
var reinforcement := false
var crates: Array[bool]=[false,false,false]
var rune_step := 0
var rune_reset_time := 0.0
var boss_started := false
var reward_taken := false

func setup(owner_: Node3D,area: int,already_complete: bool) -> void:
    host=owner_;index=area;complete=already_complete
    host.stage="travel" if complete else "regional"
    match index:
        1:
            guide=Node3D.new();guide.name="FriendlyScout";guide.position=Vector3(-3,0,17);host.add_child(guide)
            var skin=Visual.new();skin.target_height=1.4;guide.add_child(skin);skin.setup();skin.apply_active()
            _object("compass",Vector3(16,0,-19),"Забрать компас разведчика")
        2:
            for i in range(3):_object("valve%d"%i,Vector3(-16+i*16,0,9 if i!=1 else 13),"Повернуть шлюз %d"%(i+1),"valve")
            _object("mill_key",Vector3(0,0,-19),"Забрать мельничный ключ")
            _update_valves()
        3:
            for i in range(2):_object("mirror%d"%i,MIRROR_POINTS[i]-Vector3.UP*2,"Повернуть зеркало %d"%(i+1),"none")
            _object("flower",Vector3(12,0,-17),"Взять солнечную печать","none")
            _trace_light()
        4:_object("rope",Vector3(20,0,-18),"Закрепить верёвку обратного пути")
        5:
            _object("bell",Vector3(-18,0,16),"Отвлечь караул колоколом","bell")
            _object("alarm",Vector3(0,0,-10),"Отключить лагерную тревогу","valve")
            for i in range(3):_object("crate%d"%i,[Vector3(-23,0,-5),Vector3(23,0,-10),Vector3(0,0,-20)][i],"Осмотреть ящик %d"%(i+1),"crate")
            for p in [Vector3(-18,0,2),Vector3(18,0,-9),Vector3(0,0,-16)]:
                host._spawn_guard(p,[p+Vector3(4,0,0),p+Vector3(0,0,7)],false)
                host.guards[-1].stealth_patrol=true;host.guards[-1].hearing_distance=38
        6:
            _object("refill",Vector3(0,0,16),"Взять тренировочные шишки","crate")
            for i in range(3):
                var target=Target.new();target.mission=self;target.symbol=i;target.position=[Vector3(-12,2,-7),Vector3(0,2,-18),Vector3(12,2,-7)][i];host.add_child(target)
        7:
            _object("seal",Vector3(0,0,11),"Приложить собранные лесные печати","valve")
            _object("acorns",Vector3(0,0,-18),"Взять шесть древних жёлудей","crate")
            host._spawn_guard(Vector3(0,0,-9),[Vector3(0,0,-9)],true,true)
            host.tank=host.guards[-1]
    if complete:
        if index==2:
            valves.assign([true,false,true]);host.world.open_bridge();host.world.water_surface.position.y=-.5
        if index==3:mirror_states.assign([1,2]);_trace_light()
        if index==4:host.world.open_ravine_shortcut()
        if index==5:
            crates.assign([true,true,true]);alarm_silenced=true
            for object in objects:
                if str(object.id).begins_with("crate"):object.node.visible=false
        if index==6:rune_step=4
        if index==1:guide.position=GUIDE_ROUTE[-1];guide_step=GUIDE_ROUTE.size()
        if index==7:host.tank.restore_defeated()

func _object(id: String,p: Vector3,label: String,kind:="cache") -> void:
    var node=Node3D.new();node.name=id;node.position=p;host.add_child(node)
    var wood=host._mat(Color("a58257"));var brass=host._mat(Color("b4a16f"))
    if kind=="valve":
        host._box(node,Vector3(0,.7,0),Vector3(.16,1.4,.16),wood)
        var wheel=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=.34;mesh.outer_radius=.42;mesh.rings=20;mesh.ring_segments=5
        wheel.mesh=mesh;wheel.material_override=brass;wheel.position.y=1.4;wheel.rotation.x=PI*.5;node.add_child(wheel)
    elif kind=="bell":
        host._box(node,Vector3(0,1,0),Vector3(.16,2,.16),wood)
        host._box(node,Vector3(0,1.9,0),Vector3(.7,.5,.55),brass)
    elif kind!="none":
        host._box(node,Vector3(0,.3,0),Vector3(1,.6,.7),wood)
        host._box(node,Vector3(0,.63,0),Vector3(1.05,.08,.75),brass)
    objects.append({"id":id,"position":p,"label":label,"node":node})

func update(delta: float) -> void:
    bell_cooldown=maxf(0,bell_cooldown-delta);rescue_cooldown=maxf(0,rescue_cooldown-delta);rune_reset_time=maxf(0,rune_reset_time-delta)
    if index==2:
        if host.world.wheel!=null and _valves_correct():host.world.wheel.rotation.x+=delta*1.1
        if host.world.water_surface!=null:host.world.water_surface.position.y=move_toward(host.world.water_surface.position.y,-.5 if _valves_correct() else -.02,delta*.3)
    if index==4:_ravine_update(delta)
    if complete:return
    match index:
        1:_guide_update(delta)
        5:_camp_update(delta)
        7:
            if boss_started and host.tank.defeated:host.stage="reward"

func _guide_update(delta: float) -> void:
    guide_clock+=delta
    if guide_step>=GUIDE_ROUTE.size():return
    var target: Vector3=GUIDE_ROUTE[guide_step]
    var distance=guide.position.distance_to(target)
    var direction=Vector3.ZERO
    if guide.position.distance_to(host.player.position)<11 and distance>.4:
        direction=guide.position.direction_to(target);guide.position+=direction*minf(distance,delta*1.8)
    if distance<=.5 and guide.position.distance_to(host.player.position)<3.5:
        guide_step+=1;host.hud.notify("След разведчика: %d / 4"%guide_step,2)
    guide.get_child(0).animate_squirrel(guide_clock,0,direction.length()*1.8,direction,delta)

func _ravine_update(delta: float) -> void:
    wind_time+=delta;gust=not complete and fmod(wind_time,7.0)>4.8
    var p: Vector3=host.player.position
    if absf(p.z)>8.8:return
    var distance=1000.0
    for i in range(host.world.RAVINE_ROUTE.size()-1):
        var q=Geometry3D.get_closest_point_to_segment(Vector3(p.x,0,p.z),host.world.RAVINE_ROUTE[i],host.world.RAVINE_ROUTE[i+1])
        distance=minf(distance,q.distance_to(Vector3(p.x,0,p.z)))
    if host.world.shortcut_open:distance=minf(distance,absf(p.x))
    if gust and not host.player.quiet_mode:host.player.position.z+=delta*1.9
    if distance>1.55 and rescue_cooldown<=0:
        rescue_cooldown=2.0;host.player.take_damage(15)
        host.player.position=Vector3(-20,.65,12);host.player.velocity=Vector3.ZERO
        host.hud.notify("Верёвка удержала. На порывах включай тихий шаг.",3)

func _camp_update(delta: float) -> void:
    if alarm_silenced:return
    var noticed=false
    for guard in host.guards:
        if not guard.defeated and guard.state in ["chase","melee"]:noticed=true
    alarm=clampf(alarm+(delta*25 if noticed else -delta*9),0,100)
    if alarm>=100 and not reinforcement:
        reinforcement=true;host._spawn_guard(Vector3(0,0,-22),[Vector3(-10,0,-18),Vector3(10,0,-18)],false)
        host.hud.notify("Тревога! Отключи сирену или спрячься за ящиками.",4)
        SignalBus.emit_audio_event(&"squirrel_warn",Vector3(0,1,-10))

func context() -> String:
    for object in objects:
        if host._distance(object.position)>2.9:continue
        var id: String=object.id
        if complete and id!="refill":continue
        match id:
            "compass":return object.label if guide_step==4 else "Разведчик ещё не дошёл до тайника"
            "mill_key":return object.label if _valves_correct() else "Ключ по ту сторону поднятого моста"
            "flower":return object.label if light_reaches_flower else "Цветку нужен отражённый солнечный луч"
            "acorns":return object.label if host.tank.defeated else "Тайник охраняет древний страж"
            "seal":return "Печати установлены" if boss_started else object.label
            "bell":return "Колокол перезаряжается" if bell_cooldown>0 else object.label
            "alarm":return "Сирена отключена" if alarm_silenced else object.label
        if id.begins_with("crate") and crates[int(id[-1])]:continue
        return object.label
    return ""

func interact() -> void:
    for object in objects:
        if host._distance(object.position)>2.9:continue
        var id: String=object.id
        if complete and id!="refill":continue
        if id.begins_with("valve"):
            var i=int(id[-1]);valves[i]=not valves[i];_update_valves();_sound(object.position);return
        if id.begins_with("mirror"):
            var i=int(id[-1]);mirror_states[i]=(mirror_states[i]+1)%3;_trace_light();_sound(object.position);return
        if id.begins_with("crate"):
            var i=int(id[-1]);crates[i]=true;object.node.visible=false
            _sound(object.position)
            if crates.all(func(value):return value):_finish()
            return
        match id:
            "compass":
                if guide_step==4:object.node.visible=false;_finish()
            "mill_key":
                if _valves_correct():object.node.visible=false;_finish()
            "flower":
                if light_reaches_flower:object.node.visible=false;_finish()
            "rope":_finish()
            "bell":
                if bell_cooldown<=0:
                    bell_cooldown=10;host.make_noise(object.position,60,5);SignalBus.emit_audio_event(&"woodland_bell",object.position)
            "alarm":alarm_silenced=true;alarm=0;_sound(object.position)
            "refill":
                if bell_cooldown<=0:host.player.ammo=38;bell_cooldown=3;_sound(object.position)
            "seal":
                if not boss_started:
                    boss_started=true;host.stage="cache";host.hud.notify("Древний страж: после рывка — удар по земле. Отступай от светящегося круга.",5)
            "acorns":
                if host.tank.defeated:reward_taken=true;object.node.visible=false;_finish()
        return

func _valves_correct() -> bool:return valves==[true,false,true]
func _update_valves() -> void:
    if _valves_correct():host.world.open_bridge()
    elif host.world.bridge_gate==null:
        # Once lowered, the safe bridge remains lowered; nobody can be trapped
        # on the north bank by turning a valve while backtracking.
        pass

func _trace_light() -> void:
    var normals=[
        [Vector3(0,0,1),Vector3(-1,0,-1).normalized(),Vector3(1,0,0)],
        [Vector3(0,0,1),Vector3(1,0,-1).normalized(),Vector3(1,0,1).normalized()]
    ]
    var segments: Array=[]
    var origin=Vector3(-12,2,17);var incoming=Vector3.FORWARD
    var a: Vector3=MIRROR_POINTS[0];segments.append([origin,a])
    var n: Vector3=normals[0][mirror_states[0]]
    var reflected=incoming.bounce(n)
    var b: Vector3=MIRROR_POINTS[1]
    var reaches_second=reflected.dot(a.direction_to(b))>.99
    segments.append([a,b if reaches_second else a+reflected*20])
    light_reaches_flower=false
    if reaches_second:
        incoming=a.direction_to(b);n=normals[1][mirror_states[1]];reflected=incoming.bounce(n)
        var flower=Vector3(12,2,-17)
        light_reaches_flower=reflected.dot(b.direction_to(flower))>.99
        segments.append([b,flower if light_reaches_flower else b+reflected*18])
    for i in range(2):host.world.mirrors[i].rotation.y=atan2(normals[i][mirror_states[i]].x,normals[i][mirror_states[i]].z)
    host.world.set_light_beams(segments)

func target_hit(symbol: int) -> void:
    if complete or index!=6:return
    if symbol==RUNE_SEQUENCE[rune_step]:
        rune_step+=1;SignalBus.emit_audio_event(&"woodland_activate",host.player.position)
        if rune_step==RUNE_SEQUENCE.size():_finish()
        else:host.hud.notify("Верная руна: %d / 4"%rune_step,1.5)
    else:
        rune_step=0;host.hud.notify("Лес просит повторить: лист, луна, жёлудь, луна.",3)

func _finish() -> void:
    if complete:return
    complete=true;host.stage="travel"
    if index==4:host.world.open_ravine_shortcut()
    host.complete_region()
    _sound(host.player.position)

func _sound(p: Vector3) -> void:SignalBus.emit_audio_event(&"woodland_activate",p)

func progress_text() -> String:
    match index:
        1:return "СЛЕДЫ  %d / 4"%guide_step
        2:return "ШЛЮЗЫ  %s · %s · %s"%["ОТКР" if valves[0] else "ЗАКР","ОТКР" if valves[1] else "ЗАКР","ОТКР" if valves[2] else "ЗАКР"]
        3:return "ЛУЧ  "+("ЦВЕТОК ОСВЕЩЁН" if light_reaches_flower else "НАЙДИ ПУТЬ СВЕТА")
        4:return "ВЕТЕР  "+("ПОРЫВ — ТИХИЙ ШАГ" if gust else "МОЖНО ИДТИ")
        5:return "ЯЩИКИ %d / 3  ·  ТРЕВОГА %d%%"%[crates.count(true),roundi(alarm)]
        6:return "РУНЫ  %d / 4"%rune_step
        7:return "ДРЕВНИЙ СТРАЖ" if boss_started else "СОБРАНО СЕМЬ ЛЕСНЫХ ЗНАКОВ"
    return ""

func objective() -> String:
    if complete:return "ЗАДАНИЕ ВЫПОЛНЕНО\n"+("Короткая дорога вернёт тебя к машине" if index==7 else "Продолжай путь. К другим заданиям можно вернуться.")
    match index:
        1:return "СЛЕДОМ ЗА РАЗВЕДЧИКОМ\nДержись рядом с дружелюбной белкой. В конце маршрута забери компас."
        2:return "ЗАПУСТИ СТАРУЮ МЕЛЬНИЦУ\nШлюзы: открыт — закрыт — открыт. Затем переходи мост за ключом."
        3:return "СОЛНЕЧНЫЙ ЦВЕТОК\nНаправь солнечный луч двумя зеркалами к цветку."
        4:return "ПЕРЕПРАВА ЧЕРЕЗ ОВРАГ\nИди по мостам. Во время порывов тихий шаг удерживает равновесие."
        5:return "ПЛАН КАРАУЛА\nНайди три ящика. Укрытия и колокол помогут пройти тихо; сирену можно отключить."
        6:return "ПАМЯТЬ КАМЕННОГО КРУГА\nВыстрели по рунам: лист → луна → жёлудь → луна. Шишки у входа."
        7:return "ШЕСТЬ ДРЕВНИХ ЖЁЛУДЕЙ\n"+("Страж оглушён. Забери жёлуди за ареной." if host.tank!=null and host.tank.defeated else "Установи печати. Уклоняйся от рывка и ударной волны стража.")
    return ""
