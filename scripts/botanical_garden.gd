extends "res://scripts/level1_woodland.gd"
## One evening garden: patrols, one pump repair, gallery, guardian and escape.
const GardenWorld=preload("res://scripts/botanical_world.gd")
const GardenState=preload("res://scripts/botanical_state.gd")
const GardenHUD=preload("res://scripts/botanical_hud.gd")
const Parts=preload("res://scripts/botanical_service_parts.gd")
const PhysicalSolids=preload("res://scripts/botanical_collision150.gd")
const DEPARTURE=Vector3(0,0,71)
const PART_POSITIONS=[Vector3(28,3,11)]
const PART_NAMES=["ПРЕДОХРАНИТЕЛЬ НАСОСА"]
const PANEL=Vector3(23,3,19)
const GALLERY_APPROACH=Vector3(-28,7,-20)
const GALLERY_ENTRANCE=Vector3(-35,7,-34)
const GALLERY_CENTER=Vector3(-27,7,-33)
const CHECKPOINTS={"entry":Vector3(24,2.5,33),"pump_repair":Vector3(22,3.7,10),"pump_start":Vector3(23,3.7,21),"pump":Vector3(23,3.7,21),"gallery":Vector3(-28,7.7,-22),"guardian_start":Vector3(0,7.7,-18),"guardian":Vector3(0,7.9,-31),"reward":Vector3(0,7.9,-31),"escape":Vector3(0,.7,60)}
var progress=GardenState.new()
var interactables: Array[Dictionary]=[]
var checkpoint_clock:=0.0
var water_flow: Node3D
var is_botanical:=true
var guard_navigation: Node
var encounter_director: Node
var mission_routes: Node3D
var objective_events: Array[String]=[]
var event_log: Array[Dictionary]=[]
var _alert_relay_cooldown:=0.0
func _ready() -> void:
    GameState.current_level=&"level1";progress.load_save()
    if progress.reward:GameState.acorns_collected=6
    world=GardenWorld.new();world.name="BotanicalGarden";world.set_meta("reference_rendering",get_meta("reference_rendering",false));world.set_meta("reference_147",get_meta("reference_147",false));world.set_meta("skip_baked_lighting",get_meta("skip_baked_lighting",false));add_child(world);world.build()
    player=PlayerScene.instantiate();player.name="Player";player.position=progress.position;add_child(player);player.set_physics_process(false)
    player.camera.position.y=.95;player.eye_height=.95;player.camera.fov=65;player.camera.far=260;player.heist=self;player.collision_mask=1|8;player.quiet_enabled=false
    player.configure_garden_collision()
    preload("res://scripts/botanical_compatibility.gd").configure_camera(player.camera)
    player.health.current_health=progress.hp;player.ammo=progress.ammo;player.health.died.connect(_on_player_died)
    hud=GardenHUD.new();hud.name="GardenHUD";add_child(hud);hud.setup(self)
    weapon=preload("res://scripts/botanical_conegun.gd").new();player.camera.add_child(weapon);weapon.position=Vector3(.25,-.30,-.55)
    _make_garden_objects();_make_garden_car()
    water_flow=preload("res://scripts/botanical_waterworks.gd").new();add_child(water_flow);water_flow.setup(world,progress.gate_unlatched or progress.reward)
    mission_routes=preload("res://scripts/botanical_mission_routes.gd").new();add_child(mission_routes);mission_routes.setup(self,progress.installed)
    _apply_garden_state()
    # Register the authored bodies before validating a saved capsule. This is
    # load-only depenetration; normal movement remains entirely physics driven.
    await get_tree().physics_frame;await get_tree().physics_frame
    var old_position=player.position;var old_checkpoint=progress.checkpoint_position
    var capsule=player.get_node("CollisionShape3D").shape as CapsuleShape3D
    var space=get_world_3d().direct_space_state
    var shape_offset: Vector3=player.get_node("CollisionShape3D").position
    player.position=WorldCollision.restore_clear_position(space,player.position,capsule,shape_offset)
    progress.position=player.position
    progress.checkpoint_position=WorldCollision.restore_clear_position(space,progress.checkpoint_position,capsule,shape_offset)
    var repaired_spawn=old_position!=player.position or old_checkpoint!=progress.checkpoint_position
    player.set_physics_process(true)
    guard_navigation=preload("res://scripts/botanical_guard_navigation.gd").new();add_child(guard_navigation);guard_navigation.setup(self)
    preload("res://scripts/botanical_encounters.gd").populate(self)
    for actor in guards:
        for mesh in actor.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
    for i in range(guards.size()):
        guards[i].stealth_patrol=false
        if progress.defeated.has(guards[i].encounter_id):guards[i].restore_defeated()
    if progress.guardian:_restore_guardian()
    stage="reward" if progress.guardian else "garden"
    SignalBus.combat_event.connect(_on_combat_event);SignalBus.show_message.connect(_on_message);PauseManager.pause_state_changed.connect(_on_pause)
    var spatial=preload("res://scripts/woodland_audio.gd").new();add_child(spatial);spatial.water.position=Vector3(20,3.2,23)
    ambient=AudioStreamPlayer.new();var music=load("res://assets/acorn_music.mp3").duplicate();music.loop=true;ambient.stream=music;ambient.volume_db=-25;add_child(ambient);AudioManager.register_music(ambient)
    _apply_garden_state();ready_for_play=true
    if player.desktop_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    hud.notify("Шесть жёлудей уже в рюкзаке. К машине!" if progress.reward else "Дарине нужны шесть жёлудей для поделки. Белки держат зимний запас в оранжерее.",6)
    _objective_event("reward_collected" if progress.reward else "entry_approach")
    if not encounter_done("entry"):_announce(&"encounter_entry","Дозор: «К запасу не подпускать!»",_voice_origin("entry",Vector3(0,1,48)))
    if repaired_spawn or not FileAccess.file_exists(GardenState.PATH):_save()
func ground_height_at(point: Vector3) -> float:return GardenWorld.height_at(point.x,point.z)
func _physics_process(delta: float) -> void:
    if not ready_for_play or mission_failed or mission_complete:return
    seconds+=delta;checkpoint_clock+=delta
    _alert_relay_cooldown=maxf(0,_alert_relay_cooldown-delta)
    if is_instance_valid(encounter_director):encounter_director.update(delta)
    if encounter_done("pump") and not encounter_done("gallery") and gallery_approach_reached():
        _objective_event("gallery_approach")
    if progress.reward and player.position.z>48:_objective_event("car_approach")
    if not progress.gate_unlatched and encounter_done("gallery") and water_flow.gate_open>=.98:
        progress.gate_unlatched=true;_save();hud.notify("Служебный замок снят. Решётка поднята. В оранжерее остался страж.",4)
    if not progress.guardian and tank.defeated:
        progress.guardian=true;stage="reward";_objective_event("guardian_defeated");_apply_garden_state();on_encounter_completed("guardian");hud.notify("Страж повержен. Шесть жёлудей в кладовой — забирай и к машине!\nЗапас пополнен: 38 шишек, здоровье не ниже 80.",5)
    if checkpoint_clock>25:checkpoint_clock=0;_save()
    for supply in supplies:
        if _distance(supply.position)<1.8 and not supply.get_meta("used",false) and (player.get_hp()<95 or player.ammo<24):
            var id=int(supply.get_meta("supply_id",supplies.find(supply)))
            supply.set_meta("used",true);supply.visible=false
            if not progress.used_supplies.has(id):progress.used_supplies.append(id)
            player.health.heal(30);player.ammo=mini(38,player.ammo+18);_save();hud.notify("Запас садовника: +30 здоровья, +18 шишек",3);SignalBus.emit_audio_event(&"pickup",supply.position)
    if is_instance_valid(weapon):weapon.position.y=-.30+sin(seconds*8)*minf(player.velocity.length(),1)*.008;weapon.rotation.x=player.recoil_time*1.5
func _make_garden_objects() -> void:
    _object("journal",Vector3(4,0,59),"Прочитать план насосной","ПЛАН")
    _object("part0",PART_POSITIONS[0],"Забрать предохранитель насоса","ПРЕДОХРАНИТЕЛЬ")
    _object("panel",PANEL,"Вставить предохранитель и запустить насос","НАСОС")
    _object("guardian",Vector3(0,7,-20),"Войти в оранжерею к стражу","ОРАНЖЕРЕЯ")
    _object("reward",Vector3(0,7,-36),"Забрать шесть жёлудей для Дарины","ЗАПАС")
    for pos in [Vector3(10.5,.935,39),Vector3(22,3.035,7),Vector3(-15,7.035,-18),Vector3(3,7.26,-31),Vector3(1.25,3.50,9),Vector3(1.25,1.47,41)]:
        _make_supply(pos)
        var supply=supplies.back();var id=supplies.size()-1;supply.set_meta("supply_id",id)
        PhysicalSolids.visible_prop(supply)
        if progress.used_supplies.has(id):supply.set_meta("used",true);supply.hide()
func _object(id: String,p: Vector3,action: String,title: String) -> void:
    var node=Node3D.new();node.position=p;node.name=id;add_child(node)
    var wood=_mat(Color("786546"))
    if id.begins_with("part"):
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
    var label=Label3D.new();label.text=title;label.font_size=22;label.pixel_size=.0025;label.position.y=2.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=8;label.modulate=Color("d6cdb3");node.add_child(label)
    if id in ["journal","part0","reward"]:PhysicalSolids.visible_prop(node)
    interactables.append({"id":id,"position":p,"action":action,"node":node})
func _make_garden_car() -> void:
    var car=preload("res://scripts/level1_exit.gd").new();add_child(car);car.name="GardenExitCar";car.position=DEPARTURE
    var area=car.get_node("BoardingArea");area.body_entered.disconnect(car._on_body_entered)
    for node in car.find_children("*","Light3D",true,false):node.queue_free()
    for node in car.find_children("*","MeshInstance3D",true,false):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    PhysicalSolids.parked_car(car)
func _apply_garden_state() -> void:
    progress.water=progress.installed
    if is_instance_valid(water_flow):
        water_flow.set_state(progress.water,progress.installed)
        water_flow.set_access((encounter_done("pump") and encounter_done("gallery")) or progress.gate_unlatched or progress.guardian or progress.reward)
    if is_instance_valid(mission_routes):mission_routes.set_powered(progress.installed)
    for object in interactables:
        if object.id=="part0":object.node.visible=not progress.parts[0]
        if object.id=="reward":object.node.visible=not progress.reward

func encounter_done(id: String) -> bool:return progress.encounters_completed.has(id)
func gallery_approach_reached() -> bool:
    return player.position.y>6 and player.position.x< -17 and player.position.z< -8 and player.position.distance_to(GALLERY_APPROACH)<14
func _garden_ready() -> bool:return progress.gate_unlatched or progress.reward or (encounter_done("pump") and encounter_done("gallery") and is_instance_valid(water_flow) and water_flow.gate_open>=.98)
func can_depart() -> bool:return progress.reward and encounter_done("escape") and (not is_instance_valid(encounter_director) or encounter_director.can_depart())

func objective_text() -> String:
    if progress.reward:
        return "ШЕСТЬ ЖЁЛУДЕЙ ДЛЯ ДАРИНЫ\nСадись в машину у входа." if can_depart() else "ПРОРЫВ К МАШИНЕ\nОтбей последний дозор. Служебный мост ведёт прямо к выходу."
    if progress.guardian:return "ШЕСТЬ ЖЁЛУДЕЙ В КЛАДОВОЙ\nЗабери зимний запас для поделки Дарины."
    if stage=="cache":return "СТРАЖ ОРАНЖЕРЕИ\nУйди с линии рывка. Стреляй, пока страж переводит дух."
    if _garden_ready():return "ПУТЬ К ЗАПАСУ ОТКРЫТ\nВойди в оранжерею. Страж ещё охраняет жёлуди."
    if encounter_done("gallery"):return "СЛУЖЕБНЫЙ ЗАМОК СНЯТ\nГидропривод поднимает решётку кладовой."
    if encounter_done("pump"):return "ЗАПАДНАЯ СТЕКЛЯННАЯ ГАЛЕРЕЯ\nЗа центральной лестницей поверни налево. Вход в крыло — с западного торца."
    if progress.installed:return "УДЕРЖАТЬ НАСОСНУЮ\nБелки идут с восточной дорожки. Отбей контратаку."
    if progress.parts[0]:return "ПРЕДОХРАНИТЕЛЬ НАЙДЕН\nВставь его в щит рядом и запусти насос."
    if encounter_done("entry"):return "НАСОСНАЯ У ПРУДА\nУбери охрану и забери предохранитель рядом со щитом."
    return "ПРОБИТЬСЯ В САД\nСними входной дозор. Насосная — по правой лестнице."

func area_progress() -> String:
    return "ДОЗОР %s   НАСОС %s   ГАЛЕРЕЯ %s"%["✓" if encounter_done("entry") else "—","✓" if encounter_done("pump") else "—","✓" if encounter_done("gallery") else "—"]
func trail_hint() -> String:
    if progress.reward:return "К МАШИНЕ · ЦЕНТРАЛЬНАЯ ЛЕСТНИЦА → МОСТ ЧЕРЕЗ ПРУД → ВХОД"
    if progress.guardian or stage=="cache" or encounter_done("gallery"):return "ШЕСТЬ ЖЁЛУДЕЙ ДЛЯ ДАРИНЫ · ЗАПАС В ОРАНЖЕРЕЕ"
    if encounter_done("pump"):return "ЦЕНТРАЛЬНАЯ ЛЕСТНИЦА → ЗАПАДНОЕ КРЫЛО · КЛЮЧ У ДОЗОРА ГАЛЕРЕИ"
    if progress.installed:return "МОСТ ЧЕРЕЗ ПРУД ОТКРЫТ · СНАЧАЛА УДЕРЖИ НАСОСНУЮ"
    return "НАСОСНАЯ СПРАВА ОТ ПРУДА · ПРЕДОХРАНИТЕЛЬ РЯДОМ СО ЩИТОМ"
func journey_map_text() -> String:return "БОТАНИЧЕСКИЙ САД · ПОЗДНИЙ ВЕЧЕР"
func map_footer_text() -> String:
    return "Вход → насосная → западная галерея → страж → 6 жёлудей → машина.\n"+("Мост открыт. Вход в западную галерею — с её западного торца." if progress.installed else "Один предохранитель запускает насос и открывает мост через пруд.")
func goal_position() -> Vector3:
    if progress.reward:return DEPARTURE if can_depart() else Vector3(0,3,23)
    if progress.guardian:return Vector3(0,7,-36)
    if stage=="cache":return tank.position
    if _garden_ready() or encounter_done("gallery"):return Vector3(0,7,-20)
    if encounter_done("pump"):return GALLERY_CENTER if player.position.z< -29 else GALLERY_ENTRANCE
    if progress.installed or progress.parts[0]:return PANEL
    if encounter_done("entry"):return PART_POSITIONS[0]
    return Vector3(0,0,48)
func checkpoint_text() -> String:
    return {"entry_start":"у входа","entry":"после входного дозора","pump_repair":"у щита насосной","pump_start":"перед контратакой у насоса","pump":"после контратаки","gallery":"в очищенной западной галерее","guardian_start":"перед стражем","guardian":"у кладовой","reward":"с шестью жёлудями","escape":"у машины","grove":"в очищенной роще","pavilion":"в очищенном павильоне","legacy_resume":"на сохранённом маршруте"}.get(progress.checkpoint_id,"у последней контрольной точки")
func _distance(point: Vector3) -> float:return player.position.distance_to(point+Vector3.UP*.6)

func context_text() -> String:
    if mission_failed or mission_complete:return ""
    if _distance(DEPARTURE)<4:return "Сесть в машину" if can_depart() else ("Отбей дозор на пути к машине" if progress.reward else "Дарине нужны шесть жёлудей. Запас в оранжерее.")
    for object in interactables:
        if _distance(object.position)>3:continue
        var id: String=object.id
        if id=="part0":
            if progress.parts[0]:continue
            return object.action if encounter_done("entry") and encounter_done("pump_repair") else "Сначала отбей дозор насосной"
        if id=="panel":return "" if progress.installed else (object.action if progress.parts[0] else "Предохранитель лежит рядом, за охраной насосной")
        if id=="guardian":return "" if progress.guardian or stage=="cache" else (object.action if _garden_ready() else "Дозор галереи держит служебный замок")
        if id=="reward":return "" if progress.reward else (object.action if progress.guardian else "Сначала победи стража")
        return object.action
    return ""

func interact() -> void:
    if mission_failed or mission_complete or PauseManager.is_paused:return
    if _distance(DEPARTURE)<4:
        if can_depart():hud.release_controls();player.stop();_save();mission_complete=true;SignalBus.level_completed.emit(&"level1")
        return
    for object in interactables:
        if _distance(object.position)>3:continue
        var id: String=object.id
        if id=="journal":
            progress.journal=true;hud.notify("План: насосная справа от пруда. Один запасной предохранитель лежит рядом со щитом. Насос опускает служебный мост; ключ от кладовой у дозора галереи.",8)
        elif id=="part0":
            if progress.parts[0]:continue
            if not encounter_done("entry") or not encounter_done("pump_repair"):return
            progress.parts[0]=true;_objective_event("fuse_collected");hud.notify("Предохранитель найден. Щит насоса в десяти шагах.",4)
        elif id=="panel":
            if progress.installed or not progress.parts[0]:return
            progress.installed=true;_apply_garden_state();checkpoint("pump_start",CHECKPOINTS.pump_start,true);_objective_event("pump_started")
            hud.notify("Насос запущен. Вода опускает мост через пруд!\nРезерв насосной выдан: 38 шишек, здоровье не ниже 80.",5)
            _announce(&"encounter_pump","Насосная: «Вода пошла! Перекрыть дорожку!»",_voice_origin("pump",Vector3(40,4,5)))
        elif id=="guardian":
            if not _garden_ready() or progress.guardian or stage=="cache":return
            stage="cache";_objective_event("guardian_started");checkpoint("guardian_start",CHECKPOINTS.guardian_start,false)
            hud.notify("Страж защищает зимний запас. Уклоняйся от рывка и стреляй после него.",5)
        elif id=="reward":
            if not progress.guardian or progress.reward:return
            progress.reward=true;GameState.acorns_collected=6;stage="reward";_objective_event("reward_collected");checkpoint("reward",CHECKPOINTS.reward,true)
            hud.notify("Шесть жёлудей для Дарины в рюкзаке. Через мост к машине!\nЗапас пополнен: 38 шишек, здоровье не ниже 80.",5)
            if not encounter_done("escape"):_announce(&"encounter_escape","Тревога: «Жёлуди у неё! К воротам!»",_voice_origin("escape",Vector3(0,4,15)))
        _apply_garden_state();_save();SignalBus.emit_audio_event(&"pickup",object.position);return

func _objective_event(event: String) -> void:
    if objective_events.has(event):return
    objective_events.append(event);event_log.append({"event":event,"time":seconds,"position":player.position})
    if is_instance_valid(encounter_director):encounter_director.on_objective_event(event)
    if event=="gallery_approach":_announce(&"encounter_gallery","Галерея: «Держать западное крыло!»",_voice_origin("gallery",GALLERY_CENTER+Vector3.UP))

func _voice_origin(id: String,fallback: Vector3) -> Vector3:
    return encounter_director.leader_position(id) if is_instance_valid(encounter_director) and encounter_director.has_method("leader_position") else fallback

func _announce(kind: StringName,text: String,where: Vector3) -> void:
    if is_instance_valid(hud):hud.communicate(text,4.5)
    SignalBus.emit_audio_event(kind,where)

func on_encounter_completed(id: String) -> void:
    if encounter_done(id):return
    progress.encounters_completed.append(id)
    var notice=""
    if id=="gallery":notice="Ключ дозора получен. Вернись вдоль крыла к входу в оранжерею."
    elif id=="pump":notice="Насосная удержана. За центральной лестницей налево — к западной галерее."
    elif id=="entry":notice="Входной дозор снят. Справа у пруда — насосная."
    elif id=="pump_repair":notice="Насосная очищена. Предохранитель рядом со щитом."
    elif id=="escape":notice="Путь к машине свободен. Садись — пора домой!"
    _apply_garden_state()
    if id in ["grove","pavilion"]:
        player.health.heal(100);player.ammo=38
        checkpoint(id,player.position,false)
        hud.notify(("Роща" if id=="grove" else "Павильон")+" очищена. Найден резерв: полное здоровье, 38 шишек и контрольная точка.",5)
    elif CHECKPOINTS.has(id):
        checkpoint(id,CHECKPOINTS[id],true)
        if not notice.is_empty():hud.notify(notice+"\nЗапас пополнен: 38 шишек, здоровье не ниже 80. Контрольная точка.",5)
    else:_save()

func checkpoint(id: String,at: Vector3,resupply:=true) -> void:
    # Chapter rewards happen once, in on_encounter_completed. Ordinary saves
    # never improve resources. A retry restores this snapshot and its supplies.
    if resupply:
        player.health.heal(maxi(0,80-player.get_hp()));player.ammo=38
    _capture_runtime();progress.capture_checkpoint(id,at);progress.save()
    event_log.append({"event":"checkpoint_"+id,"time":seconds,"position":at})

func _restore_guardian() -> void:stage="reward";tank.restore_defeated()
func _capture_runtime() -> void:
    progress.position=player.position;progress.hp=maxi(1,player.get_hp());progress.ammo=player.ammo;progress.defeated.clear()
    for guard in guards:
        if guard.defeated:progress.defeated.append(guard.encounter_id)
func _save() -> void:
    if not is_instance_valid(player) or mission_complete or mission_failed:return
    if is_instance_valid(water_flow) and water_flow.gate_open>=.98:progress.gate_unlatched=true
    _capture_runtime();progress.save()
func _on_pause(paused_: bool) -> void:
    super._on_pause(paused_)
    if paused_ and ready_for_play:_save()
func _on_combat_event(kind: StringName,where: Vector2) -> void:
    super._on_combat_event(kind,where)
    if kind in [&"weapon_fired",&"weapon_hit"] and ready_for_play:_save()
func _on_player_died() -> void:
    super._on_player_died()
    hud.notify("Белки удержали проход. Повтор — от последней контрольной точки.",6)
func restart() -> void:
    hud.release_controls();progress.restore_checkpoint();progress.save();PauseManager.resume();SceneFlow.go_to(&"level1")
func guard_alerted(source: Node3D,point: Vector3) -> void:
    if is_instance_valid(encounter_director):encounter_director.alert_group(source,point)
func guard_attack_allowed(source: Node3D) -> bool:
    return encounter_director.attack_allowed(source) if is_instance_valid(encounter_director) else true
