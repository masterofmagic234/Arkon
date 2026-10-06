extends Control
class_name Race240SXOverlay

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const CAR_MODEL_PATH := "res://240_sx_nfs_pro_street.glb"
const DESIRED_LENGTH := 6.2
const MODEL_AUTHORED_FORWARD_YAW := 0.0

@onready var viewport: SubViewport = $Car3DViewport
@onready var world_root: Node3D = $Car3DViewport/Car3DWorld

var model_root: Node3D = null
var model_instance: Node3D = null
var camera: Camera3D = null
var ready_3d := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    call_deferred("_build_preview")

func _build_preview() -> void:
    if viewport == null or world_root == null:
        return

    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    viewport.transparent_bg = true
    viewport.world_3d = World3D.new()

    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.78, 0.92, 1.0)
    environment.ambient_light_energy = 1.2
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    var world_environment := WorldEnvironment.new()
    world_environment.name = "Environment"
    world_environment.environment = environment
    world_root.add_child(world_environment)

    var key := DirectionalLight3D.new()
    key.name = "KeyLight"
    key.rotation_degrees = Vector3(-25.0, -30.0, 0.0)
    key.light_energy = 1.8
    key.shadow_enabled = false
    world_root.add_child(key)

    var fill := DirectionalLight3D.new()
    fill.name = "FillLight"
    fill.rotation_degrees = Vector3(18.0, 140.0, 0.0)
    fill.light_energy = 0.65
    fill.shadow_enabled = false
    world_root.add_child(fill)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 30.0
    camera.near = 0.05
    camera.far = 100.0
    camera.position = Vector3(0.0, 1.15, 4.8)
    world_root.add_child(camera)
    camera.look_at_from_position(
        camera.position,
        Vector3(0.0, 0.60, 0.0),
        Vector3.UP
    )
    camera.make_current()

    var packed := load(CAR_MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Level2 240SX] Failed to load %s" % CAR_MODEL_PATH)
        return

    model_root = Node3D.new()
    model_root.name = "240SXRoot"
    world_root.add_child(model_root)

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 240SX] GLB root is not Node3D")
        return

    model_instance.name = "240SX"
    model_root.add_child(model_instance)
    model_instance.rotation.y = MODEL_AUTHORED_FORWARD_YAW

    _prepare_materials()

    var bounds := _calculate_bounds()
    var longitudinal := maxf(bounds.size.x, bounds.size.z)
    if longitudinal < 0.01:
        push_error("[Level2 240SX] Invalid model bounds")
        return

    var scale_factor := DESIRED_LENGTH / longitudinal
    model_instance.scale = Vector3.ONE * scale_factor

    var scaled_center := bounds.get_center() * scale_factor
    model_instance.position = Vector3(
        -scaled_center.x,
        -scaled_center.y + 0.08,
        -scaled_center.z
    )

    ready_3d = true
    visible = true
    queue_redraw()

func _calculate_bounds() -> AABB:
    if model_instance == null:
        return AABB()

    var bounds := AABB()
    var has_bounds := false
    var inv_root := model_instance.global_transform.affine_inverse()

    for node in model_instance.find_children(
        "*",
        "MeshInstance3D",
        true,
        false
    ):
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
                material.metallic = minf(material.metallic, 0.18)
                material.roughness = maxf(material.roughness, 0.68)
                material.cull_mode = BaseMaterial3D.CULL_BACK
                material.texture_filter = (
                    BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
                )
                mesh_node.set_surface_override_material(
                    surface,
                    material
                )

func sync_from_race_car(
        race_car,
        track_x: PackedFloat32Array,
        viewport_size: Vector2
) -> void:
    if race_car == null or track_x.is_empty() or viewport_size.x <= 1.0:
        visible = false
        return

    var center := float(track_x[
        clampi(
            race_car.segment_index,
            0,
            track_x.size() - 1
        )
    ])
    var half_road := RaceLevelData.ROAD_WIDTH * 0.5
    var lateral := 0.0
    if half_road > 0.0:
        lateral = clampf(
            (race_car.world_x - center) / half_road,
            -1.0,
            1.0
        )

    var playfield_height := viewport_size.y * (
        496.0 / 720.0
    )
    var car_width := clampf(
        viewport_size.x * 0.24,
        170.0,
        340.0
    )
    var car_height := car_width * 0.52

    position = Vector2(
        viewport_size.x * 0.5
        + lateral * viewport_size.x * 0.10
        - car_width * 0.5,
        playfield_height - car_height - 2.0
    )
    size = Vector2(car_width, car_height)

    var steer := clampf(float(race_car.steer_in), -1.0, 1.0)
    if model_root != null:
        model_root.rotation.y = (
            MODEL_AUTHORED_FORWARD_YAW
            + steer * 0.10
        )
        model_root.rotation.z = -steer * 0.035

    visible = ready_3d

func is_model_ready() -> bool:
    return ready_3d
