extends Node3D
## Woodland Run: a new mission independent of the estate grid.
const PlayerScene = preload("res://scenes/level1_player.tscn")
const World = preload("res://scripts/woodland_world.gd")
const Guard = preload("res://scripts/woodland_guard.gd")
const HUD = preload("res://scripts/woodland_hud.gd")
const JourneyState=preload("res://scripts/woodland_journey_state.gd")
const RegionWorld=preload("res://scripts/woodland_region_world.gd")
const RegionMission=preload("res://scripts/woodland_region_mission.gd")
const NEXT_TRAIL=Vector3(26,0,-24)
const PREVIOUS_TRAIL=Vector3(-26,0,23)
const EXIT := Vector3(0,0,25)
const CACHE := Vector3(0,0,-13)
const STATIONS := [
    {"position":Vector3(-22,0,-7),"title":"ПРИСТАНЬ","action":"Позвонить в колокол","done":"Колокол отвлёк дозор от дуба."},
    {"position":Vector3(22,0,0),"title":"ДОМИК ЛЕСНИКА","action":"Забрать ключ от тайника","done":"Ключ найден. Проверь сигналы на других тропах."},
    {"position":Vector3(0,0,-18),"title":"СТАРЫЙ ДУБ","action":"Зажечь сигнальный фонарь","done":"Фонарь зажжён. Тайник виден под корнями дуба."},
]
var journey=JourneyState.new()
var region_index := 0
var regional: RefCounted
var travelling := false
var player: Level1Player
var world: Node3D
var hud: CanvasLayer
var tank: CharacterBody3D
var guards: Array[Node3D] = []
var stations: Array[Node3D] = []
var lit: Array[bool] = [false,false,false]
var stations_lit := 0
var stage := "trail"
var mission_complete := false
var mission_failed := false
var cache_node: Node3D
var supplies: Array[Node3D] = []
var seconds := 0.0
var shots := 0
var weapon: Node3D
var weapon_batches: Dictionary = {}
var ambient: AudioStreamPlayer
var ready_for_play := false

func _ready() -> void:
    GameState.current_level = &"level1"
    journey.load_checkpoint();region_index=journey.region
    if not FileAccess.file_exists(JourneyState.PATH):journey.save_checkpoint()
    world=World.new() if region_index==0 else RegionWorld.new()
    if region_index>0:world.region_index=region_index
    world.name="Woodland"; add_child(world); world.build()
    player=PlayerScene.instantiate(); player.name="Player"; player.position=Vector3(0,.65,21); add_child(player)
    player.camera.position.y=.9; player.camera.far=130; player.heist=self; player.collision_mask=1|8
    player.health.current_health=journey.hp;player.ammo=journey.ammo
    player.health.died.connect(_on_player_died)
    if region_index==0:
        for i in range(STATIONS.size()): _make_station(i)
        _make_cache()
        _spawn_guard(Vector3(-15,0,-3),[Vector3(-17,0,-2),Vector3(-23,0,3)],false)
        _spawn_guard(Vector3(17,0,-5),[Vector3(19,0,-6),Vector3(22,0,7)],false)
        _spawn_guard(Vector3(0,0,-10),[Vector3(0,0,-10)],true)
        _make_car()
    for p in [Vector3(-13,0,8),Vector3(14,0,11),Vector3(10,0,-18)]:_make_supply(p)
    _make_slingshot();_make_trail_marker(NEXT_TRAIL,"КОРОТКАЯ ДОРОГА К МАШИНЕ" if region_index==7 else "СЕВЕРНАЯ ТРОПА →")
    if region_index>0:_make_trail_marker(PREVIOUS_TRAIL,"← ОБРАТНАЯ ТРОПА")
    var spatial_audio := preload("res://scripts/woodland_audio.gd").new(); spatial_audio.name="WoodlandAudio"; add_child(spatial_audio)
    hud=HUD.new(); hud.name="HUD"; add_child(hud); hud.setup(self)
    if region_index>0:
        regional=RegionMission.new();regional.setup(self,region_index,journey.completed.has(region_index))
    elif journey.completed.has(0):
        lit.assign([true,true,true]);stations_lit=3;cache_node.visible=false;stage="travel"
        for station in stations:station.get_node("Light").light_energy=1.3
        for guard in guards:guard.restore_defeated()
    if journey.completed.has(region_index):
        for guard in guards:
            if not guard.defeated:guard.restore_defeated()
    if journey.completed.has(7):GameState.acorns_collected=6
    SignalBus.combat_event.connect(_on_combat_event); SignalBus.show_message.connect(_on_message)
    PauseManager.pause_state_changed.connect(_on_pause)
    ambient=AudioStreamPlayer.new(); ambient.name="WoodlandAmbience"
    var stream := load("res://assets/acorn_music.mp3") as AudioStreamMP3
    if stream:
        stream=stream.duplicate(); stream.loop=true; ambient.stream=stream; ambient.volume_db=-23
        add_child(ambient); AudioManager.register_music(ambient)
    if player.desktop_mode: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    hud.notify("Участок %d / 8: %s. Карта покажет весь путь."%[region_index+1,JourneyState.TITLES[region_index]],5)
    ready_for_play=true

func _exit_tree() -> void:
    if SignalBus.combat_event.is_connected(_on_combat_event): SignalBus.combat_event.disconnect(_on_combat_event)
    if SignalBus.show_message.is_connected(_on_message): SignalBus.show_message.disconnect(_on_message)
    if PauseManager.pause_state_changed.is_connected(_on_pause): PauseManager.pause_state_changed.disconnect(_on_pause)
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    if not ready_for_play or mission_failed or mission_complete: return
    seconds+=delta
    if regional!=null:regional.update(delta)
    if stage=="cache" and tank!=null and tank.defeated:
        stage="reward"; hud.notify("Страж оглушён. Забери жёлуди из тайника под дубом.",4)
    for supply in supplies:
        if not supply.get_meta("used",false) and _distance(supply.position)<1.7 and (player.get_hp()<100 or player.ammo<38):
            supply.set_meta("used",true); supply.visible=false; player.health.heal(30); player.ammo=mini(38,player.ammo+14)
            hud.notify("Запас лесника: +30 здоровья, +14 шишек",2.5); SignalBus.emit_audio_event(&"pickup",supply.position)
    if is_instance_valid(weapon):
        var moving := Vector2(player.velocity.x,player.velocity.z).length()
        weapon.position.y=-.30+sin(seconds*9)*minf(moving,.8)*.009; weapon.rotation.x=-player.recoil_time*1.5

func _unhandled_input(event: InputEvent) -> void:
    if not ready_for_play or PauseManager.is_paused or mission_failed or mission_complete: return
    if event is InputEventMouseMotion and player.desktop_mode and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: player.handle_mouse_motion(event.relative)
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.device!=InputEvent.DEVICE_ID_EMULATION and player.desktop_mode: player.request_fire()
    if event.is_action_pressed("l1_interact"): interact()

func objective_text() -> String:
    if regional!=null:return regional.objective()
    if journey.completed.has(0):return "ШЕСТЬ ЖЁЛУДЕЙ НАЙДЕНЫ\nВернись к машине" if journey.completed.size()==8 else "ЛЕСНИЧЕСТВО ЖДЁТ\nКарта найдена. Продолжай путь по северной тропе."
    match stage:
        "trail": return "ЛЕСНАЯ ТРОПА · %d / 3\nКолокол у воды • ключ в домике • фонарь у дуба" % stations_lit
        "cache": return "СТРАЖ ДУБА\nУклоняйся от рывка. Стреляй, пока он переводит дух."
        "reward": return "ТАЙНИК ОТКРЫТ\nЗабери карту большого лесничества"
        "escape": return "ПОРА ДОМОЙ\nВернись к машине у входа"
    return "ОПЕРАЦИЯ «ЖЁЛУДЬ»"

func context_text() -> String:
    if mission_failed or mission_complete:return ""
    if _distance(NEXT_TRAIL)<3.1:return "Короткой дорогой к машине" if region_index==7 and journey.completed.has(7) else ("Следующий участок: "+JourneyState.TITLES[mini(region_index+1,7)] if journey.completed.has(region_index) else "Сначала заверши задачу участка")
    if region_index>0 and _distance(PREVIOUS_TRAIL)<3.1:return "Вернуться: "+JourneyState.TITLES[region_index-1]
    if regional!=null:return regional.context()
    if journey.completed.has(0):return "Сесть в машину" if journey.completed.size()==8 and _distance(EXIT)<3.7 else ("Сначала пройди лесничество — 8 участков" if _distance(EXIT)<3.7 else "")
    for i in range(stations.size()):
        if _distance(STATIONS[i].position)<3.1:
            if not lit[i]: return STATIONS[i].action
    if _distance(CACHE)<3.1:
        if stage=="reward": return "Забрать карту лесничества"
        if stage=="cache": return "Тайник охраняется"
        if stage=="trail": return "Тайник заперт: найди ключ и два сигнала"
    if _distance(EXIT)<3.7: return "Сесть в машину" if stage=="escape" else "Машина ждёт жёлуди"
    return ""

func interact() -> void:
    if mission_failed or mission_complete or PauseManager.is_paused or travelling:return
    if _distance(NEXT_TRAIL)<3.1:
        if journey.completed.has(region_index):travel_region(0 if region_index==7 else region_index+1)
        else:hud.notify("У каждого участка своя задача. Закончи её перед следующей тропой.",3)
        return
    if region_index>0 and _distance(PREVIOUS_TRAIL)<3.1:travel_region(region_index-1);return
    if regional!=null:regional.interact();return
    if journey.completed.size()==8 and _distance(EXIT)<3.7:
        mission_complete=true;player.stop();hud.release_controls();JourneyState.clear_checkpoint()
        SignalBus.emit_signal(&"level_completed",&"level1");return
    for i in range(stations.size()):
        if _distance(STATIONS[i].position)>=3.1: continue
        if lit[i]: continue
        lit[i]=true; stations_lit+=1
        var light: OmniLight3D=stations[i].get_node("Light"); light.light_energy=1.3
        var flame: MeshInstance3D=stations[i].get_node("Flame")
        var material := flame.material_override.duplicate() as StandardMaterial3D
        material.emission_enabled=true; material.emission=Color("ffc779"); flame.material_override=material
        hud.notify(STATIONS[i].done,4); SignalBus.emit_audio_event(&"woodland_bell" if i==0 else &"pickup",STATIONS[i].position)
        make_noise(STATIONS[i].position,22,3)
        if stations_lit==3:
            stage="cache"; hud.notify("Страж проснулся! Уйди в сторону от рывка и стреляй после него.",6)
        return
    if stage=="reward" and _distance(CACHE)<3.1:
        cache_node.visible=false;complete_region()
        hud.notify("Карта лесничества найдена. Северная тропа ведёт в яблоневый сад.",5)
        SignalBus.emit_audio_event(&"pickup",CACHE);return

func make_noise(origin: Vector3, radius: float, _priority: float=1.0) -> void:
    for guard in guards:
        if not guard.defeated and guard.global_position.distance_to(origin)<=radius: guard.investigate(origin)

func _on_combat_event(kind: StringName, _where: Vector2) -> void:
    if kind==&"weapon_fired": shots+=1; make_noise(player.global_position,18)

func _on_message(text: String, duration: float) -> void:
    if is_instance_valid(hud): hud.notify(text,duration)

func _on_pause(paused_: bool) -> void:
    if not is_instance_valid(player): return
    if paused_: player.fire_requested=false
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if player.desktop_mode and not paused_ and not mission_failed else Input.MOUSE_MODE_VISIBLE

func _on_player_died() -> void:
    mission_failed=true; player.stop(); hud.release_controls(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    hud.notify("Белки удержали тайник. Попробуем другую тропу?",8)

func restart() -> void:
    hud.release_controls(); PauseManager.resume(); SceneFlow.go_to(&"level1")

func _distance(point: Vector3) -> float:
    return Vector2(player.position.x-point.x,player.position.z-point.z).length()

func _spawn_guard(at: Vector3, route: Array, heavy: bool,final_boss:=false) -> void:
    var guard := Guard.new(); guard.name="Tank" if heavy else "Ranger%d" % guards.size()
    guard.position=at; guard.is_tank=heavy; guard.director=self;guard.final_boss=final_boss
    for p: Vector3 in route: guard.patrol_points.append(p)
    add_child(guard); guards.append(guard)
    if heavy: tank=guard

func _mat(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.85; return mat

func _box(parent: Node3D, at: Vector3, size_: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size=size_; node.mesh=mesh
    node.position=at; node.material_override=material; parent.add_child(node); return node

func _make_station(index: int) -> void:
    var station := Node3D.new(); station.name="Station%d" % index; station.position=STATIONS[index].position
    add_child(station); stations.append(station)
    var wood := _mat(Color("876346")); var brass := _mat(Color("9b8556"))
    _box(station,Vector3(0,.75,0),Vector3(.16,1.5,.16),wood)
    _box(station,Vector3(0,1.5,0),Vector3(.65,.08,.5),brass)
    _box(station,Vector3(0,1.8,0),Vector3(.1,.55,.1),brass)
    var flame := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius=.14; sphere.height=.28
    flame.mesh=sphere; flame.material_override=_mat(Color("f2d2a3")); flame.position.y=1.85; flame.name="Flame"; station.add_child(flame)
    var light := OmniLight3D.new(); light.name="Light"; light.position.y=2; light.omni_range=5; light.light_color=Color("ffc48b"); light.light_energy=.15; station.add_child(light)
    var label := Label3D.new(); label.text=STATIONS[index].title; label.font_size=36; label.pixel_size=.005
    label.position.y=2.5; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.visibility_range_end=9
    label.modulate=Color("f0dec0"); station.add_child(label)

func _make_cache() -> void:
    cache_node=Node3D.new(); cache_node.name="OakCache"; cache_node.position=CACHE; add_child(cache_node)
    _box(cache_node,Vector3(0,.3,0),Vector3(1.25,.6,.8),_mat(Color("79553b")))
    _box(cache_node,Vector3(0,.64,0),Vector3(1.3,.1,.85),_mat(Color("ac8b5e")))
    for x: float in [-.45,.45]: _box(cache_node,Vector3(x,.35,.415),Vector3(.055,.5,.025),_mat(Color("a49366")))
    _box(cache_node,Vector3(0,.5,.46),Vector3(.16,.18,.07),_mat(Color("c7a75b")))

func _make_supply(at: Vector3) -> void:
    var supply := Node3D.new(); supply.name="Supply%d" % supplies.size(); supply.position=at; add_child(supply); supplies.append(supply)
    _box(supply,Vector3(0,.25,0),Vector3(.55,.5,.4),_mat(Color("6b7955")))
    _box(supply,Vector3(0,.3,.21),Vector3(.25,.07,.02),_mat(Color("f1d7a4")))
    _box(supply,Vector3(0,.3,.22),Vector3(.07,.25,.02),_mat(Color("f1d7a4")))

func _make_car() -> void:
    var car := preload("res://scripts/level1_exit.gd").new()
    car.name="ExitCar"; add_child(car); car.position=EXIT
    var area := car.get_node("BoardingArea") as Area3D
    area.body_entered.disconnect(car._on_body_entered)
    for node in car.get_children():
        if node is Light3D: node.queue_free()
    # Only the parked car's silhouette casts a shadow. Rendering every wheel,
    # trim and interior surface into the sun map wastes the mobile frame budget.
    for node in car.find_children("*","MeshInstance3D",true,false):
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var shadow := _box(car,Vector3(0,.65,0),Vector3(1.85,1.3,4.3),_mat(Color("33352e")))
    shadow.name="ParkedCarShadow"
    shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _make_slingshot() -> void:
    weapon=Node3D.new(); weapon.name="WoodenSlingshot"; player.camera.add_child(weapon)
    weapon.position=Vector3(.27,-.30,-.55); weapon.rotation_degrees.z=-8
    var wood := _mat(Color("c4ac89"))
    wood.albedo_texture=preload("res://assets/level1/textures/park_oak_bark.jpg")
    wood.uv1_scale=Vector3(.6,.8,1)
    var elastic := _mat(Color("a99878"))
    _weapon_branch(Vector3(0,-.20,0),Vector3(0,.015,0),.027,wood)
    for side: float in [-1,1]:
        var bend := Vector3(side*.045,.075,0)
        var tip := Vector3(side*.095,.16,-.008)
        _weapon_branch(Vector3(0,.005,0),bend,.021,wood)
        _weapon_branch(bend,tip,.017,wood)
        _weapon_branch(tip,Vector3(0,.13,.065),.004,elastic)
    # Static parts share one surface per material instead of seven tiny draws.
    for material: Material in weapon_batches:
        var st: SurfaceTool=weapon_batches[material]
        var mesh_instance := MeshInstance3D.new(); st.index(); mesh_instance.mesh=st.commit()
        mesh_instance.material_override=material
        mesh_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        weapon.add_child(mesh_instance)
    weapon_batches.clear()
    var pouch := _box(weapon,Vector3(0,.13,.065),Vector3(.032,.025,.015),_mat(Color("5d4936")))
    pouch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _weapon_branch(a: Vector3,b: Vector3,radius_: float,material: Material) -> void:
    var mesh := CylinderMesh.new(); mesh.top_radius=radius_*.83; mesh.bottom_radius=radius_
    mesh.height=a.distance_to(b); mesh.radial_segments=10
    if not weapon_batches.has(material):
        var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        weapon_batches[material]=surface
    var st: SurfaceTool=weapon_batches[material]
    st.append_from(mesh,0,Transform3D(Basis(Quaternion(Vector3.UP,a.direction_to(b))),(a+b)*.5))

func complete_region() -> void:
    if not journey.completed.has(region_index):journey.completed.append(region_index)
    journey.region=region_index;journey.hp=maxi(player.get_hp(),60);journey.ammo=maxi(player.ammo,24);journey.save_checkpoint()
    stage="travel"
    hud.notify("Участок пройден: %s. Найдено: %s. Прогресс сохранён."%[JourneyState.TITLES[region_index],JourneyState.REWARDS[region_index]],5)
    if region_index==7:GameState.acorns_collected=6

func travel_region(target: int) -> void:
    if travelling or target<0 or target>=8:return
    if target>region_index and not journey.completed.has(region_index):return
    travelling=true;player.stop();hud.release_controls()
    journey.region=target;journey.hp=maxi(player.get_hp(),60);journey.ammo=maxi(player.ammo,24);journey.save_checkpoint()
    SceneFlow.go_to(&"level1")

func area_progress() -> String:
    if regional!=null:return regional.progress_text()
    return "ЛЕСНИЧЕСТВО %d / 8"%journey.completed.size() if journey.completed.has(0) else "ЗАДАЧИ %d / 3"%stations_lit

func journey_map_text() -> String:
    var text="ЛЕСНИЧЕСТВО — ПЕРВЫЙ УРОВЕНЬ\n\n"
    for i in range(8):
        var mark="✓" if journey.completed.has(i) else ("→" if i==region_index else "○")
        text+="%s  %d. %s\n"%[mark,i+1,JourneyState.TITLES[i]]
    text+="\nСеверная тропа — дальше, южная — назад.\nКороткая дорога из древней рощи ведёт к машине.\nСохранение — у входа и после задачи участка."
    return text

func _make_trail_marker(at: Vector3,text: String) -> void:
    var marker=Node3D.new();marker.name="TrailGate";marker.position=at;add_child(marker)
    var label=Label3D.new();label.text=text;label.position.y=2.3;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size=40;label.pixel_size=.006;label.visibility_range_end=14;marker.add_child(label)
    var ring=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=1.6;mesh.outer_radius=1.7;mesh.rings=24;mesh.ring_segments=4
    ring.mesh=mesh;ring.position.y=.03;ring.material_override=_mat(Color("ba9b63"));ring.visibility_range_end=14;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;marker.add_child(ring)
