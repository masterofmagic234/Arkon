extends Node2D
class_name Level2RacerVisualPseudo3D

const OKA_MODEL_PATH := "res://compact+car+3d+model.glb"
const SQUIRREL_PATH := "res://assets/squirrel_mobile.png"
const VIEWPORT_SIZE := Vector2i(256, 256)
const OKA_DESIRED_LENGTH := 3.2
const OKA_MAX_SPEED := 32.0
const MODEL_YAW_PER_STEER := deg_to_rad(11.0)
const MODEL_ROLL_PER_STEER := deg_to_rad(5.0)
const MODEL_PITCH_PER_SPEED := deg_to_rad(1.5)

var renderer: Node2D = null
var movement: Node = null
var projection: Dictionary = {}
var texture: Texture2D = null
var _draw_width := 0.0
var _draw_height := 0.0

var model_viewport: SubViewport = null
var model_root: Node3D = null
var model_pivot: Node3D = null
var model_instance: Node3D = null
var model_camera: Camera3D = null
var model_ready := false

func bind_movement(movement_ref: Node) -> void:
    movement = movement_ref

    if movement != null and bool(movement.get("is_player")):
        call_deferred("_ensure_oka_viewport")
    else:
        texture = _load_texture(SQUIRREL_PATH)

func bind_renderer(renderer_ref: Node2D, movement_ref: Node) -> void:
    renderer = renderer_ref
    movement = movement_ref

    if movement != null and bool(movement.get("is_player")):
        call_deferred("_ensure_oka_viewport")
    else:
        texture = _load_texture(SQUIRREL_PATH)

func _ensure_oka_viewport() -> void:
    if model_ready or movement == null or not bool(movement.get("is_player")):
        return

    model_viewport = SubViewport.new()
    model_viewport.name = "OkaViewport"
    model_viewport.size = VIEWPORT_SIZE
    model_viewport.transparent_bg = true
    model_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    model_viewport.disable_3d = false
    model_viewport.own_world_3d = true
    model_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    add_child(model_viewport)

    var world_root := Node3D.new()
    world_root.name = "OkaWorld"
    model_viewport.add_child(world_root)
    model_root = world_root

    model_pivot = Node3D.new()
    model_pivot.name = "OkaPivot"
    model_root.add_child(model_pivot)

    var packed := load(OKA_MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Level2 Oka] Failed to load 3D model: %s" % OKA_MODEL_PATH)
        model_ready = true
        queue_redraw()
        return

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Level2 Oka] Model scene is not a Node3D: %s" % OKA_MODEL_PATH)
        model_ready = true
        queue_redraw()
        return

    model_instance.name = "OkaModel"
    model_pivot.add_child(model_instance)
    _prepare_oka_materials()

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
    key_light.light_energy = 1.7
    key_light.shadow_enabled = false
    model_root.add_child(key_light)

    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
    fill_light.light_energy = 0.7
    fill_light.shadow_enabled = false
    model_root.add_child(fill_light)

    model_camera = Camera3D.new()
    model_camera.name = "OkaCamera"
    model_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    model_camera.fov = 38.0
    model_camera.near = 0.02
    model_camera.far = 30.0
    model_camera.current = true
    model_camera.position = Vector3(0.0, 1.25, 4.15)
    model_root.add_child(model_camera)
    model_camera.look_at(Vector3(0.0, 0.42, 0.0), Vector3.UP)

    await get_tree().process_frame
    _fit_oka_model()
    model_ready = true
    queue_redraw()

func _prepare_oka_materials() -> void:
    if model_instance == null:
        return
    var meshes := model_instance.find_children("*", "MeshInstance3D", true, false)
    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        for surface in range(mesh_node.mesh.get_surface_count()):
            var material := mesh_node.get_active_material(surface)
            if material is StandardMaterial3D:
                var clean := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
                clean.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                clean.metallic = 0.0
                clean.roughness = 1.0
                clean.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                mesh_node.set_surface_override_material(surface, clean)

func _fit_oka_model() -> void:
    if model_instance == null or model_camera == null:
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
        var corners := [
            Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
            Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
            Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
            Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
        ]

        var mesh_to_root := inv_root * mesh_node.global_transform
        for point in corners:
            var p: Vector3 = mesh_to_root * point
            if not has_bounds:
                bounds = AABB(p, Vector3.ZERO)
                has_bounds = true
            else:
                bounds = bounds.expand(p)

    if not has_bounds or bounds.size.length_squared() <= 0.0001:
        push_warning("[Level2 Oka] Could not determine model bounds; using imported scale.")
        model_pivot.position = Vector3(0.0, -0.45, 0.0)
        return

    var length := maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
    var fit_scale := OKA_DESIRED_LENGTH / length

    model_instance.scale = model_instance.scale * fit_scale
    var scaled_center := bounds.get_center() * fit_scale

    # The camera looks at the rear three-quarter body. Put the car's geometric
    # center on the visual ground line instead of letting imported origin offsets
    # make the Oka float above the road.
    model_instance.position = -scaled_center
    model_instance.position.y += (bounds.size.y * 0.5) * fit_scale * 0.20

func sync_from_movement() -> void:
    if renderer == null or movement == null:
        visible = false
        return

    projection = renderer.project_racer(movement)
    visible = bool(projection.get("visible", false))
    if not visible:
        return

    position = Vector2(
        float(projection["x"]),
        float(projection["y"])
    )
    _draw_width = float(projection["width"])
    _draw_height = float(projection["height"])

    if bool(movement.get("is_player")) and model_ready:
        var steer := clampf(float(movement.get("steer_in")), -1.0, 1.0)
        var speed := maxf(float(movement.get("speed")), 0.0)
        var max_speed := OKA_MAX_SPEED
        var track_yaw := float(movement.get_render_track_yaw()) if movement.has_method("get_render_track_yaw") else 0.0

        model_pivot.rotation.y = track_yaw * 0.45 + steer * MODEL_YAW_PER_STEER
        model_pivot.rotation.z = -steer * MODEL_ROLL_PER_STEER
        model_pivot.rotation.x = -clampf(speed / max_speed, 0.0, 1.0) * MODEL_PITCH_PER_SPEED

        queue_redraw()
    else:
        rotation = float(projection.get("rotation", 0.0))
        z_index = 10
        queue_redraw()

func _draw() -> void:
    if movement == null or not visible:
        return

    if bool(movement.get("is_player")):
        if model_viewport != null and model_viewport.get_texture() != null:
            var src_size := Vector2(VIEWPORT_SIZE)
            var fit := minf(_draw_width / src_size.x, _draw_height / src_size.y)
            var dst_size := src_size * fit
            draw_texture_rect(
                model_viewport.get_texture(),
                Rect2(-dst_size.x * 0.5, -dst_size.y, dst_size.x, dst_size.y),
                false
            )
        else:
            draw_rect(
                Rect2(-_draw_width * 0.5, -_draw_height, _draw_width, _draw_height),
                Color(0.72, 0.08, 0.08, 1.0),
                true
            )
        z_index = 20
        return

    if texture != null:
        draw_texture_rect(
            texture,
            Rect2(
                -_draw_width * 0.5,
                -_draw_height,
                _draw_width,
                _draw_height
            ),
            false
        )
        return

    var w := maxf(_draw_width, 8.0)
    var h := maxf(_draw_height, 8.0)
    draw_rect(Rect2(-w * 0.5, -h, w, h), Color(0.8, 0.15, 0.15), true)
    draw_rect(Rect2(-w * 0.4, -h * 0.7, w * 0.8, h * 0.3), Color.WHITE, true)

func _load_texture(path: String) -> Texture2D:
    return load(path) as Texture2D
