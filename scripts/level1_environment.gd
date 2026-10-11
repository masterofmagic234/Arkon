extends Node3D
class_name Level1Environment

# Presentation for the authored park. Gameplay geometry remains in the layout
# scene, and every decorative batch is bounded to a spatial chunk for culling.
const LevelData = preload("res://scripts/level_data.gd")
const GROUND_TEXTURE = preload("res://assets/level1/park_ground.png")
const GROUND_SHADER = preload("res://shaders/level1_park_ground.gdshader")
const WATER_SHADER = preload("res://shaders/level1_park_water.gdshader")
const FOG_COLOR := Color(0.065, 0.10, 0.155)

var materials: Dictionary = {}
var meshes: Dictionary = {}
var batches: Dictionary = {}
var rng := RandomNumberGenerator.new()
var ornaments: Array[Node3D] = []
var fireflies: MultiMeshInstance3D
var clock := 0.0
var park_ready := false
var scenery_root: Node3D

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
    _build_gates()
    _build_pickups()
    _flush_batches()
    _build_fireflies()
    _build_secret()
    var grass := preload("res://scripts/level1_grass_generator.gd").new()
    grass.name = "Level1GrassGenerator"
    grass.density_per_cell = 3
    grass.chunk_cells_x = 12
    grass.chunk_cells_z = 12
    grass.visibility_end = 48.0
    grass.wind_strength = 0.025
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
        mat.set_shader_parameter("leaf_tex",GROUND_TEXTURE)
        mat.set_shader_parameter("tint",Vector3(previous.albedo_color.r,previous.albedo_color.g,previous.albedo_color.b))
        materials[id] = mat

func _batch(shape: String, material: String, position_: Vector3, size_: Vector3, basis_ := Basis.IDENTITY) -> void:
    var key := "%s|%s|%d|%d" % [shape, material, int(floor(position_.x / 16.0)), int(floor(position_.z / 16.0))]
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
        node.material_override = materials[parts[1]]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.visibility_range_end = 76.0
        scenery_root.add_child(node)
    batches.clear()

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
        sky_material.set_shader_parameter("fog_color", Vector3(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b))
        sky_material.set_shader_parameter("horizon", 0.35)
        sky_material.set_shader_parameter("blend_width", 0.38)
    var moon := get_parent().get_node("MoonLight") as DirectionalLight3D
    moon.light_color = Color(0.63, 0.76, 1.0)
    moon.light_energy = 0.65
    moon.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    moon.shadow_enabled = false

func _build_ground() -> void:
    var material := ShaderMaterial.new()
    material.shader = GROUND_SHADER
    material.set_shader_parameter("ground_tex", GROUND_TEXTURE)
    var plane := PlaneMesh.new()
    plane.size = Vector2(LevelData.MAP_WIDTH * LevelData.CELL_SIZE + 32.0, LevelData.MAP_HEIGHT * LevelData.CELL_SIZE + 32.0)
    var ground := MeshInstance3D.new()
    ground.name = "ParkGround"
    ground.mesh = plane
    ground.material_override = material
    ground.position = Vector3.ZERO
    scenery_root.add_child(ground)
    # A continuous gravel ribbon leads through reveals and forks.
    var cells := LevelData.PATH_CELLS
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var indices := PackedInt32Array()
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
        if i > 0:
            var a := (i-1)*2
            indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_INDEX] = indices
    var path_mesh := ArrayMesh.new()
    path_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var path := MeshInstance3D.new()
    path.name = "WindingParkPath"
    path.mesh = path_mesh
    var gravel := _material(Color(0.42, 0.37, 0.28))
    gravel.albedo_texture = GROUND_TEXTURE
    path.material_override = gravel
    scenery_root.add_child(path)

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
                if ruin:
                    _batch("box","stone_dark",p+Vector3.UP*1.4,Vector3(1.8,2.8,1.8))
                    for y in range(4):
                        _batch("box","stone",p+Vector3(0,0.38+y*0.65,0),Vector3(1.84,0.58,1.84))
                    _batch("ball","hedge",p+Vector3(0,2.9,0),Vector3(1.7,0.4,1.7))
                else:
                    _batch("box","hedge",p+Vector3.UP*1.25,Vector3(1.8,2.5,1.8))
                    _batch("ball","leaf",p+Vector3(0,2.5,0),Vector3(2.1,1.1+rng.randf()*0.4,2.1))
            if (x+z*3)%7 == 0 and not ruin:
                _tree(p, rng.randf_range(4.8,7.8), false)
    # Deep silhouettes stand outside the collision border, above the hedge.
    for i in range(54):
        var p := Vector3.ZERO
        if i%2 == 0:
            p = Vector3(rng.randf_range(-52,52),0,-36 if i%4==0 else 36)
        else:
            p = Vector3(-48 if i%4==1 else 48,0,rng.randf_range(-34,34))
        _tree(p,rng.randf_range(7.0,11.0),false)

func _branch(a: Vector3, b: Vector3, width: float) -> void:
    _batch("trunk","bark",(a+b)*0.5,Vector3(width,a.distance_to(b),width),Basis(Quaternion(Vector3.UP,(b-a).normalized())))

func _tree(p: Vector3, height: float, legendary: bool) -> void:
    var w := height * (0.17 if legendary else 0.12)
    var bend := p+Vector3(height*0.05,height*0.38,0)
    _branch(p,bend,w)
    _branch(bend,p+Vector3(-height*0.06,height*0.72,0),w*0.72)
    _batch("cylinder","shadow",p+Vector3.UP*0.009,Vector3(w*2.0,0.01,w*2.0))
    for i in range(7 if legendary else 4):
        var angle := float(i)*TAU/float(7 if legendary else 4)+0.4
        var branch_end := p+Vector3(cos(angle)*height*0.29,height*(0.62+rng.randf()*0.15),sin(angle)*height*0.29)
        _branch(bend+Vector3.UP*height*0.15,branch_end,w*0.38)
        var crown := Vector3(height*0.53,height*0.38,height*0.53)
        _batch("ball","gold_leaf" if legendary else ("leaf_light" if i%2==0 else "leaf"),branch_end+Vector3.UP*height*0.07,crown)
    _batch("ball","gold_leaf" if legendary else "leaf",p+Vector3.UP*height*0.92,Vector3(height*0.58,height*0.38,height*0.58))
    if legendary:
        for i in range(6):
            var a := float(i)*TAU/6.0
            _branch(p+Vector3.UP*0.9,p+Vector3(cos(a)*2.0,0.05,sin(a)*2.0),0.7)

func _lamp(p: Vector3, height: float = 3.4) -> void:
    _batch("cylinder","iron",p+Vector3.UP*height*0.48,Vector3(0.14,height*0.96,0.14))
    _batch("cylinder","brass",p+Vector3.UP*0.12,Vector3(0.45,0.24,0.45))
    _batch("box","lamp",p+Vector3.UP*height,Vector3(0.28,0.45,0.28))
    for offset in [Vector3(-0.2,0,-0.2),Vector3(0.2,0,-0.2),Vector3(-0.2,0,0.2),Vector3(0.2,0,0.2)]:
        _batch("box","iron",p+Vector3.UP*height+offset,Vector3(0.04,0.64,0.04))
    _batch("box","iron",p+Vector3.UP*(height+0.35),Vector3(0.55,0.12,0.55))
    _batch("box","iron",p+Vector3.UP*(height-0.34),Vector3(0.46,0.10,0.46))
    var light := OmniLight3D.new()
    light.position = p+Vector3.UP*(height-0.1)
    light.light_color = Color(1.0,0.69,0.36)
    light.light_energy = 2.7
    light.omni_range = 7.8
    light.omni_attenuation = 1.45
    light.shadow_enabled = false
    add_child(light)

func _bench(p: Vector3, yaw: float) -> void:
    var basis_ := Basis(Vector3.UP,yaw)
    for i in range(3):
        _batch("box","wood",p+basis_*Vector3(0,0.6,(i-1)*0.19),Vector3(2.0,0.1,0.16),basis_)
        _batch("box","wood",p+basis_*Vector3(0,0.9+i*0.18,0.3),Vector3(2.0,0.13,0.09),basis_)
    for x: float in [-0.75,0.75]:
        _batch("box","iron",p+basis_*Vector3(x,0.3,0),Vector3(0.1,0.6,0.5),basis_)

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
    for c in [Vector2i(4,29),Vector2i(11,26),Vector2i(21,23),Vector2i(13,19),Vector2i(14,13),Vector2i(19,4),Vector2i(22,8),Vector2i(27,7),Vector2i(34,13),Vector2i(43,15),Vector2i(37,20),Vector2i(41,26),Vector2i(43,30)]:
        _lamp(LevelData.cell_center_world(c))
    _bench(LevelData.cell_center_world(Vector2i(7,31)),PI)
    _bench(LevelData.cell_center_world(Vector2i(18,4)),0.0)
    _bench(LevelData.cell_center_world(Vector2i(44,28)),-PI*0.5)
    # Moon garden pond: rounded shore, water ripples, individual bank stones.
    var pond_pos := LevelData.cell_center_world(Vector2i(10,9))+Vector3(0.9,0.035,0.9)
    var pond_mesh := CylinderMesh.new()
    pond_mesh.top_radius = 6.85
    pond_mesh.bottom_radius = 6.85
    pond_mesh.height = 0.025
    pond_mesh.radial_segments = 48
    var water := MeshInstance3D.new()
    water.name = "MoonGardenPond"
    water.mesh = pond_mesh
    var water_mat := ShaderMaterial.new()
    water_mat.shader = WATER_SHADER
    water.material_override = water_mat
    water.position = pond_pos
    scenery_root.add_child(water)
    for i in range(46):
        var a := float(i)*TAU/46.0
        var p := pond_pos+Vector3(cos(a)*7.0,0.04,sin(a)*7.0)
        _batch("ball","stone_dark",p,Vector3(rng.randf_range(0.5,1.2),rng.randf_range(0.24,0.48),rng.randf_range(0.5,1.0)))
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
    _lamp(gazebo,3.0)
    # Broken courtyard arch, deliberately tall enough to see over the walls.
    var arch := LevelData.cell_center_world(Vector2i(34,5))
    for x: float in [-2.5,2.5]:
        _batch("box","stone",arch+Vector3(x,2.8,0),Vector3(0.9,5.6,0.9))
    _batch("box","stone",arch+Vector3(0,5.4,0),Vector3(6.1,0.75,1.0))
    _batch("ball","hedge",arch+Vector3(-1.8,5.8,0),Vector3(2.7,0.5,1.3))
    # Lamps hanging from the legendary crown, visible before the final gate.
    var oak := LevelData.cell_center_world(Vector2i(38,27))
    for i in range(7):
        var a := i*TAU/7.0
        var p := oak+Vector3(cos(a)*3.0,3.8+sin(i*2.0)*0.4,sin(a)*3.0)
        _batch("box","lamp",p,Vector3(0.18,0.3,0.18))
        _batch("cylinder","iron",p+Vector3.UP*0.7,Vector3(0.02,1.4,0.02))

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
        for z: float in [-1.15,1.15]:
            _batch("box","stone",gate.global_position+b*Vector3(0,1.6,z),Vector3(0.7,3.2,0.7),b)
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
            item.add_child(pedestal)
            _part(pedestal,"cylinder","stone_dark",Vector3(0,-item.position.y+0.12,0),Vector3(0.95,0.24,0.95))
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
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = meshes["ball"]
    mm.instance_count = 56
    for i in range(mm.instance_count):
        var cell := Vector2i(rng.randi_range(3,44),rng.randi_range(3,32))
        var p := LevelData.cell_center_world(cell)+Vector3(0,rng.randf_range(0.8,2.7),0)
        mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.045),p))
    fireflies = MultiMeshInstance3D.new()
    fireflies.name = "ParkFireflies"
    fireflies.multimesh = mm
    fireflies.material_override = materials["lamp"]
    fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(fireflies)

func _process(delta: float) -> void:
    clock += delta
    for i in range(ornaments.size()):
        var n := ornaments[i]
        if is_instance_valid(n):
            n.rotation.y += delta*0.65
            n.position.y = 0.22+sin(clock*1.8+i)*0.10
    if fireflies:
        fireflies.position = Vector3(sin(clock*0.32)*0.7,sin(clock*0.61)*0.18,cos(clock*0.24)*0.5)
