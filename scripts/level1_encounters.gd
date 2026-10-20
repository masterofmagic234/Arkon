extends Node
# Finite authored patrols. Guards exist before the first frame (and on the
# minimap), then wake after a gate warning. No pop-in, respawns or health scaling.
const Data = preload("res://scripts/level_data.gd")
const Props = preload("res://scripts/level1_park_props.gd")
const Enemy = preload("res://scenes/level1_enemy.tscn")
const WAVES := [
    {"id":&"Door01","title":"Лунный сад: метатель под прикрытием разведчика.","guards":[
        [1,Vector2i(18,10),[Vector2i(18,10),Vector2i(20,9),Vector2i(21,7)]],
        [0,Vector2i(21,5),[Vector2i(21,5),Vector2i(21,8),Vector2i(19,9)]]]},
    {"id":&"Door02","title":"Галерея: дозор с двух сторон. Используй стены как укрытие.","guards":[
        [0,Vector2i(31,7),[Vector2i(31,7),Vector2i(32,9),Vector2i(31,10)]],
        [1,Vector2i(38,14),[Vector2i(38,14),Vector2i(38,12),Vector2i(36,14)]],
        [0,Vector2i(44,13),[Vector2i(44,13),Vector2i(42,15),Vector2i(40,14)]]]},
    {"id":&"Door03","title":"Золотая роща: тяжёлый страж и метатель. Не стой на месте.","guards":[
        [2,Vector2i(40,23),[Vector2i(40,23),Vector2i(40,25),Vector2i(42,26)]],
        [1,Vector2i(34,30),[Vector2i(34,30),Vector2i(34,27),Vector2i(35,24)]]]},
    {"id":&"return","title":"Дозор перекрывает вход! Отвлеки его колокольчиком или проскочи к машине.","guards":[
        [0,Vector2i(10,30),[Vector2i(10,30),Vector2i(10,28),Vector2i(11,27)]],
        [0,Vector2i(8,23),[Vector2i(8,23),Vector2i(9,24),Vector2i(10,25)]]]},
]
var game: Node3D
var guards: Array[Array] = []
var triggered: Dictionary = {}
var pending: Dictionary = {}
var active: Dictionary = {}
var secured: Dictionary = {}
var supplies: Array[Area3D] = []
var supply_count := 0
var defeated_count := 0
var clock := 0.0
var update_timer := 0.0
var status_label: Label

func setup(owner_: Node3D) -> void:
    game=owner_
    for wave in range(WAVES.size()):
        var squad: Array=[]
        for i in range(WAVES[wave].guards.size()):
            var spec: Array=WAVES[wave].guards[i]
            var guard = Enemy.instantiate()
            guard.name="GardenGuard_%d_%d"%[wave,i]
            guard.squirrel_kind=spec[0]
            guard.simulation_range=32.0
            guard.position=Data.cell_center_world(spec[1])+Vector3.UP*.95
            for cell: Vector2i in spec[2]: guard.patrol_cells.append(cell)
            game.add_child(guard)
            # Reinforcements are only relevant within their local encounter.
            # Renderer-side ranges also cull dormant skeletons behind far walls.
            for mesh: MeshInstance3D in guard.squirrel_3d_visual.find_children("*","MeshInstance3D",true,false):
                mesh.visibility_range_end=30.0
                mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            guard.set_physics_process(false)
            guard.squirrel_3d_visual.animate_squirrel(0,0,0,Vector3.ZERO,.016)
            squad.append(guard)
        guards.append(squad)
    _build_supplies()
    status_label=Label.new()
    status_label.name="GardenChallengeStatus"
    status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    status_label.add_theme_font_size_override("font_size",14)
    status_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
    status_label.add_theme_constant_override("shadow_offset_y",2)
    game.get_node("HUD").add_child(status_label)
    SignalBus.enemy_defeated.connect(_on_enemy_defeated)
    _update_status()

func _exit_tree() -> void:
    if SignalBus.enemy_defeated.is_connected(_on_enemy_defeated):
        SignalBus.enemy_defeated.disconnect(_on_enemy_defeated)

func gate_opened(id: StringName) -> void:
    for i in range(WAVES.size()):
        if WAVES[i].id==id: _warn(i)

func begin_return() -> void:
    _warn(3)

func _warn(wave: int) -> void:
    if triggered.has(wave) or game.mission_failed or game.mission_complete: return
    triggered[wave]=true
    pending[wave]=1.8
    SignalBus.show_message.emit(WAVES[wave].title,3.6)
    for guard in guards[wave]:
        if is_instance_valid(guard) and not guard.defeated: guard.warning_ring.visible=true
    _update_status()

func _physics_process(delta: float) -> void:
    if game==null: return
    if game.mission_failed or game.mission_complete:
        for squad in guards:
            for guard in squad:
                if is_instance_valid(guard): guard.set_physics_process(false)
        set_physics_process(false)
        return
    clock+=delta
    for wave: int in pending.keys():
        pending[wave]-=delta
        if pending[wave]>0: continue
        pending.erase(wave)
        active[wave]=true
        for guard in guards[wave]:
            if not is_instance_valid(guard) or guard.defeated: continue
            guard.warning_ring.visible=false
            guard.ai.attack_cooldown=1.0
            guard.set_physics_process(true)
    update_timer-=delta
    if update_timer<=0:
        update_timer=.25
        for wave: int in active.keys():
            if secured.has(wave): continue
            var alive := 0
            for guard in guards[wave]:
                if is_instance_valid(guard) and not guard.defeated: alive+=1
            if alive==0:
                secured[wave]=true
                SignalBus.show_message.emit("Дозор обезврежен. Можно перевести дух и поискать тайник.",2.6)
        _update_status()

func _on_enemy_defeated(enemy: Node) -> void:
    for squad in guards:
        if squad.has(enemy):
            defeated_count+=1
            _update_status()
            return

func _update_status() -> void:
    if status_label==null: return
    var count_label: Label=game.get_node("HUD/Count")
    status_label.position=count_label.position+Vector2(0,count_label.size.y+1)
    status_label.size=Vector2(340,25)
    status_label.text="Тайники %d / 3   ·   Дозоры можно обойти"%supply_count
    status_label.modulate=Color("e7bf87") if pending.is_empty() else Color("f1a27f")
    status_label.visible=not game.mission_complete and not game.mission_failed

func _build_supplies() -> void:
    var box := BoxMesh.new();box.size=Vector3.ONE
    var ring := TorusMesh.new();ring.inner_radius=.18;ring.outer_radius=.22;ring.rings=20;ring.ring_segments=6
    var material := StandardMaterial3D.new();material.albedo_color=Color("304d50");material.roughness=.6
    var trim := StandardMaterial3D.new();trim.albedo_color=Color("b69761")
    var glow := StandardMaterial3D.new();glow.albedo_color=Color("9ae4cc");glow.emission_enabled=true;glow.emission=Color("72dcb9");glow.emission_energy_multiplier=1.2
    for i in range(Props.SUPPLY_CELLS.size()):
        var area := Area3D.new()
        area.name="GardenSupply%d"%(i+1)
        area.collision_layer=0;area.collision_mask=4
        area.position=Data.cell_center_world(Props.SUPPLY_CELLS[i])
        var collider := CollisionShape3D.new();var shape := SphereShape3D.new();shape.radius=1.3
        collider.shape=shape;collider.position.y=.6;area.add_child(collider)
        var case_ := MeshInstance3D.new();case_.mesh=box;case_.material_override=material
        case_.position.y=.35;case_.scale=Vector3(.78,.70,.60);area.add_child(case_)
        for side: float in [-1,1]:
            var strap := MeshInstance3D.new();strap.mesh=box;strap.material_override=trim
            strap.position=Vector3(side*.26,.36,0);strap.scale=Vector3(.06,.72,.62);area.add_child(strap)
        var emblem := MeshInstance3D.new();emblem.name="SupplyEmblem";emblem.mesh=ring;emblem.material_override=glow
        emblem.rotation.x=PI*.5;emblem.position=Vector3(0,.38,.315);area.add_child(emblem)
        var title := Label3D.new();title.name="SupplyTitle";title.text="ТАЙНИК\n+6 зарядов · +15 здоровья"
        title.font_size=40;title.pixel_size=.003;title.position.y=1.18
        title.billboard=BaseMaterial3D.BILLBOARD_ENABLED;title.modulate=Color("a3e5d2");title.visibility_range_end=14
        area.add_child(title)
        area.add_to_group("level1_supply")
        game.add_child(area)
        area.body_entered.connect(_on_supply_entered.bind(area))
        supplies.append(area)

func _on_supply_entered(body: Node3D, supply: Area3D) -> void:
    if body!=game.player or supply.has_meta("opened") or game.mission_complete or game.mission_failed: return
    supply.set_meta("opened",true)
    supply.set_deferred("monitoring",false)
    supply_count+=1
    var before: int=body.ammo
    var hp_before: int=body.get_hp()
    body.ammo=mini(body.ammo+6,Data.MAX_AMMO)
    body.health.heal(15)
    SignalBus.weapon_changed.emit(body,&"l1_sidearm",body.ammo)
    SignalBus.emit_audio_event(&"pickup",supply.global_position)
    SignalBus.show_message.emit("Тайник %d / 3: +%d зарядов, +%d здоровья."%[supply_count,body.ammo-before,body.get_hp()-hp_before],3.0)
    supply.get_node("SupplyEmblem").visible=false
    supply.get_node("SupplyTitle").text="ТАЙНИК НАЙДЕН"
    supply.get_node("SupplyTitle").modulate=Color("879c96")
    _update_status()
