extends "res://scripts/level1_woodland.gd"
## New geography and quest director. The entire garden stays in ONE scene.
const GardenWorld=preload("res://scripts/botanical_world.gd")
const GardenState=preload("res://scripts/botanical_state.gd")
const GardenHUD=preload("res://scripts/botanical_hud.gd")
const DEPARTURE=Vector3(0,0,71)
const SEED_POSITIONS=[Vector3(-26,3,10),Vector3(-31,7,-34),Vector3(-44,12,-81)]
const GUIDE_ROUTE=[Vector3(0,0,47),Vector3(-24,1.5,35),Vector3(-25,3,8),Vector3(0,3.6,8),Vector3(0,7,-18)]
const MIRRORS=[Vector3(-9,9,-18),Vector3(9,9,-31)]
const RECEIVER=Vector3(0,9,-36)
var progress=GardenState.new()
var interactables: Array[Dictionary]=[]
var guide: Node3D
var mirror_nodes: Array[Node3D]=[]
var beams: Array[Node3D]=[]
var light_solved:=false
var guide_clock:=0.0
var checkpoint_clock:=0.0
var bloom: Node3D
var water_flow: Node3D
var is_botanical:=true

func _ready() -> void:
    GameState.current_level=&"level1";progress.load_save()
    world=GardenWorld.new();world.name="BotanicalGarden";world.set_meta("reference_rendering",get_meta("reference_rendering",false));world.set_meta("skip_baked_lighting",get_meta("skip_baked_lighting",false));add_child(world);world.build()
    player=PlayerScene.instantiate();player.name="Player";player.position=progress.position;add_child(player)
    player.camera.position.y=.95;player.eye_height=.95;player.camera.fov=65;player.camera.far=260;player.heist=self;player.collision_mask=1|8
    preload("res://scripts/botanical_compatibility.gd").configure_camera(player.camera)
    player.health.current_health=progress.hp;player.ammo=progress.ammo;player.health.died.connect(_on_player_died)
    hud=GardenHUD.new();hud.name="GardenHUD";add_child(hud);hud.setup(self)
    _make_slingshot();_make_garden_objects();_make_garden_car();_make_guide();_make_optics();_make_water()
    _spawn_guard(Vector3(38,3,15),[Vector3(38,3,15),Vector3(46,3,3)],false)
    _spawn_guard(Vector3(-40,7,-25),[Vector3(-40,7,-25),Vector3(-45,7,-44)],false)
    _spawn_guard(Vector3(27,7,-49),[Vector3(27,7,-49),Vector3(34,7,-56)],false)
    _spawn_guard(Vector3(0,7,-27),[Vector3(0,7,-27)],true,true);tank.visual.scale=Vector3.ONE*.88
    # Characters move through the baked probe volume and retain realtime sun.
    # Scope this to the garden so the later levels keep their own lighting.
    for actor in [guide]+guards:
        for mesh in actor.find_children("*","MeshInstance3D",true,false):mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
    for i in range(guards.size()):
        guards[i].stealth_patrol=true
        if progress.defeated.has(i):guards[i].restore_defeated()
    if progress.guardian:_pacify_guardian(false)
    stage="reward" if progress.guardian else "garden"
    SignalBus.combat_event.connect(_on_combat_event);SignalBus.show_message.connect(_on_message);PauseManager.pause_state_changed.connect(_on_pause)
    var spatial=preload("res://scripts/woodland_audio.gd").new();add_child(spatial);spatial.water.position=Vector3(0,3.2,23)
    ambient=AudioStreamPlayer.new();var music=load("res://assets/acorn_music.mp3").duplicate();music.loop=true;ambient.stream=music;ambient.volume_db=-25;add_child(ambient);AudioManager.register_music(ambient)
    _update_optics();_apply_garden_state();ready_for_play=true
    if player.desktop_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    hud.notify("Забытый ботанический сад. Все террасы соединены — начни исследование с дневника у входа.",6)
    if not FileAccess.file_exists(GardenState.PATH):_save()

func ground_height_at(point: Vector3) -> float:return GardenWorld.height_at(point.x,point.z)
func _physics_process(delta: float) -> void:
    if not ready_for_play or mission_failed or mission_complete:return
    seconds+=delta;guide_clock+=delta;checkpoint_clock+=delta
    if not progress.guardian and tank.defeated:progress.guardian=true;stage="reward";_apply_garden_state();_save();hud.notify("Страж уступил. В оранжерее созрели шесть золотых жёлудей.",5)
    _update_guide(delta)
    if checkpoint_clock>25:checkpoint_clock=0;_save()
    for supply in supplies:
        if _distance(supply.position)<1.8 and not supply.get_meta("used",false) and (player.get_hp()<95 or player.ammo<24):
            supply.set_meta("used",true);supply.visible=false;player.health.heal(35);player.ammo=38;hud.notify("Запас садовника: здоровье и шишки восстановлены",3)
    if is_instance_valid(weapon):weapon.position.y=-.30+sin(seconds*8)*minf(player.velocity.length(),1)*.008

func _make_garden_objects() -> void:
    _object("journal",Vector3(4,0,59),"Прочитать дневник садовника","ДНЕВНИК САДА")
    for i in range(3):_object("valve%d"%i,Vector3(28+i*5,3,19),"Повернуть вентиль %d"%(i+1),"ШЛЮЗ %d"%(i+1))
    for i in range(3):_object("seed%d"%i,SEED_POSITIONS[i],"Забрать образец %d"%(i+1),["ПРИБРЕЖНЫЙ ЦВЕТОК","СЕМЕНА ОРАНЖЕРЕИ","ОРЕХОВАЯ РОЩА"][i])
    _object("guardian",Vector3(0,7,-20),"Поговорить со стражем","СТРАЖ ОРАНЖЕРЕИ")
    _object("reward",Vector3(0,7,-36),"Забрать золотые жёлуди","СЕРДЦЕ САДА")
    for pos in [Vector3(-12,0,51),Vector3(24,3,7),Vector3(-42,7,-43),Vector3(28,12,-83)]:_make_supply(pos)

func _object(id: String,p: Vector3,action: String,title: String) -> void:
    var node=Node3D.new();node.position=p;node.name=id;add_child(node)
    var wood=_mat(Color("8c7952"));var brass=_mat(Color("bb9c58"))
    if id.begins_with("valve"):
        _box(node,Vector3(0,.7,0),Vector3(.35,1.4,.35),wood)
        var ring=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=.35;mesh.outer_radius=.43;mesh.rings=20;mesh.ring_segments=5;ring.mesh=mesh;ring.material_override=brass;ring.position.y=1.45;node.add_child(ring)
    elif id.begins_with("seed"):
        _box(node,Vector3(0,.35,0),Vector3(.7,.7,.7),wood)
        var fruit=MeshInstance3D.new();var shape=SphereMesh.new();shape.radius=.18;shape.height=.4;fruit.mesh=shape if get_meta("reference_rendering",false) else preload("res://assets/level1/botanical/meshes/specimen.res");fruit.lod_bias=4;fruit.material_override=brass;fruit.position.y=.9;node.add_child(fruit)
    elif id=="journal":
        _box(node,Vector3(0,.85,0),Vector3(1,.1,.7),wood);_box(node,Vector3(0,.93,0),Vector3(.65,.045,.5),_mat(Color("d8cfad")))
        _box(node,Vector3(0,.4,0),Vector3(.16,.8,.16),wood)
    var label=Label3D.new();label.text=title;label.font_size=30;label.pixel_size=.004;label.position.y=2.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.visibility_range_end=12;label.modulate=Color("f0e4c5");node.add_child(label)
    interactables.append({"id":id,"position":p,"action":action,"node":node})

func _make_garden_car() -> void:
    var car=preload("res://scripts/level1_exit.gd").new();add_child(car);car.name="GardenExitCar";car.position=DEPARTURE
    var area=car.get_node("BoardingArea");area.body_entered.disconnect(car._on_body_entered)
    for node in car.find_children("*","Light3D",true,false):node.queue_free()
    for node in car.find_children("*","MeshInstance3D",true,false):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_guide() -> void:
    guide=Node3D.new();guide.name="GardenScout";guide.position=Vector3(-3,0,56) if progress.guide_step==0 else GUIDE_ROUTE[mini(progress.guide_step-1,4)];add_child(guide)
    var skin=preload("res://scripts/squirrel_3d_visual.gd").new();skin.target_height=1.3;guide.add_child(skin);skin.setup();skin.apply_active()
func _update_guide(delta: float) -> void:
    if progress.guide_step>=5:return
    var target: Vector3=GUIDE_ROUTE[progress.guide_step];var direction=target-guide.position;direction.y=0
    var moving=0.0
    if guide.position.distance_to(player.position)<13 and direction.length()>.45:
        guide.position+=direction.normalized()*minf(direction.length(),delta*1.9);guide.position.y=ground_height_at(guide.position);moving=1.9
    if direction.length()<.5 and guide.position.distance_to(player.position)<4:
        progress.guide_step+=1;_save()
        if progress.guide_step==5:hud.notify("Разведчик доверяет тебе. Теперь он поможет договориться со стражем.",5)
    guide.get_child(0).animate_squirrel(guide_clock,0,moving,direction.normalized()*moving,delta)

func _make_optics() -> void:
    for i in range(2):
        var pivot=Node3D.new();pivot.position=MIRRORS[i];pivot.name="Mirror%d"%i;add_child(pivot);mirror_nodes.append(pivot)
        _box(pivot,Vector3.ZERO,Vector3(1.6,1.9,.12),_mat(Color("394e41")))
        _box(pivot,Vector3(0,0,.075),Vector3(1.37,1.67,.035),_mat(Color("b6d2c4")))
        _box(self,MIRRORS[i]-Vector3.UP,Vector3(.12,2,.12),_mat(Color("69583b")))
        interactables.append({"id":"mirror%d"%i,"position":MIRRORS[i]-Vector3.UP*2,"action":"Повернуть зеркало %d"%(i+1),"node":pivot})
    bloom=Node3D.new();bloom.position=RECEIVER-Vector3.UP;add_child(bloom)
    for i in range(12):
        var leaf=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.18;mesh.height=.65;leaf.mesh=mesh if get_meta("reference_rendering",false) else preload("res://assets/level1/botanical/meshes/petal.res");leaf.lod_bias=4;leaf.material_override=_mat(Color("d7bd76"));leaf.position=Vector3(cos(i*TAU/12)*.6,.15,sin(i*TAU/12)*.6);leaf.rotation.z=.8;leaf.rotation.y=i*TAU/12;bloom.add_child(leaf)
func _normal(index: int) -> Vector3:
    var incoming=Vector3.RIGHT if index==0 else MIRRORS[0].direction_to(MIRRORS[1])
    var outgoing=MIRRORS[0].direction_to(MIRRORS[1]) if index==0 else MIRRORS[1].direction_to(RECEIVER)
    var correct=(incoming-outgoing).normalized()
    var turn=(progress.mirrors[index]-(1 if index==0 else 2))*PI/3
    return correct.rotated(Vector3.UP,turn)
func _update_optics() -> void:
    for node in beams:node.queue_free()
    beams.clear()
    for i in range(2):mirror_nodes[i].basis=Basis.looking_at(-_normal(i),Vector3.UP)
    var ray1=Vector3.RIGHT.bounce(_normal(0)).normalized();var desired1=MIRRORS[0].direction_to(MIRRORS[1])
    var hits1=ray1.dot(desired1)>.999
    _beam(MIRRORS[0]-Vector3.RIGHT*12,MIRRORS[0]);_beam(MIRRORS[0],MIRRORS[1] if hits1 else MIRRORS[0]+ray1*14)
    light_solved=false
    if hits1:
        var ray2=desired1.bounce(_normal(1)).normalized();light_solved=ray2.dot(MIRRORS[1].direction_to(RECEIVER))>.999
        _beam(MIRRORS[1],RECEIVER if light_solved else MIRRORS[1]+ray2*13)
    _apply_garden_state()
func _beam(a: Vector3,b: Vector3) -> void:
    var n=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.025;mesh.bottom_radius=.025;mesh.height=a.distance_to(b);mesh.radial_segments=6;n.mesh=mesh
    var material=_mat(Color("e8d49a"));material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color.a=.48;n.material_override=material
    n.position=(a+b)*.5;n.basis=Basis(Quaternion(Vector3.UP,a.direction_to(b)));n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);beams.append(n)

func _make_water() -> void:
    water_flow=Node3D.new();water_flow.name="IrrigationFlow";add_child(water_flow)
    var material=world.mats.water
    for pair in [[Vector3(42,12,-71),Vector3(42,7,-51)],[Vector3(42,7,-14),Vector3(42,3,10)],[Vector3(34,3.2,19),Vector3(18,3.2,22)]]:
        var a: Vector3=pair[0];var b: Vector3=pair[1];var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3(1.5,.05,a.distance_to(b));node.mesh=mesh;node.material_override=material;node.position=(a+b)*.5;node.basis=Basis.looking_at(b-a);water_flow.add_child(node)
    _apply_garden_state()

func _apply_garden_state() -> void:
    if is_instance_valid(water_flow):water_flow.visible=progress.water
    if is_instance_valid(bloom):bloom.scale=Vector3.ONE*(1.7 if progress.water and light_solved and progress.seeds.count(true)==3 else .55)
    for object in interactables:
        if object.id.begins_with("seed"):object.node.visible=not progress.seeds[int(object.id.trim_prefix("seed"))]

func objective_text() -> String:
    if progress.reward:return "ШЕСТЬ ЖЁЛУДЕЙ В РЮКЗАКЕ\nВернись к машине у входа в сад."
    if progress.guardian:return "САД ПРОСНУЛСЯ\nЗабери золотые жёлуди в центре оранжереи."
    if stage=="cache":return "СТРАЖ ОРАНЖЕРЕИ\nУходи от рывка. Стреляй после атаки — или приведи разведчика."
    if _garden_ready():return "САД ГОТОВ — СТРАЖ ЖДЁТ\nПодойди к стражу у входа в оранжерею. Разведчик поможет договориться."
    return "ВОЗРОДИТЬ БОТАНИЧЕСКИЙ САД\nВерни воду, собери три образца и направь свет к сердцу оранжереи."
func area_progress() -> String:return "ВОДА %s   ОБРАЗЦЫ %d / 3   СВЕТ %s"%["✓" if progress.water else "—",progress.seeds.count(true),"✓" if light_solved else "—"]
func trail_hint() -> String:return "ДНЕВНИК И КАРТА ПОМОГУТ НАЙТИ МАРШРУТ" if not progress.journal else "РАЗВЕДЧИК: %d / 5   ·   Сад можно исследовать в любом порядке"%progress.guide_step
func journey_map_text() -> String:return "БОТАНИЧЕСКИЙ САД"
func _distance(point: Vector3) -> float:return player.position.distance_to(point+Vector3.UP*.6)
func context_text() -> String:
    if mission_failed or mission_complete:return ""
    if _distance(DEPARTURE)<4:return "Сесть в машину" if progress.reward else "Сначала помоги саду и забери жёлуди"
    for object in interactables:
        if _distance(object.position)>3:continue
        var id: String=object.id
        if id.begins_with("seed") and progress.seeds[int(id.trim_prefix("seed"))]:continue
        if id=="guardian":
            if progress.guardian:return "Страж отдыхает"
            if not _garden_ready():return "Страж ждёт: верни воду, образцы и солнечный свет"
            return "Попросить разведчика успокоить стража" if progress.guide_step==5 else "Вызвать стража на поединок"
        if id=="reward":return object.action if progress.guardian else "Редкие жёлуди охраняет страж"
        return object.action
    return ""
func interact() -> void:
    if mission_failed or mission_complete or PauseManager.is_paused:return
    if _distance(DEPARTURE)<4:
        if progress.reward:
            mission_complete=true;hud.release_controls();player.stop();GardenState.clear();SignalBus.level_completed.emit(&"level1")
        return
    for object in interactables:
        if _distance(object.position)>3:continue
        var id: String=object.id
        if id=="journal":progress.journal=true;hud.notify("Дневник: шлюзы «открыт · закрыт · открыт». Образцы — у пруда, в западном крыле и в верхней роще. Зеркала направляют луч к цветку.",10)
        elif id.begins_with("valve"):
            var i=int(id.trim_prefix("valve"));progress.valves[i]=not progress.valves[i];object.node.rotation.y+=PI*.5
            progress.water=progress.valves==[true,false,true];hud.notify("Вода пошла по саду!" if progress.water else "Вентили: "+str(progress.valves),3)
        elif id.begins_with("seed"):
            var i=int(id.trim_prefix("seed"))
            if progress.seeds[i]:continue
            progress.seeds[i]=true;hud.notify("Ботанический образец %d / 3"%progress.seeds.count(true),3)
        elif id.begins_with("mirror"):
            var i=int(id.trim_prefix("mirror"));progress.mirrors[i]=(progress.mirrors[i]+1)%3;_update_optics();hud.notify("Солнечный луч достиг цветка" if light_solved else "Зеркало повернуто. Проследи за отражённым лучом.",3)
        elif id=="guardian" and _garden_ready() and not progress.guardian:
            if progress.guide_step==5:_pacify_guardian();hud.notify("Разведчик поручился за тебя. Страж разрешил забрать жёлуди.",5)
            else:stage="cache";hud.notify("Страж принял вызов. После рывка он уязвим.",4)
        elif id=="reward" and progress.guardian:
            progress.reward=true;GameState.acorns_collected=6;hud.notify("Шесть золотых жёлудей найдены. Возвращайся через сад к машине.",5)
        _apply_garden_state();_save();SignalBus.emit_audio_event(&"pickup",object.position);return
func _garden_ready() -> bool:return progress.water and progress.seeds.count(true)==3 and light_solved
func _pacify_guardian(save_now:=true) -> void:
    progress.guardian=true;stage="reward";tank.defeated=true;tank.set_physics_process(false);tank.hitbox.collision_layer=0;tank.visual.apply_active()
    if save_now:_save()
func _save() -> void:
    if not is_instance_valid(player) or mission_complete:return
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
