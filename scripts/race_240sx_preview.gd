extends Node3D
class_name Race240SXPreview

const CAR_MODEL_PATH := "res://240_sx_nfs_pro_street.glb"
const DESIRED_LENGTH := 3.85
const MODEL_AUTHORED_FORWARD_YAW := PI
const CAMERA_POSITION := Vector3(0.95, 1.25, 7.1)
const CAMERA_TARGET := Vector3(0.0, 0.62, 0.0)

var model_root: Node3D = null
var model_instance: Node3D = null
var camera: Camera3D = null
var model_ready := false
var current_steer := 0.0

func _ready() -> void:
    var viewport := get_parent() as SubViewport
    if viewport == null:
        push_error("[Level2 240SX] Preview root must be inside a SubViewport.")
        return

    viewport.world_3d = World3D.new()
    viewport.transparent_bg = true
    viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    _build_world()
    _build_model()

func _build_world() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.78, 0.90, 1.0)
    environment.ambient_light_energy = 1.15
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    var world_environment := WorldEnvironment.new()
    world_environment.name = "Environment"
    world_environment.environment = environment
    add_child(world_environment)

    var key := DirectionalLight3D.new()
    key.name = "KeyLight"
    key.rotation_degrees = Vector3(-28.0, -35.0, 0.0)
    key.light_energy = 1.7
    key.shadow_enabled = false
    add_child(key)

    var fill := DirectionalLight3D.new()
    fill.name = "FillLight"
    fill.rotation_degrees = Vector3(18.0, 150.0, 0.0)
    fill.light_energy = 0.55
    fill.shadow_enabled = false
    add_child(fill)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 5.0
    camera.near = 0.05
    camera.far = 100.0
    camera.position = CAMERA_POSITION
    add_child(camera)
    camera.look_at_from_position(camera.position, CAMERA_TARGET, Vector3.UP)
    camera.make_current()

func _build_model() -> void:
    var packed := load(CAR_MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Level2 240SX] Failed to load %s" % CAR_MODEL_PATH)
        return

    model_root = Node3D.new()
    model_root.name = "240SXRoot"
    add_child(model_root)

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 240SX] GLB root is not Node3D")
        model_root.queue_free()
        model_root = null
        return

    model_instance.name = "240SX"
    model_root.add_child(model_instance)
    model_instance.rotation.y = MODEL_AUTHORED_FORWARD_YAW

    _prepare_materials()

    var bounds := _calculate_bounds()
    if bounds.size.length_squared() <= 0.0001:
        push_error("[Level2 240SX] Could not calculate model bounds")
        return

    var longitudinal := maxf(bounds.size.x, bounds.size.z)
    var scale_factor := DESIRED_LENGTH / maxf(longitudinal, 0.001)
    model_instance.scale = Vector3.ONE * scale_factor

    var scaled_center := bounds.get_center() * scale_factor
    model_instance.position = Vector3(
        -scaled_center.x,
        -scaled_center.y + 0.06,
        -scaled_center.z
    )

    model_ready = true

func _calculate_bounds() -> AABB:
    if model_instance == null:
        return AABB()

    var meshes := model_instance.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    )
    var bounds := AABB()
    var has_bounds := false
    var inv_root := model_instance.global_transform.affine_inverse()

    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        var aabb := mesh_node.get_aabb()
        var mesh_to_root := inv_root * mesh_node.global_transform

        for corner in [
            Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.end.z)
        ]:
            var point: Vector3 = mesh_to_root * corner
            if not has_bounds:
                bounds = AABB(point, Vector3.ZERO)
                has_bounds = true
            else:
                bounds = bounds.expand(point)

    return bounds

func _prepare_materials() -> void:
    if model_instance == null:
        return

    for node in model_instance.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    ):
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        for surface in range(mesh_node.mesh.get_surface_count()):
            var source := mesh_node.get_active_material(surface)
            if source is StandardMaterial3D:
                var material := (
                    source as StandardMaterial3D
                ).duplicate() as StandardMaterial3D
                material.metallic = minf(material.metallic, 0.2)
                material.roughness = maxf(material.roughness, 0.68)
                material.cull_mode = BaseMaterial3D.CULL_BACK
                mesh_node.set_surface_override_material(surface, material)

func sync_from_race_car(race_car) -> void:
    if model_root == null or race_car == null:
        return

    current_steer = clampf(float(race_car.steer_in), -1.0, 1.0)

    # RaceCarController owns the authoritative lane/world position. The
    # pseudo-3D renderer owns screen projection; this preview mirrors the
    # controller's steering only, while its screen position is projected from
    # world_x in _draw_player_car().
    model_root.rotation.y = (
        MODEL_AUTHORED_FORWARD_YAW
        + current_steer * 0.10
    )
    model_root.rotation.z = -current_steer * 0.035

func is_model_ready() -> bool:
    return model_ready
