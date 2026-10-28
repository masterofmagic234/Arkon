extends "res://scripts/level1_woodland.gd"
## A single evening garden. Service hardware has a visible mechanical purpose.
const GardenWorld=preload("res://scripts/botanical_world.gd")
const GardenState=preload("res://scripts/botanical_state.gd")
const GardenHUD=preload("res://scripts/botanical_hud.gd")
const Parts=preload("res://scripts/botanical_service_parts.gd")
const DEPARTURE=Vector3(0,0,71)
const PART_POSITIONS=[Vector3(-26,3,10),Vector3(-31,7,-34),Vector3(-44,12,-81)]
const PART_NAMES=["ПРЕДОХРАНИТЕЛЬ НАСОСА","ШЕСТЕРНЯ ПРИВОДА","КЛЮЧ СЛУЖЕБНОГО ЩИТА"]
const PANEL=Vector3(23,3,19)
var progress=GardenState.new()
var interactables: Array[Dictionary]=[]
var checkpoint_clock:=0.0
var water_flow: Node3D
var is_botanical:=true
var guard_navigation: Node
var _alert_relay_cooldown:=0.0
func _ready() -> void:
    GameState.current_level=&"level1";progress.load_save()
    if progress.reward:GameState.acorns_collected=6
    world=GardenWorld.new();world.name="BotanicalGarden";world.set_meta("reference_rendering",get_meta("reference_rendering",false));world.set_meta("skip_baked_lighting",get_meta("skip_baked_lighting",false));add_child(world);world.build()
    player=PlayerScene.instantiate();player.name="Player";player.position=progress.position;add_child(player)
    player.camera.position.y=.95;player.eye_height=.95;player.camera.fov=65;player.camera.far=260;player.heist=self;player.collision_mask=1|8;player.quiet_enabled=false
    preload("res://scripts/botanical_compatibility.gd").configure_camera(player.camera)
    player.health.current_health=progress.hp;player.ammo=progress.ammo;player.health.died.connect(_on_player_died)
    hud=GardenHUD.new();hud.name="GardenHUD";add_child(hud);hud.setup(self)
    weapon=preload("res://scripts/botanical_conegun.gd").new();player.camera.add_child(weapon);weapon.position=Vector3(.25,-.30,-.55)
    _make_garden_objects();_make_garden_car()
    water_flow=preload("res://scripts/botanical_waterworks.gd").new();add_child(water_flow);water_flow.setup(world,progress.water or progress.gate_unlatched or progress.reward)
    guard_navigation=preload("res://scripts/botanical_guard_navigation.gd").new();add_child(guard_navigation);guard_navigation.setup(self)
    preload("res://scripts/botanical_encounters.gd").populate(self)
    for actor in guards:
        for mesh in actor.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
    for i in range(guards.size()):
        guards[i].stealth_patrol=false
        if progress.defeated.has(i):guards[i].restore_defeated()
    if progress.guardian:_restore_guardian()
    stage="reward" if progress.guardian else "garden"
    SignalBus.combat_event.connect(_on_combat_event);SignalBus.show_message.connect(_on_message);PauseManager.pause_state_changed.connect(_on_pause)
    var spatial=preload("res://scripts/woodland_audio.gd").new();add_child(spatial);spatial.water.position=Vector3(20,3.2,23)
    ambient=AudioStreamPlayer.new();var music=load("res://assets/acorn_music.mp3").duplicate();music.loop=true;ambient.stream=music;ambient.volume_db=-25;add_child(ambient);AudioManager.register_music(ambient)
    _apply_garden_state();ready_for_play=true
    if player.desktop_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    hud.notify("Жёлуди уже в рюкзаке. Возвращайся к машине у входа." if progress.reward else ("Решётка кладовой уже открыта. Пройди в оранжерею к стражу." if progress.gate_unlatched else "Дарине нужны шесть жёлудей для поделки. Беличий запас заперт в оранжерее. Найди служебный журнал у входа."),8)
    if not FileAccess.file_exists(GardenState.PATH):_save()
func ground_height_at(point: Vector3) -> float:return GardenWorld.height_at(point.x,point.z)
func _physics_process(delta: float) -> void:
    if not ready_for_play or mission_failed or mission_complete:return
    seconds+=delta;checkpoint_clock+=delta
    _alert_relay_cooldown=maxf(0,_alert_relay_cooldown-delta)
    if not progress.gate_unlatched and progress.installed and water_flow.gate_open>=.98:
        progress.gate_unlatched=true;_save();hud.notify("Решётка поднята и защёлкнута. Пройди в оранжерею к беличьему запасу.",5)
    if not progress.guardian and tank.defeated:
        progress.guardian=true;stage="reward";_apply_garden_state();_save();hud.notify("Страж оглушён. Забери шесть жёлудей из кладовой и возвращайся к машине.",5)
    if checkpoint_clock>25:checkpoint_clock=0;_save()
    for supply in supplies:
        if _distance(supply.position)<1.8 and not supply.get_meta("used",false) and (player.get_hp()<95 or player.ammo<24):
            supply.set_meta("used",true);supply.visible=false;player.health.heal(35);player.ammo=38;hud.notify("Запас садовника: здоровье и шишки восстановлены",3)
    if is_instance_valid(weapon):weapon.position.y=-.30+sin(seconds*8)*minf(player.velocity.length(),1)*.008;weapon.rotation.x=player.recoil_time*1.5
func _make_garden_objects() -> void:
    _object("journal",Vector3(4,0,59),"Прочитать служебный журнал","ЖУРНАЛ НАСОСНОЙ")
    for i in range(3):_object("valve%d"%i,Vector3(28+i*5,3,19),"Повернуть вентиль %d"%(i+1),"ВЕНТИЛЬ %d"%(i+1))
    for i in range(3):_object("part%d"%i,PART_POSITIONS[i],"Забрать: "+PART_NAMES[i].to_lower(),PART_NAMES[i])
    _object("panel",PANEL,"Установить детали и запустить насос","ЩИТ ГИДРОПРИВОДА")
    _object("guardian",Vector3(0,7,-20),"Войти в кладовую","СТРАЖ ЗИМНЕГО ЗАПАСА")
    _object("reward",Vector3(0,7,-36),"Забрать шесть жёлудей для Дарины","БЕЛИЧИЙ ЗАПАС")
    for pos in [Vector3(-12,0,51),Vector3(24,3,7),Vector3(-42,7,-43),Vector3(28,12,-83)]:_make_supply(pos)
func _object(id: String,p: Vector3,action: String,title: String) -> void:
    var node=Node3D.new();node.position=p;node.name=id;add_child(node)
    var wood=_mat(Color("786546"));var brass=_mat(Color("bb9c58"))
    if id.begins_with("valve"):
        _box(node,Vector3(0,.7,0),Vector3(.35,1.4,.35),wood)
        var ring=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=.35;mesh.outer_radius=.43;mesh.rings=20;mesh.ring_segments=5;ring.mesh=mesh;ring.material_override=brass;ring.position.y=1.45;node.add_child(ring)
    elif id.begins_with("part"):
        _box(node,Vector3(0,.35,0),Vector3(.7,.7,.7),wood)
        var part=Parts.build(int(id.trim_prefix("part")));part.position.y=.9;node.add_child(part)
    elif id=="journal":
        _box(node,Vector3(0,.85,0),Vector3(1,.1,.7),wood);_box(node,Vector3(0,.93,0),Vector3(.65,.045,.5),_mat(Color("d8cfad")));_box(node,Vector3(0,.4,0),Vector3(.16,.8,.16),wood)
    elif id=="reward":
        var bodies=SurfaceTool.new();bodies.begin(Mesh.PRIMITIVE_TRIANGLES);var caps=SurfaceTool.new();caps.begin(Mesh.PRIMITIVE_TRIANGLES)
        var shape=SphereMesh.new();shape.radius=.13;shape.height=.30;shape.radial_segments=12;shape.rings=6
        var cap=CylinderMesh.new();cap.top_radius=.11;cap.bottom_radius=.15;cap.height=.09;cap.radial_segments=12
        var stem=CylinderMesh.new();stem.top_radius=.018;stem.bottom_radius=.025;stem.height=.08;stem.radial_segments=6
        for i in range(6):
            var position_=Vector3((i%3-1)*.33,1.89,(floori(i/3.0)-.5)*.36)
            bodies.append_from(shape,0,Transform3D(Basis.IDENTITY,position_));caps.append_from(cap,0,Transform3D(Basis.IDENTITY,position_+Vector3.UP*.11));caps.append_from(stem,0,Transform3D(Basis.IDENTITY,position_+Vector3.UP*.18))
        for pair in [[bodies,Color("aa7c41")],[caps,Color("56432c")]]:
            var st: SurfaceTool=pair[0];st.index();var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=_mat(pair[1]);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(mesh)
    var label=Label3D.new();label.text=title;label.font_size=30;label.pixel_size=.004;label.position.y=2.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=12;label.modulate=Color("f0e4c5");node.add_child(label)
    interactables.append({"id":id,"position":p,"action":action,"node":node})
func _make_garden_car() -> void:
    var car=preload("res://scripts/level1_exit.gd").new();add_child(car);car.name="GardenExitCar";car.position=DEPARTURE
    var area=car.get_node("BoardingArea");area.body_entered.disconnect(car._on_body_entered)
    for node in car.find_children("*","Light3D",true,false):node.queue_free()
    for node in car.find_children("*","MeshInstance3D",true,false):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func _apply_garden_state() -> void:
    progress.water=progress.installed and progress.valves==[true,false,true]
    if is_instance_valid(water_flow):water_flow.set_state(progress.water,progress.installed)
    for object in interactables:
        if object.id.begins_with("part"):object.node.visible=not progress.parts[int(object.id.trim_prefix("part"))]
        if object.id=="reward":object.node.visible=not progress.reward
func _garden_ready() -> bool:return progress.gate_unlatched or progress.reward or (progress.installed and is_instance_valid(water_flow) and water_flow.gate_open>=.98)
func objective_text() -> String:
    if progress.reward:return "ШЕСТЬ ЖЁЛУДЕЙ ДЛЯ ДАРИНЫ\nВернись к машине у входа в сад."
    if progress.guardian:return "ЗИМНИЙ ЗАПАС БЕЗ ОХРАНЫ\nЗабери шесть жёлудей в кладовой оранжереи."
    if stage=="cache":return "СТРАЖ ЗИМНЕГО ЗАПАСА\nУклоняйся от рывка. Стреляй из шишкомёта после его атаки."
    if _garden_ready():return "РЕШЁТКА КЛАДОВОЙ ПОДНЯТА\nПройди к оранжерее. Беличий страж охраняет жёлуди."
    if progress.water:return "ГИДРОПРИВОД ПОДНИМАЕТ РЕШЁТКУ\nВода идёт по каменным лоткам к приводу кладовой."
    if progress.installed:return "ЗАПУСТИТЬ ГИДРОПРИВОД\nОткрой первый и третий вентили. Средний оставь закрытым."
    if progress.parts.count(true)==3:return "ДЕТАЛИ НАЙДЕНЫ\nУстанови предохранитель, шестерню и ключ в щит у вентилей."
    if progress.journal:return "ПОЧИНИТЬ ПРИВОД КЛАДОВОЙ\nНайди предохранитель у пруда, шестерню в западном крыле и ключ в верхней роще."
    return "ЖЁЛУДИ ДЛЯ ПОДЕЛКИ\nВ оранжерее заперт беличий запас. Прочитай журнал насосной у входа."
func area_progress() -> String:return "ДЕТАЛИ %d / 3   ЩИТ %s   ЗАТВОР %s"%[progress.parts.count(true),"✓" if progress.installed else "—","✓" if _garden_ready() else "—"]
func trail_hint() -> String:return "ДАРИНЕ НУЖНЫ ШЕСТЬ ЖЁЛУДЕЙ · СЛУЖЕБНЫЙ ЖУРНАЛ У ВХОДА" if not progress.journal else "ПРУД: ПРЕДОХРАНИТЕЛЬ · ЗАПАДНОЕ КРЫЛО: ШЕСТЕРНЯ · ВЕРХНЯЯ РОЩА: КЛЮЧ"
func journey_map_text() -> String:return "БОТАНИЧЕСКИЙ САД · ПОЗДНИЙ ВЕЧЕР"
func _distance(point: Vector3) -> float:return player.position.distance_to(point+Vector3.UP*.6)
func context_text() -> String:
    if mission_failed or mission_complete:return ""
    if _distance(DEPARTURE)<4:return "Сесть в машину" if progress.reward else "Дарина ждёт шесть жёлудей. Кладовая — в оранжерее."
    for object in interactables:
        if _distance(object.position)>3:continue
        var id: String=object.id
        if id.begins_with("part") and progress.parts[int(id.trim_prefix("part"))]:continue
        if id=="panel":return "Предохранитель, шестерня и ключ установлены" if progress.installed else (object.action if progress.parts.count(true)==3 else "Для ремонта нужны предохранитель, шестерня и ключ")
        if id=="guardian":return "Страж оглушён" if progress.guardian else (object.action if _garden_ready() else "Решётка кладовой закрыта: восстанови насос и гидропривод")
        if id=="reward":return ("Жёлуди уже в рюкзаке" if progress.reward else object.action) if progress.guardian else "Беличий запас охраняет страж"
        if id.begins_with("valve"):
            var i=int(id.trim_prefix("valve"));return ("Закрыть" if progress.valves[i] else "Открыть")+" вентиль %d"%(i+1)
        return object.action
    return ""
func interact() -> void:
    if mission_failed or mission_complete or PauseManager.is_paused:return
    if _distance(DEPARTURE)<4:
        if progress.reward:hud.release_controls();player.stop();_save();mission_complete=true;SignalBus.level_completed.emit(&"level1")
        return
    for object in interactables:
        if _distance(object.position)>3:continue
        var id: String=object.id
        if id=="journal":
            progress.journal=true;hud.notify("Журнал: насос обесточен, редуктор затвора сломан, щит заперт. Предохранитель — у пруда, шестерня — в западном крыле, ключ — в верхней роще. Установи их в щит; вентили: открыт · закрыт · открыт.",14)
        elif id.begins_with("valve"):
            var i=int(id.trim_prefix("valve"));progress.valves[i]=not progress.valves[i];object.node.rotation.y+=PI*.5
            hud.notify("Вода включает гидропривод кладовой!" if progress.installed and progress.valves==[true,false,true] else ("Насос без питания: сначала почини щит" if not progress.installed else "Проверь вентили: открыт · закрыт · открыт"),4)
        elif id.begins_with("part"):
            var i=int(id.trim_prefix("part"))
            if progress.parts[i]:continue
            progress.parts[i]=true;hud.notify(PART_NAMES[i]+" · доставь в щит гидропривода",4)
        elif id=="panel":
            if not progress.installed and progress.parts.count(true)==3:
                progress.installed=true;hud.notify("Предохранитель вставлен, шестерня закреплена, ключ повернут. Насос готов. Вентили: открыт · закрыт · открыт.",8)
        elif id=="guardian" and _garden_ready() and not progress.guardian:stage="cache";hud.notify("Страж защищает зимний запас. Уклоняйся и стреляй после рывка.",5)
        elif id=="reward" and progress.guardian:
            progress.reward=true;GameState.acorns_collected=6;hud.notify("Шесть жёлудей для Дарины в рюкзаке. Скорее к машине!",5)
        _apply_garden_state();_save();SignalBus.emit_audio_event(&"pickup",object.position);return
func _restore_guardian() -> void:
    stage="reward";tank.restore_defeated()
func _save() -> void:
    if not is_instance_valid(player) or mission_complete:return
    if is_instance_valid(water_flow) and water_flow.gate_open>=.98:progress.gate_unlatched=true
    progress.position=player.position;progress.hp=maxi(60,player.get_hp());progress.ammo=maxi(24,player.ammo);progress.defeated.clear()
    for i in range(guards.size()):
        if guards[i].defeated:progress.defeated.append(i)
    progress.save()
func _on_pause(paused_: bool) -> void:
    super._on_pause(paused_)
    if paused_ and ready_for_play:_save()
func _on_combat_event(kind: StringName,where: Vector2) -> void:
    super._on_combat_event(kind,where)
    if kind==&"weapon_hit":_save()
func restart() -> void:
    hud.release_controls();progress.hp=100;progress.ammo=38;progress.position=Vector3(0,.7,65);progress.save();PauseManager.resume();SceneFlow.go_to(&"level1")

func guard_alerted(source: Node3D, point: Vector3) -> void:
    if _alert_relay_cooldown>0:return
    _alert_relay_cooldown=1.0
    for guard in guards:
        if guard==source or guard.is_tank or guard.defeated:continue
        if guard.global_position.distance_to(source.global_position)<14 and absf(guard.global_position.y-source.global_position.y)<2:
            guard.investigate(point)

func guard_attack_allowed(source: Node3D) -> bool:
    # One readable nearby tell at a time; independent physical projectiles
    # remain dodgeable and do not bypass the player's real damage cooldown.
    for guard in guards:
        if guard==source or guard.defeated:continue
        if guard.state in ["aim","fire","melee","windup","charge","stomp_windup","shockwave"] and guard.global_position.distance_to(player.global_position)<14:
            return false
    return true
