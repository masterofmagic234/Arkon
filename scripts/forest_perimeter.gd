extends Node

const FENCE_X := 17.55
const FENCE_Z := 12.15
const FENCE_HEIGHT := 2.55
const POST_SPACING := 1.55
const FOREST_DEPTH := 9.0
const TREE_COUNT_PER_SIDE := 18

var fence_mat: StandardMaterial3D
var forest_mat: StandardMaterial3D
var tree_mat: StandardMaterial3D
var pine_mat: StandardMaterial3D

func _ready() -> void:
    get_tree().scene_changed.connect(_on_scene_changed)
    if get_tree().current_scene != null:
        _on_scene_changed(get_tree().current_scene)

func _on_scene_changed(scene: Node) -> void:
    if scene == null or scene.name != "Game":
        return
    await get_tree().process_frame
    await get_tree().process_frame
    if is_instance_valid(scene):
        _replace_old_walls(scene)
        _build_fence(scene)
        _build_forest(scene)

func _replace_old_walls(world: Node) -> void:
    for node in world.get_children():
        if node.name.begins_with("MapWall_"):
            if node.has_node("Mesh"):
                node.get_node("Mesh").visible = false
            if node.has_node("Collision"):
                node.get_node("Collision").disabled = true
            if node is CollisionObject3D:
                node.collision_layer = 0
                node.collision_mask = 0

func _make_material(color: Color, metallic := 0.0, roughness := 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _mesh_part(parent: Node3D, mesh: Mesh, pos: Vector3, name: String, rot_y := 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name
    mi.mesh = mesh
    mi.position = pos
    mi.rotation.y = rot_y
    parent.add_child(mi)
    return mi

func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = material
    return mesh

func _add_collision(parent: Node3D, pos: Vector3, size: Vector3, name: String, rot_y := 0.0) -> void:
    var body := StaticBody3D.new()
    body.name = name
    body.position = pos
    body.rotation.y = rot_y
    body.collision_layer = 1
    body.collision_mask = 0
    parent.add_child(body)

    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)

func _build_fence(world: Node3D) -> void:
    var root := Node3D.new()
    root.name = "ParkFence"
    world.add_child(root)

    fence_mat = _make_material(Color(0.055, 0.065, 0.07), 0.72, 0.48)

    var post_mesh := CylinderMesh.new()
    post_mesh.top_radius = 0.055
    post_mesh.bottom_radius = 0.07
    post_mesh.height = FENCE_HEIGHT
    post_mesh.radial_segments = 8
    post_mesh.material = fence_mat

    var rail_mesh_x := _box_mesh(Vector3(1.55, 0.09, 0.09), fence_mat)
    var rail_mesh_z := _box_mesh(Vector3(0.09, 0.09, 1.55), fence_mat)

    var spear_mesh := CylinderMesh.new()
    spear_mesh.top_radius = 0.0
    spear_mesh.bottom_radius = 0.075
    spear_mesh.height = 0.32
    spear_mesh.radial_segments = 6
    spear_mesh.material = fence_mat

    var x_positions := _positions(-FENCE_X, FENCE_X, POST_SPACING)
    var z_positions := _positions(-FENCE_Z, FENCE_Z, POST_SPACING)

    for x in x_positions:
        _mesh_part(root, post_mesh, Vector3(x, FENCE_HEIGHT * 0.5, -FENCE_Z), "Post_N_%s" % str(x))
        _mesh_part(root, post_mesh, Vector3(x, FENCE_HEIGHT * 0.5, FENCE_Z), "Post_S_%s" % str(x))
        _mesh_part(root, spear_mesh, Vector3(x, FENCE_HEIGHT + 0.16, -FENCE_Z), "Spear_N_%s" % str(x))
        _mesh_part(root, spear_mesh, Vector3(x, FENCE_HEIGHT + 0.16, FENCE_Z), "Spear_S_%s" % str(x))

    for z in z_positions:
        _mesh_part(root, post_mesh, Vector3(-FENCE_X, FENCE_HEIGHT * 0.5, z), "Post_W_%s" % str(z))
        _mesh_part(root, post_mesh, Vector3(FENCE_X, FENCE_HEIGHT * 0.5, z), "Post_E_%s" % str(z))
        _mesh_part(root, spear_mesh, Vector3(-FENCE_X, FENCE_HEIGHT + 0.16, z), "Spear_W_%s" % str(z))
        _mesh_part(root, spear_mesh, Vector3(FENCE_X, FENCE_HEIGHT + 0.16, z), "Spear_E_%s" % str(z))

    for x in _segment_centers(-FENCE_X, FENCE_X, POST_SPACING):
        _mesh_part(root, rail_mesh_x, Vector3(x, 0.78, -FENCE_Z), "Rail_N_L_%s" % str(x))
        _mesh_part(root, rail_mesh_x, Vector3(x, 1.72, -FENCE_Z), "Rail_N_U_%s" % str(x))
        _mesh_part(root, rail_mesh_x, Vector3(x, 0.78, FENCE_Z), "Rail_S_L_%s" % str(x))
        _mesh_part(root, rail_mesh_x, Vector3(x, 1.72, FENCE_Z), "Rail_S_U_%s" % str(x))
        _add_collision(root, Vector3(x, 1.25, -FENCE_Z), Vector3(POST_SPACING, 2.5, 0.13), "Collision_N_%s" % str(x))
        _add_collision(root, Vector3(x, 1.25, FENCE_Z), Vector3(POST_SPACING, 2.5, 0.13), "Collision_S_%s" % str(x))

    for z in _segment_centers(-FENCE_Z, FENCE_Z, POST_SPACING):
        _mesh_part(root, rail_mesh_z, Vector3(-FENCE_X, 0.78, z), "Rail_W_L_%s" % str(z))
        _mesh_part(root, rail_mesh_z, Vector3(-FENCE_X, 1.72, z), "Rail_W_U_%s" % str(z))
        _mesh_part(root, rail_mesh_z, Vector3(FENCE_X, 0.78, z), "Rail_E_L_%s" % str(z))
        _mesh_part(root, rail_mesh_z, Vector3(FENCE_X, 1.72, z), "Rail_E_U_%s" % str(z))
        _add_collision(root, Vector3(-FENCE_X, 1.25, z), Vector3(0.13, 2.5, POST_SPACING), "Collision_W_%s" % str(z))
        _add_collision(root, Vector3(FENCE_X, 1.25, z), Vector3(0.13, 2.5, POST_SPACING), "Collision_E_%s" % str(z))

func _positions(a: float, b: float, step: float) -> Array[float]:
    var result: Array[float] = []
    var p := a
    while p <= b + 0.01:
        result.append(p)
        p += step
    return result

func _segment_centers(a: float, b: float, step: float) -> Array[float]:
    var result: Array[float] = []
    var p := a + step * 0.5
    while p < b - 0.01:
        result.append(p)
        p += step
    return result

func _build_forest(world: Node3D) -> void:
    var root := Node3D.new()
    root.name = "ForestBeyondFence"
    world.add_child(root)

    forest_mat = _make_material(Color(0.025, 0.055, 0.03), 0.0, 1.0)
    var ground_mesh := BoxMesh.new()
    ground_mesh.size = Vector3(36.0, 0.12, FOREST_DEPTH)
    ground_mesh.material = forest_mat
    _mesh_part(root, ground_mesh, Vector3(0, -0.06, -FENCE_Z - FOREST_DEPTH * 0.5), "ForestGround_N")
    _mesh_part(root, ground_mesh, Vector3(0, -0.06, FENCE_Z + FOREST_DEPTH * 0.5), "ForestGround_S")

    var side_ground := BoxMesh.new()
    side_ground.size = Vector3(FOREST_DEPTH, 0.12, 25.0)
    side_ground.material = forest_mat
    _mesh_part(root, side_ground, Vector3(-FENCE_X - FOREST_DEPTH * 0.5, -0.06, 0), "ForestGround_W")
    _mesh_part(root, side_ground, Vector3(FENCE_X + FOREST_DEPTH * 0.5, -0.06, 0), "ForestGround_E")

    tree_mat = _tree_material("res://assets/oak_tree.png")
    pine_mat = _tree_material("res://assets/pine_tree.png")
    var rng := RandomNumberGenerator.new()
    rng.seed = 240916

    for i in TREE_COUNT_PER_SIDE:
        _add_tree(root, rng, Vector3(rng.randf_range(-17.0, 17.0), 0, rng.randf_range(-20.0, -14.0)), rng.randf_range(3.4, 5.2), false)
        _add_tree(root, rng, Vector3(rng.randf_range(-17.0, 17.0), 0, rng.randf_range(14.0, 20.0)), rng.randf_range(3.4, 5.2), i % 4 == 0)
        _add_tree(root, rng, Vector3(rng.randf_range(-23.0, -19.0), 0, rng.randf_range(-11.5, 11.5)), rng.randf_range(3.0, 4.8), i % 3 == 0)
        _add_tree(root, rng, Vector3(rng.randf_range(19.0, 23.0), 0, rng.randf_range(-11.5, 11.5)), rng.randf_range(3.0, 4.8), i % 3 == 0)

func _tree_material(path: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    m.alpha_scissor_threshold = 0.45
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.albedo_texture = load(path)
    m.roughness = 1.0
    return m

func _add_tree(root: Node3D, rng: RandomNumberGenerator, pos: Vector3, height: float, pine: bool) -> void:
    var mesh := QuadMesh.new()
    mesh.size = Vector2(height * 0.8, height)
    mesh.material = pine_mat if pine else tree_mat
    var tree := MeshInstance3D.new()
    tree.mesh = mesh
    tree.position = pos + Vector3(0, height * 0.5, 0)
    tree.rotation.y = rng.randf_range(0.0, TAU)
    tree.scale.x = rng.randf_range(0.82, 1.18)
    tree.scale.z = rng.randf_range(0.92, 1.08)
    root.add_child(tree)
