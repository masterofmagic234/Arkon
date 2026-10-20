extends Node3D
class_name Level1Environment

# Presentation for the authored park. Gameplay geometry remains in the layout
# scene, and every decorative batch is bounded to a spatial chunk for culling.
const LevelData = preload("res://scripts/level_data.gd")
const GROUND_TEXTURE = preload("res://assets/level1/textures/park_meadow.jpg")
const DETAIL_TEXTURE = preload("res://assets/level1/park_ground.png")
const GROUND_SHADER = preload("res://shaders/level1_park_ground.gdshader")
const Props = preload("res://scripts/level1_park_props.gd")
const Pond = preload("res://scripts/level1_park_pond.gd")
const Fireflies = preload("res://scripts/level1_park_fireflies.gd")
const Trees = preload("res://scripts/level1_park_trees.gd")
const WALL_TEXTURES := [preload("res://wall_zone1.png"),preload("res://wall_zone2.png"),preload("res://wall_zone3.png"),preload("res://wall_zone4.png")]
const FOG_COLOR := Color(0.065, 0.10, 0.155)

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
    preload("res://scripts/level1_night_garden.gd").new().build(self)
    Props.build_collisions(self)
    _build_gates()
    _build_pickups()
    preload("res://scripts/level1_park_detail.gd").build(self)
    _flush_batches()
    _combine_static_fixtures()
    preload("res://scripts/level1_wall_occlusion.gd").build(scenery_root,opaque_walls)
    _build_fireflies()
    _build_secret()
    var grass := preload("res://scripts/level1_grass_generator.gd").new()
    grass.name = "Level1GrassGenerator"
    grass.density_per_cell = 6
    grass.chunk_cells_x = 12
    grass.chunk_cells_z = 12
    grass.visibility_end = 48.0
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
    m.roughness = 0.88
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    return m

func _make_resources() -> void:
    materials = {
        "bark": _material(Color(0.25, 0.17, 0.13)),
        "hedge": _material(Color(0.12, 0.23, 0.16)),
        "leaf": _material(Color(0.20, 0.34, 0.23)),
        "leaf_light": _material(Color(0.30, 0.40, 0.24)),
        "gold_leaf": _material(Color(0.56, 0.39, 0.17)),
        "stone": _material(Color(0.35, 0.39, 0.41)),
        "stone_dark": _material(Color(0.22, 0.28, 0.29)),
        "wood": _material(Color(0.32, 0.22, 0.14)),
        "iron": _material(Color(0.055, 0.09, 0.115)),
        "brass": _material(Color(0.61, 0.43, 0.20)),
        "lamp": _material(Color(1.0, 0.66, 0.25), 3.6),
        "acorn": _material(Color(0.88, 0.43, 0.10), 0.18),
        "key": _material(Color(1.0, 0.72, 0.24), 0.35),
        "moon": _material(Color(0.71, 0.81, 1.0), 1.5),
        "lamp_moon": _material(Color("9ce5e3"),2.7),
        "lamp_gallery": _material(Color("e0b4e8"),2.7),
        "shadow": _material(Color(0.055, 0.08, 0.055)),
    }
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    meshes["box"] = box
    var ball := SphereMesh.new()
    ball.radius = 0.5
    ball.height = 1.0
    ball.radial_segments = 12
    ball.rings = 6
    meshes["ball"] = ball
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
    for id in ["leaf","leaf_light","gold_leaf","hedge"]:
        var previous := materials[id] as StandardMaterial3D
        var mat := ShaderMaterial.new()
        mat.shader = preload("res://shaders/level1_foliage.gdshader")
        mat.set_shader_parameter("leaf_tex",DETAIL_TEXTURE)
        mat.set_shader_parameter("tint",previous.albedo_color)
        materials[id] = mat
    for i in range(5):
        var mat := ShaderMaterial.new()
        mat.shader=preload("res://shaders/level1_park_masonry.gdshader")
        mat.set_shader_parameter("masonry_tex",preload("res://assets/level1/textures/park_limestone.jpg") if i==4 else WALL_TEXTURES[i])
        mat.set_shader_parameter("tile_metres",2.8)
        mat.set_shader_parameter("tint",Color(0.80,0.85,0.87) if i==4 else Color(0.72,0.78,0.75))
        materials["wall_%d"%i]=mat
    var outer_wall := ShaderMaterial.new()
    outer_wall.shader = preload("res://shaders/level1_park_masonry.gdshader")
    outer_wall.set_shader_parameter("masonry_tex",preload("res://assets/level1/textures/park_outer_limestone.jpg"))
    outer_wall.set_shader_parameter("tile_metres",3.0)
    outer_wall.set_shader_parameter("tint",Color(0.77,0.82,0.80))
    outer_wall.set_shader_parameter("relief_metres",0.026)
    materials["outer_wall"] = outer_wall
    var wall_cap := outer_wall.duplicate() as ShaderMaterial
    wall_cap.set_shader_parameter("tint",Color(0.71,0.76,0.73))
    wall_cap.set_shader_parameter("relief_metres",0.012)
    materials["outer_wall_cap"] = wall_cap
    for id in ["stone","stone_dark","wood","bark"]:
        var previous := materials[id] as StandardMaterial3D
        var mat := ShaderMaterial.new()
        mat.shader = preload("res://shaders/level1_surface.gdshader")
        mat.set_shader_parameter("detail_tex",DETAIL_TEXTURE)
        mat.set_shader_parameter("tint",previous.albedo_color)
        mat.set_shader_parameter("wood",id in ["wood","bark"])
        materials[id] = mat
    trees.make_resources(self)

func _batch(shape: String, material: String, position_: Vector3, size_: Vector3, basis_ := Basis.IDENTITY) -> void:
    var key := "%s|%s|%d|%d" % [shape, material, int(floor(position_.x / 12.0)), int(floor(position_.z / 12.0))]
    if not batches.has(key):
        batches[key] = []
    batches[key].append(Transform3D(basis_*Basis.from_scale(size_), position_))

func _flush_batches() -> void:
    for key: String in batches:
        var parts := key.split("|")
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = meshes[parts[0]]
        mm.instance_count = batches[key].size()
        for i in range(mm.instance_count):
            mm.set_instance_transform(i, batches[key][i])
        var node := MultiMeshInstance3D.new()
        node.name = "ParkBatch_" + key.replace("|", "_")
        node.multimesh = mm
        if parts[0]=="ball" and parts[1] in ["leaf","hedge"]:
            var lowest := INF
            for transform: Transform3D in batches[key]:
                var bounds: AABB=transform*mm.mesh.get_aabb().grow(.075)
                lowest=minf(lowest,bounds.position.y)
            node.set_meta("minimum_crown_y",lowest)
        node.ignore_occlusion_culling = str(parts[1]).begins_with("wall") or str(parts[1]).begins_with("outer_wall")
        node.material_override = materials[parts[1]]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.visibility_range_end = 76.0
        if parts[0]=="oak_sprig":
            node.visibility_range_end = 42.0
            node.extra_cull_margin = 0.08
        elif parts[0] in ["oak_crown","oak_crown_far"]:
            node.extra_cull_margin = 0.10
        scenery_root.add_child(node)
    batches.clear()

func _combine_static_fixtures() -> void:
    # Benches, lamp housings, rails and stone trim already share materials and
    # spatial blocks. Combine their different primitive shapes within that
    # same block, preserving every transformed triangle and normal. Masonry,
    # foliage, tree LOD profiles and moving pickups/gate leaves stay separate.
    var groups: Dictionary = {}
    for node in scenery_root.get_children():
        if not node is MultiMeshInstance3D or not String(node.name).begins_with("ParkBatch_"): continue
        var parts := String(node.name).trim_prefix("ParkBatch_").split("_")
        # Names contain compound material/shape names; identity comes from the
        # actual shared resource rather than parsing those names.
        var id := ""
        for candidate: String in ["wood","iron","brass","lamp","moon","stone","stone_dark","lantern_rope"]:
            if materials.has(candidate) and node.material_override==materials[candidate]: id=candidate; break
        if id.is_empty(): continue
        var suffix := "_%s_%s"%[parts[-2],parts[-1]]
        var key := id+suffix
        if not groups.has(key): groups[key]=[]
        groups[key].append(node)
    for key: String in groups:
        var nodes: Array=groups[key]
        if nodes.size()<2: continue
        var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        var triangles := 0
        for source: MultiMeshInstance3D in nodes:
            var mesh := source.multimesh.mesh
            var unit_triangles := mesh.get_faces().size()/3
            for i in range(source.multimesh.instance_count):
                surface.append_from(mesh,0,source.transform*source.multimesh.get_instance_transform(i))
                triangles+=unit_triangles
        surface.index()
        var combined := MeshInstance3D.new()
        combined.name="ParkFixture_"+key
        combined.mesh=surface.commit()
        combined.material_override=nodes[0].material_override
        combined.visibility_range_end=76.0
        combined.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        combined.set_meta("original_triangles",triangles)
        scenery_root.add_child(combined)
        for source: MultiMeshInstance3D in nodes:
            source.visible=false
            source.queue_free()

func _setup_atmosphere() -> void:
    var world := get_parent().get_node("WorldEnvironment") as WorldEnvironment
    var env := world.environment
    env.ambient_light_color = Color(0.40, 0.51, 0.68)
    env.ambient_light_energy = 0.48
    env.background_energy_multiplier = 0.45
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_light_color = FOG_COLOR
    env.fog_depth_begin = 12.0
    env.fog_depth_end = 52.0
    env.fog_depth_curve = 1.25
    env.fog_sky_affect = 0.0
    env.glow_enabled = true
    env.glow_bloom = 0.08
    env.glow_intensity = 0.75
    env.glow_hdr_threshold = 1.0
    var sky_material := env.sky.sky_material as ShaderMaterial
    if sky_material:
        sky_material.set_shader_parameter("moon_tex",preload("res://assets/moon.png"))
        # source_color uniforms need a Color Variant for Forward+ to convert
        # their authored sRGB values to linear light. Vector3 bypasses it.
        sky_material.set_shader_parameter("fog_color", FOG_COLOR)
        sky_material.set_shader_parameter("horizon", 0.35)
        sky_material.set_shader_parameter("blend_width", 0.38)
    var moon := get_parent().get_node("MoonLight") as DirectionalLight3D
    moon.light_color = Color(0.63, 0.76, 1.0)
    moon.light_energy = 0.65
    moon.rotation_degrees = Vector3(-48.0,-32.0,0.0)
    moon.shadow_enabled = false

func _build_ground() -> void:
    var material := ShaderMaterial.new()
    material.shader = GROUND_SHADER
    material.set_shader_parameter("ground_tex", GROUND_TEXTURE)
    # Compatibility has eight local lights per object. Small ground patches
    # let every lantern light its own surroundings without a larger shader cap.
    var total := Vector2(LevelData.MAP_WIDTH*LevelData.CELL_SIZE+32.0,LevelData.MAP_HEIGHT*LevelData.CELL_SIZE+32.0)
    var chunks := Vector2i(ceili(total.x/12.0),ceili(total.y/12.0))
    var patch := PlaneMesh.new()
    patch.size=total/Vector2(chunks)
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
    # A continuous gravel ribbon leads through reveals and forks.
    var cells := LevelData.PATH_CELLS
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var distance := 0.0
    for i in range(cells.size()):
        var p := LevelData.cell_center_world(cells[i])
        var prev := LevelData.cell_center_world(cells[maxi(0, i-1)])
        var next := LevelData.cell_center_world(cells[mini(cells.size()-1, i+1)])
        var side := (next-prev).normalized().cross(Vector3.UP) * 1.0
        if i > 0: distance += p.distance_to(prev)
        for sign_: float in [-1.0, 1.0]:
            vertices.append(p + side * sign_ + Vector3.UP * 0.018)
            normals.append(Vector3.UP)
            uv.append(Vector2((sign_+1.0)*0.5, distance * 0.24))
    var gravel := ShaderMaterial.new()
    gravel.shader=preload("res://shaders/level1_park_path.gdshader")
    gravel.set_shader_parameter("ground_tex",DETAIL_TEXTURE)
    var path_root := Node3D.new()
    path_root.name="WindingParkPath"
    scenery_root.add_child(path_root)
    # Keep identical shared edge vertices, but bound lighting to each section.
    for i in range(1,cells.size()):
        var section := []
        section.resize(Mesh.ARRAY_MAX)
        section[Mesh.ARRAY_VERTEX]=vertices.slice((i-1)*2,i*2+2)
        section[Mesh.ARRAY_NORMAL]=normals.slice((i-1)*2,i*2+2)
        section[Mesh.ARRAY_TEX_UV]=uv.slice((i-1)*2,i*2+2)
        section[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,1,2,3])
        var path_mesh := ArrayMesh.new()
        path_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,section)
        var path := MeshInstance3D.new()
        path.name="GravelSection_%02d"%i
        path.mesh=path_mesh
        path.material_override=gravel
        path.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        path_root.add_child(path)

func _walkable(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < LevelData.MAP_WIDTH and cell.y < LevelData.MAP_HEIGHT and LevelData.CANONICAL_MAP[cell.y][cell.x] == "."

func _build_hedges_and_forest() -> void:
    for z in range(LevelData.MAP_HEIGHT):
        for x in range(LevelData.MAP_WIDTH):
            var cell := Vector2i(x,z)
            if _walkable(cell) or LevelData.is_pond(cell): continue
            var p := LevelData.cell_center_world(cell)
            if (Vector2(cell)-Vector2(9,28)).length()<=1.0 or (Vector2(cell)-Vector2(38,27)).length()<=1.0: continue
            var exposed := false
            for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                if _walkable(cell+d): exposed = true
            var ruin := x >= 27 and x <= 43 and z <= 16 and z >= 4 and x != 24
            if exposed:
                opaque_walls.append(AABB(p+Vector3(-.86,.02,-.86),Vector3(1.72,2.68 if ruin else 2.38,1.72)))
                if ruin:
                    var wall_id := "wall_4"
                    if x==29 or (z==12 and x<=33): wall_id="wall_1"
                    elif x>=40 and z>=9: wall_id="wall_2"
                    elif z>=15: wall_id="wall_0"
                    _batch("box",wall_id,p+Vector3.UP*1.4,Vector3(1.8,2.8,1.8))
                    _batch("box","stone_dark",p+Vector3.UP*0.12,Vector3(1.84,0.24,1.84))
                    _batch("box","stone",p+Vector3.UP*2.78,Vector3(1.86,0.16,1.86))
                    _batch("ball","hedge",p+Vector3(0,3.16,0),Vector3(1.7,0.42,1.7))
                else:
                    _batch("box","outer_wall",p+Vector3.UP*1.25,Vector3(1.8,2.5,1.8))
                    _batch("box","outer_wall_cap",p+Vector3.UP*2.49,Vector3(1.8,0.16,1.8))
                    var crown_height := 1.1+rng.randf()*0.4
                    # The lowest leaf is above the masonry cap, even after
                    # the foliage shader's 0.075 m vertex displacement.
                    _batch("ball","leaf",p+Vector3(0,2.70+crown_height*.5,0),Vector3(2.1,crown_height,2.1))
            if (x+z*3)%7 == 0 and not ruin:
                _tree(p, rng.randf_range(4.8,7.8), false)
    # Deep silhouettes stand outside the collision border, above the hedge.
    for i in range(54):
        var p := Vector3.ZERO
        if i%2 == 0:
            p = Vector3(rng.randf_range(-52,52),0,-36 if i%4==0 else 36)
        else:
            p = Vector3(-48 if i%4==1 else 48,0,rng.randf_range(-34,34))
        _tree(p,rng.randf_range(7.0,11.0),false,true)

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
    add_child(label)

func _build_landmarks() -> void:
    _tree(LevelData.cell_center_world(Vector2i(9,28)),8.5,false)
    _tree(LevelData.cell_center_world(Vector2i(38,27)),13.0,true)
    _sign(LevelData.cell_center_world(Vector2i(5,27))+Vector3(-1.0,0,0),"ЛУННЫЙ ПАРК\nБелкам не верить")
    _sign(LevelData.cell_center_world(Vector2i(12,19))+Vector3(-2.0,0,0),"ЛУННЫЙ САД →")
    _sign(LevelData.cell_center_world(Vector2i(37,20))+Vector3(1.0,0,0),"ЛЕГЕНДАРНЫЙ ДУБ")
    for c in Props.LAMPS:
        _lamp(LevelData.cell_center_world(c))
    for bench in Props.BENCHES: _bench(Props.bench_position(bench),Props.bench_yaw(bench))
    var pond := Pond.new()
    pond.name="MoonGardenPond"
    scenery_root.add_child(pond)
    pond.build(self)
    # An eight-sided pavilion is the garden's distant orientation landmark.
    var gazebo := LevelData.cell_center_world(Vector2i(17,4))
    _batch("cylinder","stone_dark",gazebo+Vector3.UP*0.10,Vector3(5.8,0.20,5.8))
    for i in range(8):
        var a := float(i)*TAU/8.0
        _batch("cylinder","wood",gazebo+Vector3(cos(a)*2.4,2.2,sin(a)*2.4),Vector3(0.18,4.4,0.18))
    var roof := CylinderMesh.new()
    roof.top_radius = 0.3
    roof.bottom_radius = 3.3
    roof.height = 1.8
    roof.radial_segments = 8
    var roof_node := MeshInstance3D.new()
    roof_node.name = "GardenPavilionRoof"
    roof_node.mesh = roof
    roof_node.material_override = materials["iron"]
    roof_node.position = gazebo+Vector3.UP*5.1
    scenery_root.add_child(roof_node)
    _lamp(gazebo+Vector3.UP*0.20,3.0)
    # Broken courtyard arch, deliberately tall enough to see over the walls.
    var arch := LevelData.cell_center_world(Vector2i(34,5))
    for x: float in [-2.5,2.5]:
        _batch("box","wall_4",arch+Vector3(x,2.8,0),Vector3(0.9,5.6,0.9))
        _batch("box","stone_dark",arch+Vector3(x,0.15,0),Vector3(1.08,0.30,1.08))
        _batch("box","stone",arch+Vector3(x,5.25,0),Vector3(1.06,0.23,1.06))
    _batch("box","wall_2",arch+Vector3(0,5.4,0),Vector3(6.1,0.75,1.0))
    _batch("ball","hedge",arch+Vector3(-1.8,5.8,0),Vector3(2.7,0.5,1.3))
    _build_path_arch()
    # Lamps hanging from the legendary crown, visible before the final gate.
    var oak := LevelData.cell_center_world(Vector2i(38,27))
    materials["lantern_rope"] = _material(Color(0.58,0.43,0.26),0.22)
    for i in range(trees.legendary_hangers.size()):
        var anchor: Vector3 = trees.legendary_hangers[i]
        var p := Vector3(anchor.x,3.8+sin(i*2.0)*0.4,anchor.z)
        var top := p+Vector3.UP*0.29
        # The rope ends inside the actual generated branch, including its yaw.
        _batch("cylinder","lantern_rope",(anchor+top)*0.5,Vector3(0.065,anchor.y-top.y,0.065))
        _batch("ball","brass",anchor,Vector3(0.19,0.19,0.19))
        _batch("box","lamp",p,Vector3(0.19,0.30,0.19))
        for y: float in [-0.20,0.20]:
            _batch("box","brass",p+Vector3.UP*y,Vector3(0.34,0.075,0.34))
        for x: float in [-0.13,0.13]:
            for z: float in [-0.13,0.13]:
                _batch("box","iron",p+Vector3(x,0,z),Vector3(0.035,0.40,0.035))
        _batch("cylinder","brass",top,Vector3(0.11,0.16,0.11))

func _build_path_arch() -> void:
    var center := (LevelData.cell_center_world(Vector2i(29,8))+LevelData.cell_center_world(Vector2i(29,9)))*0.5
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # A real semicircular opening across Z, with 1.8 m masonry depth along X.
    for i in range(12):
        var a := float(i)*PI/12.0
        var b := float(i+1)*PI/12.0
        var ring: Array[Vector3] = []
        for x: float in [-0.9,0.9]:
            for pair: Vector2 in [Vector2(a,1.8),Vector2(b,1.8),Vector2(b,2.12),Vector2(a,2.12)]:
                ring.append(center+Vector3(x,2.25+sin(pair.x)*pair.y,cos(pair.x)*pair.y))
        for face in [[0,1,2,3],[7,6,5,4],[4,5,1,0],[3,2,6,7],[0,3,7,4],[1,5,6,2]]:
            for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
                st.add_vertex(ring[index])
    st.generate_normals()
    st.index()
    var node := MeshInstance3D.new()
    node.name = "CourtyardPathArch"
    node.mesh = st.commit()
    node.material_override = materials["wall_1"]
    node.ignore_occlusion_culling = true
    scenery_root.add_child(node)
    node.create_trimesh_collision()
    for side: float in [-1,1]:
        _batch("box","wall_1",center+Vector3(0,1.125,side*1.96),Vector3(1.8,2.25,0.32))
        _batch("box","stone",center+Vector3(0,2.25,side*1.97),Vector3(1.9,0.16,0.38))

func _build_gates() -> void:
    for gate in get_tree().get_nodes_in_group("level1_door"):
        var leaf := gate.get_node("Pivot/Leaf") as Node3D
        for i in range(7):
            var bar := MeshInstance3D.new()
            bar.mesh = meshes["box"]
            bar.material_override = materials["iron"]
            bar.position = Vector3(0,0,-0.78+i*0.26)
            bar.scale = Vector3(0.065,2.55,0.065)
            leaf.add_child(bar)
        for y: float in [-0.8,0.65,1.25]:
            var rail := MeshInstance3D.new()
            rail.mesh = meshes["box"]
            rail.material_override = materials["brass"]
            rail.position = Vector3(0,y,0)
            rail.scale = Vector3(0.12,0.10,1.85)
            leaf.add_child(rail)
        var b: Basis = gate.global_basis
        var wall_id: String = ["wall_0","wall_1","wall_3"][gate.required_key-1]
        for z: float in [-1.15,1.15]:
            _batch("box",wall_id,gate.global_position+b*Vector3(0,1.6,z),Vector3(0.7,3.2,0.7),b)
            _batch("box","stone",gate.global_position+b*Vector3(0,3.12,z),Vector3(0.87,0.22,0.87),b)
            _batch("ball","lamp",gate.global_position+b*Vector3(0,3.3,z),Vector3(0.23,0.23,0.23))

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
    for item in get_tree().get_nodes_in_group("level1_trap"):
        item.get_node("Visual").visible = false
        var pine := Node3D.new()
        item.add_child(pine)
        for i in range(5):
            _part(pine,"ball","bark",Vector3(0,i*0.10,0),Vector3(0.40-i*0.05,0.16,0.40-i*0.05))

func _build_fireflies() -> void:
    fireflies=Fireflies.build(self)

func _process(delta: float) -> void:
    clock += delta
    for i in range(ornaments.size()):
        var n := ornaments[i]
        if is_instance_valid(n):
            n.rotation.y += delta*0.65
            n.position.y = 0.22+sin(clock*1.8+i)*0.10
