extends Node3D
class_name Level2Oka3DStage

const OKA_MODEL_PATH := "res://compact+car+3d+model.glb"
const VIEWPORT_SIZE := Vector2i(256, 256)
const OKA_DESIRED_LENGTH := 3.2

var viewport: SubViewport
var world_root: Node3D
var model_pivot: Node3D
var model_instance: Node3D
var camera: Camera3D
var model_ready := false
var bound_movement: Node = null

func _ready() -> void:
    _build_stage()

func _build_stage() -> void:
    viewport = SubViewport.new()
    viewport.name = "OkaViewport"
    viewport.size = VIEWPORT_SIZE
    viewport.disable_3d = false
    viewport.transparent_bg = true
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_DISABLED
    add_child(viewport)

    world_root = Node3D.new()
    world_root.name = "OkaWorld"
    viewport.add_child(world_root)

    var environment_node := WorldEnvironment.new()
    environment_node.name = "OkaEnvironment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.76, 0.84, 1.0)
    environment.ambient_light_energy = 1.25
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    environment_node.environment = environment
    world_root.add_child(environment_node)

    model_pivot = Node3D.new()
    model_pivot.name = "OkaPivot"
    world_root.add_child(model_pivot)

    var packed := load(OKA_MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Level2 Oka] Failed to load %s" % OKA_MODEL_PATH)
        return

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 Oka] GLB root is not Node3D")
        return
    model_instance.name = "OkaModel"
    model_pivot.add_child(model_instance)

    _prepare_materials()

    var key_light := DirectionalLight3D.new()
    key_light.name = "KeyLight"
    key_light.rotation_degrees = Vector3(-32.0, -35.0, 0.0)
    key_light.light_energy = 1.5
    key_light.shadow_enabled = false
    world_root.add_child(key_light)

    var fill_light := DirectionalLight3D.new()
    fill_light.name = "FillLight"
    fill_light.rotation_degrees = Vector3(-12.0, 145.0, 0.0)
    fill_light.light_energy = 0.55
    fill_light.shadow_enabled = false
    world_root.add_child(fill_light)

    camera = Camera3D.new()
    camera.name = "OkaCamera"
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 34.0
    camera.near = 0.02
    camera.far = 30.0
    camera.current = true
    camera.position = Vector3(0.0, 0.95, 4.05)
    world_root.add_child(camera)

    await get_tree().process_frame
    _fit_model()
    model_ready = true

func _prepare_materials() -> void:
    if model_instance == null:
        return

    for node in model_instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue

        for surface in range(mesh_node.mesh.get_surface_count()):
            var source := mesh_node.get_active_material(surface)
            if source is StandardMaterial3D:
                var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                material.metallic = 0.0
                material.roughness = 0.82
                material.cull_mode = BaseMaterial3D.CULL_BACK
                material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
                mesh_node.set_surface_override_material(surface, material)

func _fit_model() -> void:
    if model_instance == null or camera == null:
        return

    var meshes := model_instance.find_children("*", "MeshInstance3D", true, false)
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
            Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
        ]:
            var point: Vector3 = mesh_to_root * corner
            if not has_bounds:
                bounds = AABB(point, Vector3.ZERO)
                has_bounds = true
            else:
                bounds = bounds.expand(point)

    if not has_bounds:
        return

    var longitudinal := maxf(bounds.size.x, bounds.size.z)
    longitudinal = maxf(longitudinal, 0.001)
    var scale_factor := OKA_DESIRED_LENGTH / longitudinal

    model_instance.scale = Vector3.ONE * scale_factor
    var scaled_center := bounds.get_center() * scale_factor
    model_instance.position = Vector3(
        -scaled_center.x,
        -scaled_center.y + 0.38,
        -scaled_center.z
    )

    camera.position = Vector3(0.0, 0.92, 4.15)
    camera.look_at(Vector3(0.0, 0.48, 0.0), Vector3.UP)

func bind_player(movement: Node) -> void:
    bound_movement = movement

func sync_from_movement(movement: Node) -> void:
    if not model_ready or movement == null or model_pivot == null:
        return

    var steer := clampf(float(movement.get("steer_in")), -1.0, 1.0)
    var speed := maxf(float(movement.get("speed")), 0.0)
    var max_speed := 32.0
    var track_yaw := 0.0
    if movement.has_method("get_render_track_yaw"):
        track_yaw = float(movement.get_render_track_yaw())

    model_pivot.rotation = Vector3(
        -clampf(speed / max_speed, 0.0, 1.0) * deg_to_rad(1.5),
        track_yaw * 0.30 + steer * deg_to_rad(10.0),
        -steer * deg_to_rad(4.0)
    )

func get_view_texture() -> Texture2D:
    if viewport == null:
        return null
    return viewport.get_texture()

func is_model_ready() -> bool:
    return model_ready and model_instance != null and camera != null
