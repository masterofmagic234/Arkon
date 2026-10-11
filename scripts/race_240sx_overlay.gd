extends Control
class_name Race240SXOverlay

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const CAR_MODEL_PATH := "res://240_sx_nfs_pro_street.glb"
const DESIRED_LENGTH := 4.3
const MODEL_AUTHORED_FORWARD_YAW := 0.0
const MIN_CAMERA_DISTANCE := 3.8
const OVERLAY_WINDOW_SCALE := 1.35
const Race240SXRig = preload("res://scripts/race_240sx_rig.gd")

@onready var viewport: SubViewport = $Car3DViewport
@onready var world_root: Node3D = $Car3DViewport/Car3DWorld

var model_root: Node3D = null
var model_instance: Node3D = null
var body_pivot: Node3D = null
var camera: Camera3D = null
var camera_rig: Node3D = null
var rig = null
var body_roll: float = 0.0
var body_pitch: float = 0.0
var model_scaled_size := Vector3.ZERO
var model_foot := Vector3.ZERO
var fitted_viewport_size := Vector2i.ZERO
var ready_3d := false
var camera_distance := 5.0
var camera_state = null
var race_renderer: Node2D = null
# The fitted mesh transform is independent of the shared camera rig.
var model_base_scale: float = 1.0
var model_base_position: Vector3 = Vector3.ZERO

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

    camera_rig = Node3D.new()
    camera_rig.name = "CameraRig"
    world_root.add_child(camera_rig)

    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 30.0
    camera.near = 0.05
    camera.far = 100.0
    camera.position = Vector3(0.0, 1.15, 4.8)
    camera_rig.add_child(camera)
    camera.make_current()

    var packed := load(CAR_MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Level2 240SX] Failed to load %s" % CAR_MODEL_PATH)
        return

    model_root = Node3D.new()
    model_root.name = "CarRoot"
    world_root.add_child(model_root)

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 240SX] GLB root is not Node3D")
        return

    model_instance.name = "CarMesh"
    model_root.add_child(model_instance)
    model_instance.rotation.y = MODEL_AUTHORED_FORWARD_YAW

    _prepare_materials()
    var body_nodes := model_instance.get_children()
    rig = Race240SXRig.new()
    if not rig.build(model_instance):
        push_error("[Level2 240SX] Wheel/lamp rig could not be built")
        return

    var bounds := _calculate_bounds()
    var longitudinal := maxf(bounds.size.x, bounds.size.z)
    if longitudinal < 0.01:
        push_error("[Level2 240SX] Invalid model bounds")
        return

    var scale_factor := DESIRED_LENGTH / longitudinal
    model_base_scale = scale_factor
    model_instance.scale = Vector3.ONE * model_base_scale

    var rear_centre := Vector3.ZERO
    var ground_y := INF
    for wheel in rig.wheels:
        var centre: Vector3 = wheel.steer.position
        ground_y = minf(ground_y, centre.y - float(wheel.radius))
        if not bool(wheel.front):
            rear_centre += centre * 0.5
    model_instance.position = Vector3(-rear_centre.x, -ground_y, -rear_centre.z) * scale_factor
    model_base_position = model_instance.position
    # Suspension moves the sprung body; four tire contact patches stay down.
    body_pivot = Node3D.new()
    body_pivot.name = "BodySuspension"
    model_instance.add_child(body_pivot)
    body_pivot.position = bounds.get_center()
    for node in body_nodes:
        node.reparent(body_pivot, true)

    model_scaled_size = bounds.size * scale_factor
    # Rear axle contact point is the screen-space baseline.
    model_foot = Vector3.ZERO
    _fit_camera_to_model(model_scaled_size)
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
        if mesh_node == null or mesh_node.mesh == null or not mesh_node.visible:
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

func _fit_camera_to_model(_scaled_size: Vector3) -> void:
    if camera == null or viewport == null:
        return

    camera.position = Vector3(0.0, 1.85, -6.45)
    camera.rotation = Vector3(0.0, PI, 0.0)
    fitted_viewport_size = viewport.size


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

func bind_camera_state(shared_state, renderer_ref: Node2D = null) -> void:
    camera_state = shared_state
    race_renderer = renderer_ref

func sync_from_race_car(
        race_car,
        track_x: PackedFloat32Array,
        viewport_size: Vector2,
        shared_state = null,
        _upcoming_curve: float = 0.0,
        delta: float = 1.0 / 60.0
) -> void:
    if shared_state != null:
        camera_state = shared_state
    if race_car == null or track_x.is_empty() or viewport_size.x <= 1.0:
        visible = false
        return

    if not ready_3d:
        return
    var playfield_height := viewport_size.y * (496.0 / 720.0)
    var car_width := clampf(viewport_size.x * 0.32, 210.0, 450.0)
    var window_width := car_width * OVERLAY_WINDOW_SCALE
    var window_height := car_width * 0.80 * OVERLAY_WINDOW_SCALE
    size = Vector2(window_width, window_height)
    var next_viewport_size := Vector2i(maxi(int(round(window_width)), 1), maxi(int(round(window_height)), 1))
    if viewport.size != next_viewport_size:
        viewport.size = next_viewport_size
    if fitted_viewport_size != next_viewport_size:
        _fit_camera_to_model(model_scaled_size)

    # One yaw for the entire world AND this camera. No local chase controller.
    var shared_yaw := float(camera_state.yaw_offset) if camera_state != null else float(race_car.heading_yaw)
    # The pseudo-3D world is +Z forward/+X screen-right. Godot's rear
    # camera looking along +Z sees -X on its right: convert handedness once.
    camera_rig.rotation.y = -shared_yaw
    model_root.rotation.y = -float(race_car.heading_yaw)
    var speed_ratio := clampf(float(race_car.speed) / RaceLevelData.PLAYER_MAX_SPEED, 0.0, 1.0)
    var blend := 1.0 - exp(-9.0 * maxf(delta, 0.0))
    body_roll = lerpf(body_roll, float(race_car.steer_applied) * speed_ratio * deg_to_rad(2.3), blend)
    body_pitch = lerpf(body_pitch, -clampf(float(race_car.longitudinal_acceleration) / 12.0, -1.0, 1.0) * deg_to_rad(1.0), blend)
    body_pivot.rotation = Vector3(body_pitch, 0.0, body_roll)
    var presentation_zoom := float(camera_state.zoom) if camera_state != null else 1.0
    model_instance.scale = Vector3.ONE * model_base_scale
    model_instance.position = model_base_position
    rig.sync(race_car, model_base_scale, delta)

    var anchor := Vector2(viewport_size.x * 0.5, playfield_height - 4.0)
    if race_renderer != null and race_renderer.has_method("get_player_ground_anchor"):
        anchor = race_renderer.call("get_player_ground_anchor", viewport_size)
        # Match the world's pinhole projection, including focal length and
        # camera height. A separate downward-pitched camera made the front
        # tires float even though the rear contact point was aligned.
        var focal := 0.84 * presentation_zoom * viewport_size.x * 0.75
        var horizon: float = race_renderer._horizon(playfield_height)
        var height := (playfield_height - horizon) * 6.0 * presentation_zoom / focal
        var track_position := float(race_car.segment_index) + float(race_car.segment_progress)
        var camera_x: float = race_renderer._camera_world_x(track_position)
        var rear_x := float(race_car.world_x) + sin(float(race_car.heading_yaw)) * 0.45
        var rear_z := cos(float(race_car.heading_yaw)) * 0.45
        camera.position = Basis(Vector3.UP, shared_yaw) * Vector3(rear_x - camera_x, height, -race_renderer._behind() - rear_z)
        camera.fov = rad_to_deg(2.0 * atan(float(viewport.size.y) * 0.5 / focal))
    # Align tire contact with the SAME projected point used by the asphalt.
    var foot_screen := camera.unproject_position(model_root.global_transform * model_foot)
    position = anchor - foot_screen
    var shared_roll := float(camera_state.roll) if camera_state != null else 0.0
    pivot_offset = foot_screen
    rotation = -shared_roll
    visible = ready_3d

func is_model_ready() -> bool:
    return ready_3d
