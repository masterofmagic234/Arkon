extends Control
class_name Race240SXOverlay

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")
const CAR_MODEL_PATH := "res://240_sx_nfs_pro_street.glb"
const DESIRED_LENGTH := 6.2
const MODEL_AUTHORED_FORWARD_YAW := 0.0
const MIN_CAMERA_DISTANCE := 3.8
const CAMERA_DISTANCE_MARGIN := 0.15
const OVERLAY_WINDOW_SCALE := 1.35
const CAMERA_LOOK_SPEED := 3.5
const CAMERA_FOLLOW_RATIO := 0.70
const CAMERA_CENTRIFUGAL_OFFSET := 0.85
const CAMERA_OFFSET_SPEED := 2.5
const CURVE_LOOK_AHEAD_YAW := 0.12

@onready var viewport: SubViewport = $Car3DViewport
@onready var world_root: Node3D = $Car3DViewport/Car3DWorld

var model_root: Node3D = null
var model_instance: Node3D = null
var camera: Camera3D = null
var camera_rig: Node3D = null
var camera_orientation_initialized := false
var ready_3d := false
var camera_distance := 5.0
var camera_state = null

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

    # Keep the requested hierarchy: CarRoot owns both the visible car and the
    # CameraRig, while the internal camera follows the nose with controlled lag.
    if camera_rig != null:
        world_root.remove_child(camera_rig)
        model_root.add_child(camera_rig)

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 240SX] GLB root is not Node3D")
        return

    model_instance.name = "CarMesh"
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

    _fit_camera_to_model(bounds.size * scale_factor)
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

func _fit_camera_to_model(scaled_size: Vector3) -> void:
    if camera == null or viewport == null:
        return

    var target := Vector3(0.0, 0.08, 0.0)
    var aspect := float(viewport.size.x) / maxf(float(viewport.size.y), 1.0)
    camera.keep_aspect = Camera3D.KEEP_HEIGHT

    # KEEP_HEIGHT means Camera3D.fov is the vertical FOV. Derive the
    # horizontal FOV from the actual render-target aspect ratio.
    var vertical_fov := deg_to_rad(camera.fov)
    var horizontal_fov := 2.0 * atan(
        tan(vertical_fov * 0.5) * maxf(aspect, 0.01)
    )

    # Fit width and body height independently instead of using the full
    # AABB diagonal. The old diagonal fit was dominated by the car's
    # longitudinal/depth extent and pushed the camera far enough away that
    # the 240SX became nearly invisible on the Android overlay.
    var half_width := scaled_size.x * 0.5
    var half_height := scaled_size.y * 0.5
    var half_depth := scaled_size.z * 0.5

    var distance_width := half_width / maxf(tan(horizontal_fov * 0.5), 0.01)
    var distance_height := half_height / maxf(tan(vertical_fov * 0.5), 0.01)
    var distance_depth := half_depth + 0.35
    var distance := maxf(
        MIN_CAMERA_DISTANCE,
        maxf(distance_width, maxf(distance_height, distance_depth))
    ) + CAMERA_DISTANCE_MARGIN
    distance *= OVERLAY_WINDOW_SCALE
    camera_distance = distance

    # This Camera3D is deliberately fixed. Level2 owns the gameplay/presentation
    # camera state; this camera only renders the GLB from the chosen top-rear view.
    camera.position = target + Vector3(0.0, 1.05, -camera_distance)
    # Initialize the local view direction once. Later the parent CameraRig
    # rotates with chase-camera inertia; viewport resizes must not reset it.
    if not camera_orientation_initialized:
        camera.look_at(target, Vector3.UP)
        camera_orientation_initialized = true


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

func bind_camera_state(shared_state) -> void:
    camera_state = shared_state

func sync_from_race_car(
        race_car,
        track_x: PackedFloat32Array,
        viewport_size: Vector2,
        shared_state = null,
        upcoming_curve: float = 0.0,
        delta: float = 1.0 / 60.0
) -> void:
    if shared_state != null:
        camera_state = shared_state
    if race_car == null or track_x.is_empty() or viewport_size.x <= 1.0:
        visible = false
        return

    var track_position: float = float(race_car.segment_index) + float(race_car.segment_progress)
    var center := RaceMath.track_center_x(track_position, track_x)
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

    # Keep a larger transparent render window around the car. The steering
    # rotation changes the projected AABB, so a viewport sized exactly to the
    # unrotated body clips the front/rear corners when the car turns.
    var window_width := car_width * OVERLAY_WINDOW_SCALE
    var window_height := car_height * OVERLAY_WINDOW_SCALE

    # Use the same lateral camera offset as the pseudo-3D renderer so the car
    # is positioned relative to the shared main camera, not a second chase state.
    var camera_lateral_world := 0.0
    if camera_state != null:
        camera_lateral_world = float(camera_state.lateral_offset)
    var relative_lateral := clampf(
        lateral - camera_lateral_world / maxf(half_road, 0.001),
        -1.0,
        1.0
    )

    position = Vector2(
        viewport_size.x * 0.5
        + relative_lateral * viewport_size.x * 0.10
        - window_width * 0.5,
        playfield_height - window_height - 2.0
    )
    size = Vector2(window_width, window_height)

    var next_viewport_size := Vector2i(
        maxi(int(round(window_width)), 1),
        maxi(int(round(window_height)), 1)
    )
    if viewport.size != next_viewport_size:
        viewport.size = next_viewport_size
        if model_instance != null:
            var fitted_bounds := _calculate_bounds()
            if fitted_bounds.size.length() > 0.01:
                _fit_camera_to_model(fitted_bounds.size * model_instance.scale)


    var steer := clampf(float(race_car.steer_applied), -1.0, 1.0)
    var curve := clampf(upcoming_curve, -1.0, 1.0)
    # The car follows its own nose heading. Curve preview adds a small visual
    # anticipation, while the main pseudo-3D camera remains bound to actual
    # heading_yaw through RaceCameraState.
    var target_car_rotation_y := (
        MODEL_AUTHORED_FORWARD_YAW
        + float(race_car.heading_yaw)
        - curve * CURVE_LOOK_AHEAD_YAW
    )

    if model_root != null:
        model_root.rotation.y = target_car_rotation_y
        model_root.rotation.z = (
            -steer * 0.06
            - float(race_car.slip_angle) * 0.08
            + curve * 0.035
        )
        if camera_state != null:
            # Speed zoom is applied to the rendered model only. The transparent
            # viewport remains independently sized with the steering-safe margin.
            var presentation_zoom := clampf(
                float(camera_state.zoom),
                1.0,
                1.06
            )
            model_root.scale = Vector3.ONE * presentation_zoom

    if camera_rig != null:
        # A chase camera follows the nose with deliberate inertia. Since the
        # camera follows 70% of the car yaw, the remaining angle lets the player
        # read the car turning instead of seeing a permanently square rear view.
        var camera_blend := 1.0 - exp(-CAMERA_LOOK_SPEED * maxf(delta, 0.0))
        # CameraRig is a child of CarRoot, so its local yaw is the
        # remaining 30% lag. Combined with the car's yaw, its world yaw follows
        # 70% of the nose direction, leaving a readable relative car angle.
        camera_rig.rotation.y = lerp_angle(
            camera_rig.rotation.y,
            target_car_rotation_y * (CAMERA_FOLLOW_RATIO - 1.0),
            camera_blend
        )
        var target_camera_x := clampf(
            (steer + curve) * CAMERA_CENTRIFUGAL_OFFSET,
            -CAMERA_CENTRIFUGAL_OFFSET,
            CAMERA_CENTRIFUGAL_OFFSET
        )
        var offset_blend := 1.0 - exp(-CAMERA_OFFSET_SPEED * maxf(delta, 0.0))
        camera_rig.position.x = lerpf(
            camera_rig.position.x,
            target_camera_x,
            offset_blend
        )

    # The main pseudo-3D camera is still owned by Level2 and follows heading_yaw;
    # this CameraRig only adds the NFS-style chase lag in the car render viewport.
    visible = ready_3d

func is_model_ready() -> bool:
    return ready_3d
