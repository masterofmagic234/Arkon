extends Node3D
class_name Level1Environment

# Presentation for the authored park. Gameplay geometry remains in the layout
# scene, and every decorative batch is bounded to a spatial chunk for culling.
const LevelData = preload("res://scripts/level_data.gd")
const GROUND_TEXTURE = preload("res://assets/level1/cozy/sky.svg")
const DETAIL_TEXTURE = preload("res://assets/level1/park_ground.png")
const GROUND_SHADER = preload("res://shaders/level1_park_ground.gdshader")
const Props = preload("res://scripts/level1_park_props.gd")
const Pond = preload("res://scripts/level1_park_pond.gd")
const Fireflies = preload("res://scripts/level1_park_fireflies.gd")
const Trees = preload("res://scripts/level1_park_trees.gd")
const StaticBatch = preload("res://scripts/level1_trail_batch.gd")
const FOG_COLOR := Color("1a3448")

var materials: Dictionary = {}
var meshes: Dictionary = {}
var batches: Dictionary = {}
var rng := RandomNumberGenerator.new()
var ornaments: Array[Node3D] = []
var fireflies: Node3D
var clock := 0.0
var park_ready := false
var scenery_root: Node3D
var trees := Trees.new()
var opaque_walls: Array[AABB]=[]
var mobile_rendering := false
var previous_3d_scale := -1.0

func _ready() -> void:
    call_deferred("_build")

func _build() -> void:
    rng.seed = 7112026
    _make_resources()
    _setup_atmosphere()
    scenery_root = Node3D.new()
    scenery_root.name = "ParkScenery"
    add_child(scenery_root)
    _build_ground()
    _build_hedges_and_forest()
    _build_landmarks()
    Props.build_collisions(self)
    _build_gates()
    _build_pickups()
    _flush_batches()
    preload("res://scripts/level1_wall_occlusion.gd").build(scenery_root,opaque_walls)
    _build_fireflies()
    _build_secret()
    var grass := preload("res://scripts/level1_grass_generator.gd").new()
    grass.name = "Level1GrassGenerator"
    grass.density_per_cell = 2
    grass.chunk_cells_x = 12
    grass.chunk_cells_z = 12
    grass.visibility_end = 22.0
    grass.curated_edges = true
    grass.wind_strength = 0.025
    grass.grass_texture = preload("res://assets/level1/textures/park_meadow_tuft.svg")
    grass.scale_range = Vector2(0.45,1.10)
    grass.alpha_scissor_threshold = 0.38
    add_child(grass)
    park_ready = true

func _build_secret() -> void:
    var chest := Area3D.new()
    chest.name = "GardenSecretChest"
    chest.collision_layer = 0
    chest.collision_mask = 4
    chest.position = LevelData.park_position("Secret")+Vector3.UP*0.5
    var collider := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.1
    collider.shape = sphere
    chest.add_child(collider)
    _part(chest,"box","wood",Vector3.ZERO,Vector3(0.85,0.5,0.55))
    _part(chest,"box","brass",Vector3(0,0.1,0.30),Vector3(0.12,0.15,0.07))
    add_child(chest)
    chest.body_entered.connect(func(body: Node3D):
        if chest.has_meta("opened") or not body.has_method("is_level1_player"): return
        chest.set_meta("opened",true)
        body.health.heal(20)
        body.ammo = mini(body.ammo+8,LevelData.MAX_AMMO)
        SignalBus.show_message.emit("Тайник садовника: здоровье и восемь зарядов. Белкам ни слова.",3.0)
        SignalBus.emit_audio_event(&"pickup",chest.global_position))

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    m.metallic_specular = 0.0
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    return m

func _make_resources() -> void:
    materials = {}
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    meshes["box"] = box
    var ball := SphereMesh.new()
    ball.radius = 0.5
    ball.height = 1.0
    ball.radial_segments = 12
    ball.rings = 6
    meshes["ball"] = ball
    var boundary_crown:=SphereMesh.new()
    boundary_crown.radius=.5;boundary_crown.height=1.0
    boundary_crown.radial_segments=8;boundary_crown.rings=3
    meshes["boundary_crown"]=boundary_crown
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.36
    trunk.bottom_radius = 0.5
    trunk.height = 1.0
    trunk.radial_segments = 10
    meshes["trunk"] = trunk
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.5
    cylinder.bottom_radius = 0.5
    cylinder.height = 1.0
    cylinder.radial_segments = 16
    meshes["cylinder"] = cylinder
    preload("res://scripts/level1_cozy_palette.gd").materials(self)
    trees.make_resources(self)
    var fixtures:=ShaderMaterial.new();fixtures.shader=preload("res://shaders/level1_static_fixture.gdshader")
    materials.static_fixtures=fixtures
    var colored:=ShaderMaterial.new();colored.shader=preload("res://shaders/level1_vertex_solid.gdshader")
    materials.vertex_solid=colored

func _batch(shape: String, material: String, position_: Vector3, size_: Vector3, basis_ := Basis.IDENTITY) -> void:
    var chunk:=12.0 if shape.begins_with("oak") else 24.0
    var key := "%s|%s|%d|%d" % [shape, material, int(floor(position_.x / chunk)), int(floor(position_.z / chunk))]
    if not batches.has(key):
        batches[key] = []
    batches[key].append(Transform3D(basis_*Basis.from_scale(size_), position_))

func _flush_batches() -> void:
    var fixtures:=StaticBatch.new();fixtures.chunk_metres=24.0
    var luminous:=StaticBatch.new();luminous.chunk_metres=24.0
    for key: String in batches:
        var parts := key.split("|")
        var id: String=parts[1]
        if id in ["wood","bark","iron","brass","stone","stone_dark","lantern_rope","lamp","lamp_moon","lamp_gallery","moon"]:
            var color:=_vertex_color(id)
            var light:=id in ["lamp","lamp_moon","lamp_gallery","moon"]
            if not light:color.a=1.0 if id in ["wood","bark"] else (.5 if id in ["stone","stone_dark"] else 0.0)
            for transform: Transform3D in batches[key]:
                (luminous if light else fixtures).add(meshes[parts[0]],transform,color)
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = meshes[parts[0]]
        mm.instance_count = batches[key].size()
        for i in range(mm.instance_count):
            mm.set_instance_transform(i, batches[key][i])
        var node := MultiMeshInstance3D.new()
        node.name = "ParkBatch_" + key.replace("|", "_")
        node.multimesh = mm
        if parts[0] in ["ball","boundary_crown"] and parts[1] in ["leaf","hedge"]:
            var lowest := INF
            for transform: Transform3D in batches[key]:
                var bounds: AABB=transform*mm.mesh.get_aabb().grow(.075)
                lowest=minf(lowest,bounds.position.y)
            node.set_meta("minimum_crown_y",lowest)
        node.ignore_occlusion_culling = str(parts[1]).begins_with("wall") or str(parts[1]).begins_with("outer_wall")
        node.material_override = materials[parts[1]]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.visibility_range_end = 96.0
        if parts[0]=="oak_sprig":
            node.visibility_range_end = 42.0
            node.extra_cull_margin = 0.08
        elif parts[0] in ["oak_crown","oak_crown_far"]:
            node.extra_cull_margin = 0.10
        scenery_root.add_child(node)
    fixtures.finish(scenery_root,"ParkFixture",96.0,materials.static_fixtures)
    luminous.finish(scenery_root,"ParkLuminous",96.0,materials.vertex_solid)
    batches.clear()

func _vertex_color(id: String) -> Color:
    var material: Material=materials[id]
    var color: Color=material.albedo_color if material is StandardMaterial3D else material.get_shader_parameter("tint")
    color=color.srgb_to_linear()
    color.a=material.emission_energy_multiplier/4.0 if material is StandardMaterial3D and material.emission_enabled else 0.0
    return color

func _setup_atmosphere() -> void:
    var world := get_parent().get_node("WorldEnvironment") as WorldEnvironment
    var env := world.environment
    env.ambient_light_color = Color("b8cecf")
    env.ambient_light_energy = 0.56
    env.background_energy_multiplier = 0.75
    env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    env.fog_light_color = FOG_COLOR
    env.fog_depth_begin = 28.0
    env.fog_depth_end = 108.0
    env.fog_depth_curve = 1.25
    env.fog_sky_affect = 0.0
    env.glow_enabled = false
    env.glow_bloom = 0.08
    env.glow_intensity = 0.75
    env.glow_hdr_threshold = 1.0
    if OS.has_feature("mobile"): apply_mobile_rendering()
    var sky_material := env.sky.sky_material as ShaderMaterial
    if sky_material:
        sky_material.set_shader_parameter("panorama",preload("res://assets/level1/cozy/sky.svg"))
        # source_color uniforms need a Color Variant for Forward+ to convert
        # their authored sRGB values to linear light. Vector3 bypasses it.
        sky_material.set_shader_parameter("fog_color", FOG_COLOR)
        sky_material.set_shader_parameter("horizon", 0.54)
        sky_material.set_shader_parameter("blend_width", 0.12)
    var dusk:=ProceduralSkyMaterial.new()
    dusk.sky_top_color=Color("122c47");dusk.sky_horizon_color=Color("657f88")
    dusk.ground_horizon_color=Color("365767");dusk.ground_bottom_color=Color("1a3448")
    dusk.sky_energy_multiplier=.72;dusk.ground_energy_multiplier=.65
    dusk.sun_angle_max=1.5;dusk.sun_curve=.04
    env.sky.sky_material=dusk
    var moon := get_parent().get_node("MoonLight") as DirectionalLight3D
    moon.light_color = Color("d1decd")
    moon.light_energy = 0.72
    moon.rotation_degrees = Vector3(-48.0,-32.0,0.0)
    moon.shadow_enabled = false

func apply_mobile_rendering() -> void:
    # Keep UI at the physical display resolution. Only this level's 3D target
    # is bounded; restore the prior viewport setting before entering the race.
    var viewport:=get_viewport()
    if not mobile_rendering:
        previous_3d_scale=viewport.scaling_3d_scale
        viewport.size_changed.connect(_resize_mobile_target)
    mobile_rendering=true
    get_parent().get_node("WorldEnvironment").environment.glow_enabled=false
    _resize_mobile_target()

func _resize_mobile_target() -> void:
    var viewport:=get_viewport()
    var size_:=Vector2(get_tree().root.size)
    viewport.scaling_3d_scale=minf(previous_3d_scale,minf(1.0,sqrt(1280.0*720.0/maxf(1.0,size_.x*size_.y))))

func _exit_tree() -> void:
    if not mobile_rendering:return
    var viewport:=get_viewport()
    if viewport.size_changed.is_connected(_resize_mobile_target):viewport.size_changed.disconnect(_resize_mobile_target)
    viewport.scaling_3d_scale=previous_3d_scale

func _build_ground() -> void:
    var material := ShaderMaterial.new()
    material.shader = GROUND_SHADER
    material.set_shader_parameter("tint",Color("31595c"))
    # Compatibility has eight local lights per object. Small ground patches
    # let every lantern light its own surroundings without a larger shader cap.
    var total := Vector2(LevelData.MAP_WIDTH*LevelData.CELL_SIZE+32.0,LevelData.MAP_HEIGHT*LevelData.CELL_SIZE+32.0)
    var chunks := Vector2i(ceili(total.x/24.0),ceili(total.y/24.0))
    var patch := PlaneMesh.new()
    patch.size=total/Vector2(chunks)
    # Vertex lighting keeps the moon/lantern gradients without a per-pixel
    # clustered-light evaluation over the entire screen.
    patch.subdivide_width=7;patch.subdivide_depth=7
    var ground_root := Node3D.new()
    ground_root.name="ParkGround"
    scenery_root.add_child(ground_root)
    for z in range(chunks.y):
        for x in range(chunks.x):
            var ground := MeshInstance3D.new()
            ground.name="Ground_%02d_%02d"%[x,z]
            ground.mesh=patch
            ground.material_override=material
            ground.position=Vector3(-total.x*0.5+(x+0.5)*patch.size.x,0,-total.y*0.5+(z+0.5)*patch.size.y)
            ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            ground_root.add_child(ground)
    preload("res://scripts/level1_estate.gd").new().build_paths(self)

func _walkable(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < LevelData.MAP_WIDTH and cell.y < LevelData.MAP_HEIGHT and LevelData.CANONICAL_MAP[cell.y][cell.x] == "."

func _build_hedges_and_forest() -> void:
    preload("res://scripts/level1_estate.gd").new().build_boundary(self)

func _tree(p: Vector3, height: float, legendary: bool, distant: bool = false) -> void:
    # Preserve the surrounding scene's seeded bushes and forest positions.
    # Tree variation has its own seed and cannot reshuffle other decorations.
    for i in range(7 if legendary else 4): rng.randf()
    trees.plant(self,p,height,legendary,distant)
    var width := height*(0.17 if legendary else 0.12)
    _batch("cylinder","shadow",p+Vector3.UP*0.009,Vector3(width*2.0,0.01,width*2.0))

func _lamp(p: Vector3, height: float = 3.4) -> void:
    var zone := LevelData.episode_at(p)
    var core := "lamp_moon" if zone==1 else ("lamp_gallery" if zone==2 else "lamp")
    _batch("cylinder","iron",p+Vector3.UP*height*0.48,Vector3(0.14,height*0.96,0.14))
    _batch("cylinder","brass",p+Vector3.UP*0.12,Vector3(0.45,0.24,0.45))
    _batch("box",core,p+Vector3.UP*height,Vector3(0.25,0.42,0.25))
    _batch("cylinder","brass",p+Vector3.UP*(height-0.25),Vector3(0.34,0.04,0.34))
    for offset in [Vector3(-0.2,0,-0.2),Vector3(0.2,0,-0.2),Vector3(-0.2,0,0.2),Vector3(0.2,0,0.2)]:
        _batch("box","iron",p+Vector3.UP*height+offset,Vector3(0.04,0.64,0.04))
    _batch("box","iron",p+Vector3.UP*(height+0.35),Vector3(0.55,0.12,0.55))
    _batch("box","iron",p+Vector3.UP*(height-0.34),Vector3(0.46,0.10,0.46))
    _batch("ball","brass",p+Vector3.UP*(height+0.48),Vector3(0.11,0.16,0.11))
    var light := OmniLight3D.new()
    light.name="ParkLantern_%d_%d"%[roundi(p.x*10),roundi(p.z*10)]
    light.position = p+Vector3.UP*(height-0.1)
    light.light_color = Color("b4e5e3") if zone==1 else (Color("dfbce7") if zone==2 else Color(1.0,0.72,0.40))
    light.light_energy = 2.4
    light.omni_range = 6.8
    light.omni_attenuation = 1.55
    light.distance_fade_enabled = true
    light.distance_fade_begin = 27.0
    light.distance_fade_length = 8.0
    light.shadow_enabled = false
    add_child(light)

func _bench(p: Vector3, yaw: float) -> void:
    var basis_ := Basis(Vector3.UP,yaw)
    for i in range(4):
        _batch("box","wood",p+basis_*Vector3(0,0.55,(i-1.5)*0.17),Vector3(2.15,0.085,0.14),basis_)
        _batch("box","wood",p+basis_*Vector3(0,0.84+i*0.16,0.32+i*0.025),Vector3(2.15,0.12,0.085),basis_)
    for x: float in [-0.88,0.88]:
        _batch("box","iron",p+basis_*Vector3(x,0.25,0),Vector3(0.10,0.50,0.62),basis_)
        _batch("box","iron",p+basis_*Vector3(x,0.71,0.30),Vector3(0.09,1.05,0.08),basis_)
        _batch("box","iron",p+basis_*Vector3(x,0.73,-0.23),Vector3(0.07,0.43,0.07),basis_)
        _batch("box","iron",p+basis_*Vector3(x,0.92,0.02),Vector3(0.12,0.08,0.68),basis_)
        _batch("ball","brass",p+basis_*Vector3(x,0.94,-0.31),Vector3(0.13,0.11,0.13))

func _sign(p: Vector3, text_: String, yaw: float = 0.0) -> void:
    var basis_ := Basis(Vector3.UP,yaw)
    _batch("box","wood",p+Vector3.UP*1.9,Vector3(2.7,0.8,0.15),basis_)
    for x: float in [-1.0,1.0]:
        _batch("box","wood",p+basis_*Vector3(x,0.9,0),Vector3(0.12,1.8,0.12),basis_)
    var label := Label3D.new()
    label.text = text_
    label.font_size = 64
    label.pixel_size = 0.003
    label.position = p+Vector3.UP*1.9+basis_*Vector3(0,0,0.09)
    label.rotation.y = yaw
    label.modulate = Color(1.0,0.84,0.52)
    label.outline_size = 4
    label.no_depth_test = false
    label.visibility_range_end=26.0
    add_child(label)

func _build_landmarks() -> void:
    preload("res://scripts/level1_estate.gd").new().build(self)

func _build_gates() -> void:
    var batch:=StaticBatch.new();batch.chunk_metres=0.0
    for i in range(7):
        batch.add(meshes.box,Transform3D(Basis.from_scale(Vector3(.065,1.95,.065)),Vector3(0,0,-.78+i*.26)),_vertex_color("iron"))
    for y: float in [-.65,.35,.85]:
        batch.add(meshes.box,Transform3D(Basis.from_scale(Vector3(.12,.10,1.85)),Vector3(0,y,0)),_vertex_color("brass"))
    var source:=Node3D.new()
    batch.finish(source,"GateLeaf",60.0,materials.vertex_solid)
    var leaf_mesh: Mesh=source.get_child(0).mesh
    source.free()
    for gate in get_tree().get_nodes_in_group("level1_door"):
        var leaf := gate.get_node("Pivot/Leaf") as Node3D
        var grille:=MeshInstance3D.new();grille.name="GateLeafVisual";grille.mesh=leaf_mesh
        grille.material_override=materials.vertex_solid;grille.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        grille.visibility_range_end=60.0;leaf.add_child(grille)
        var b: Basis = gate.global_basis
        var wall_id: String = ["wall_0","wall_1","wall_3"][clampi(gate.required_key-1,0,2)]
        for z: float in [-1.15,1.15]:
            _batch("box",wall_id,gate.global_position+b*Vector3(0,1.15,z),Vector3(0.7,2.3,0.7),b)
            _batch("box","stone",gate.global_position+b*Vector3(0,2.32,z),Vector3(0.87,0.22,0.87),b)
            _batch("ball","lamp",gate.global_position+b*Vector3(0,2.5,z),Vector3(0.23,0.23,0.23))

func _part(root_: Node3D, shape: String, material: String, p: Vector3, scale_: Vector3) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = meshes[shape]
    n.material_override = materials[material]
    n.position = p
    n.scale = scale_
    root_.add_child(n)
    return n

func _build_pickups() -> void:
    for group in ["level1_acorn","level1_key"]:
        for item in get_tree().get_nodes_in_group(group):
            item.get_node("Visual").visible = false
            var model := Node3D.new()
            model.name = "ParkPickupVisual"
            item.add_child(model)
            if group == "level1_acorn":
                _part(model,"ball","acorn",Vector3.ZERO,Vector3(0.50,0.65,0.50))
                _part(model,"ball","bark",Vector3(0,0.25,0),Vector3(0.57,0.27,0.57))
                _part(model,"trunk","wood",Vector3(0,0.43,0),Vector3(0.09,0.17,0.09))
            else:
                var ring := TorusMesh.new()
                ring.inner_radius = 0.12
                ring.outer_radius = 0.22
                ring.rings = 16
                ring.ring_segments = 8
                var hoop := MeshInstance3D.new()
                hoop.mesh = ring
                hoop.material_override = materials["key"]
                hoop.rotation.x = PI*0.5
                hoop.position.y = 0.25
                model.add_child(hoop)
                _part(model,"box","key",Vector3(0,-0.1,0),Vector3(0.10,0.50,0.09))
                _part(model,"box","key",Vector3(0.09,-0.31,0),Vector3(0.25,0.09,0.09))
                _part(model,"box","key",Vector3(0.07,-0.18,0),Vector3(0.20,0.07,0.09))
            ornaments.append(model)
            var pedestal := Node3D.new()
            pedestal.name = "PickupPedestal_"+String(item.name)
            scenery_root.add_child(pedestal)
            pedestal.global_position = Vector3(item.global_position.x,0,item.global_position.z)
            _part(pedestal,"cylinder","stone_dark",Vector3.UP*0.12,Vector3(0.95,0.24,0.95))
            for i in range(3):
                var a := i*TAU/3.0
                _part(model,"ball","lamp",Vector3(cos(a)*0.55,0.15,sin(a)*0.55),Vector3.ONE*0.045)
            _merge_pickup(model)
    for item in get_tree().get_nodes_in_group("level1_trap"):
        item.get_node("Visual").visible = false
        var pine := Node3D.new()
        item.add_child(pine)
        for i in range(5):
            _part(pine,"ball","bark",Vector3(0,i*0.10,0),Vector3(0.40-i*0.05,0.16,0.40-i*0.05))

func _merge_pickup(model: Node3D) -> void:
    var batch:=StaticBatch.new();batch.chunk_metres=0.0
    for child in model.get_children():
        if not child is MeshInstance3D:continue
        var id: String="key"
        for candidate in ["acorn","bark","wood","lamp","key"]:
            if child.material_override==materials[candidate]:id=candidate;break
        batch.add(child.mesh,child.transform,_vertex_color(id))
        model.remove_child(child);child.free()
    batch.finish(model,"ParkPickup",42.0,materials.vertex_solid)

func _build_fireflies() -> void:
    fireflies=Fireflies.build(self)

func _process(delta: float) -> void:
    clock += delta
    for i in range(ornaments.size()):
        var n := ornaments[i]
        if is_instance_valid(n):
            n.rotation.y += delta*0.65
            n.position.y = 0.22+sin(clock*1.8+i)*0.10
