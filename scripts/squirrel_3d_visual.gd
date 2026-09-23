extends Node3D
class_name Squirrel3DVisual

const MODEL_PATH := "res://cartoon squirrel 3d model.glb"
const TARGET_HEIGHT := 1.85
const FALLBACK_IDLE_BOB := 0.035
const FALLBACK_RUN_BOB := 0.075
const FALLBACK_RUN_ROLL := 0.035
const STUNNED_ANGLE := deg_to_rad(-78.0)

var model_instance: Node3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var skeleton_base_rotations: Dictionary = {}
var part_nodes: Dictionary = {}
var part_base_rotations: Dictionary = {}
var current_mode := "idle"
var anim_time := 0.0
var base_position := Vector3.ZERO
var base_rotation := Vector3.ZERO
var stunned := false
var hit_recoil := 0.0

func setup() -> bool:
    if model_instance != null:
        return true

    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_warning("[Squirrel3D] Could not load %s" % MODEL_PATH)
        return false

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_warning("[Squirrel3D] %s did not instantiate as Node3D" % MODEL_PATH)
        return false

    add_child(model_instance)
    _normalize_model()

    animation_player = model_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
    skeleton = model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
    if animation_player != null:
        print("[Squirrel3D] AnimationPlayer found. Clips: ", animation_player.get_animation_list())
    if skeleton != null:
        for i in skeleton.get_bone_count():
            var bone_name := str(skeleton.get_bone_name(i))
            skeleton_base_rotations[i] = skeleton.get_bone_pose_rotation(i)
        print("[Squirrel3D] Skeleton found. Bones: ", skeleton.get_bone_count())

    _cache_named_parts()

    base_position = model_instance.position
    base_rotation = model_instance.rotation
    return true

func apply_active() -> void:
    stunned = false
    hit_recoil = 0.0
    visible = true
    _play_named_animation("idle")

func apply_hit() -> void:
    if stunned:
        return
    hit_recoil = 1.0
    _play_named_animation("hit")

func apply_stunned() -> void:
    stunned = true
    hit_recoil = 0.0
    _play_named_animation("stunned")

func animate_squirrel(phase: float, state: int, speed: float,
        direction: Vector3, dt: float) -> void:
    if model_instance == null:
        return

    anim_time += dt

    if stunned:
        _animate_stunned(dt)
        return

    var running := direction.length_squared() > 0.01 and speed > 0.15
    if running:
        current_mode = "run"
        _play_named_animation("run")
    else:
        current_mode = "idle"
        _play_named_animation("idle")

    _face_direction(direction)

    if hit_recoil > 0.0:
        hit_recoil = maxf(hit_recoil - dt * 5.5, 0.0)

    # Even without a rigged animation, the model gets a readable game-style
    # motion profile. If imported clips exist, they take over this fallback.
    if not _has_playing_named_animation():
        _animate_rig_fallback(phase, running)
        var bob_amount := FALLBACK_RUN_BOB if running else FALLBACK_IDLE_BOB
        var bob_speed := 9.0 if running else 2.6
        var bob := sin(anim_time * bob_speed + phase) * bob_amount
        model_instance.position = base_position + Vector3(0.0, bob, 0.0)

        if running:
            model_instance.rotation = base_rotation + Vector3(
                0.0,
                0.0,
                sin(anim_time * 9.0 + phase) * FALLBACK_RUN_ROLL
            )
        else:
            model_instance.rotation = base_rotation + Vector3(
                0.0,
                0.0,
                sin(anim_time * 2.6 + phase) * 0.012
            )

        if hit_recoil > 0.0:
            model_instance.position += Vector3(0.0, 0.0, -0.08 * hit_recoil)

func _animate_stunned(dt: float) -> void:
    _stop_named_animation()
    var target_rotation := Vector3(base_rotation.x, base_rotation.y, STUNNED_ANGLE)
    model_instance.rotation = model_instance.rotation.lerp(target_rotation, minf(dt * 8.0, 1.0))
    model_instance.position.y = lerpf(model_instance.position.y, base_position.y - 0.35, minf(dt * 8.0, 1.0))
    _animate_stunned_rig()

func _animate_rig_fallback(phase: float, running: bool) -> void:
    if skeleton != null:
        for bone_index in skeleton_base_rotations.keys():
            var name := str(skeleton.get_bone_name(int(bone_index))).to_lower()
            var offset := Vector3.ZERO
            var wave := sin(anim_time * (9.0 if running else 2.6) + phase)
            var wave_b := cos(anim_time * (9.0 if running else 2.6) + phase)

            if name.contains("head"):
                offset.x = wave * (0.05 if running else 0.018)
                offset.z = wave_b * (0.03 if running else 0.012)
            elif name.contains("arm"):
                offset.z = wave * (0.18 if running else 0.035)
            elif name.contains("leg") or name.contains("foot"):
                offset.z = wave * 0.22 if running else 0.0
            elif name.contains("tail"):
                offset.x = wave_b * (0.10 if running else 0.035)
                offset.z = wave * (0.08 if running else 0.025)
            elif name.contains("spine") or name.contains("chest") or name.contains("pelvis"):
                offset.x = wave * (0.03 if running else 0.012)

            if offset.length_squared() > 0.0:
                skeleton.set_bone_pose_rotation(
                    int(bone_index),
                    skeleton_base_rotations[bone_index] * Quaternion.from_euler(offset)
                )

    for key in part_nodes.keys():
        var node: Node3D = part_nodes[key]
        if node == null or not is_instance_valid(node):
            continue
        var name := str(key)
        var wave := sin(anim_time * (9.0 if running else 2.6) + phase)
        var rotation_offset := Vector3.ZERO
        if name.contains("tail"):
            rotation_offset.z = wave * (0.08 if running else 0.025)
        elif name.contains("arm"):
            rotation_offset.x = wave * (0.16 if running else 0.025)
        elif name.contains("leg") or name.contains("foot"):
            rotation_offset.x = -wave * 0.20 if running else 0.0
        if name.contains("head"):
            rotation_offset.z = cos(anim_time * 2.6 + phase) * 0.012
        node.rotation = part_base_rotations[key] + rotation_offset

func _animate_stunned_rig() -> void:
    if skeleton != null:
        for bone_index in skeleton_base_rotations.keys():
            var name := str(skeleton.get_bone_name(int(bone_index))).to_lower()
            var offset := Vector3.ZERO
            if name.contains("head") or name.contains("spine") or name.contains("chest"):
                offset.z = deg_to_rad(-18.0)
            elif name.contains("arm"):
                offset.x = deg_to_rad(22.0)
            elif name.contains("leg") or name.contains("foot"):
                offset.x = deg_to_rad(-12.0)
            elif name.contains("tail"):
                offset.x = deg_to_rad(15.0)
            if offset.length_squared() > 0.0:
                skeleton.set_bone_pose_rotation(
                    int(bone_index),
                    skeleton_base_rotations[bone_index] * Quaternion.from_euler(offset)
                )

func _cache_named_parts() -> void:
    if model_instance == null:
        return
    for child in model_instance.find_children("*", "Node3D", true, false):
        var node := child as Node3D
        if node == null or node == model_instance:
            continue
        var key := node.name.to_lower()
        if not (
            key.contains("tail")
            or key.contains("arm")
            or key.contains("leg")
            or key.contains("foot")
            or key.contains("head")
        ):
            continue
        part_nodes[key] = node
        part_base_rotations[key] = node.rotation

func _face_direction(direction: Vector3) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.01:
        return
    var target := model_instance.global_position + flat.normalized()
    model_instance.look_at(target, Vector3.UP)

func _play_named_animation(keyword: String) -> void:
    if animation_player == null:
        return
    var clip := _find_clip(keyword)
    if clip.is_empty():
        return
    if animation_player.current_animation == clip and animation_player.is_playing():
        return
    animation_player.play(clip, 0.15)

func _stop_named_animation() -> void:
    if animation_player != null and animation_player.is_playing():
        animation_player.stop()

func _find_clip(keyword: String) -> String:
    if animation_player == null:
        return ""
    var wanted := keyword.to_lower()
    for clip in animation_player.get_animation_list():
        var normalized := str(clip).to_lower().replace(" ", "_")
        if normalized == wanted or normalized.contains(wanted):
            return str(clip)
    return ""

func _has_playing_named_animation() -> bool:
    return animation_player != null and animation_player.is_playing()

func _normalize_model() -> void:
    var bounds := _collect_bounds()
    if bounds.size.y <= 0.001:
        return

    var scale_factor := TARGET_HEIGHT / bounds.size.y
    model_instance.scale = Vector3.ONE * scale_factor

    var center := bounds.position + bounds.size * 0.5
    model_instance.position = Vector3(
        -center.x * scale_factor,
        -bounds.position.y * scale_factor,
        -center.z * scale_factor
    )

func _collect_bounds() -> AABB:
    var first := true
    var combined := AABB()

    for mesh in model_instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := mesh as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var local_bounds := mesh_instance.get_aabb()
        var relative := model_instance.global_transform.affine_inverse() * mesh_instance.global_transform
        var corners := [
            Vector3(local_bounds.position.x, local_bounds.position.y, local_bounds.position.z),
            Vector3(local_bounds.end.x, local_bounds.position.y, local_bounds.position.z),
            Vector3(local_bounds.position.x, local_bounds.end.y, local_bounds.position.z),
            Vector3(local_bounds.end.x, local_bounds.end.y, local_bounds.position.z),
            Vector3(local_bounds.position.x, local_bounds.position.y, local_bounds.end.z),
            Vector3(local_bounds.end.x, local_bounds.position.y, local_bounds.end.z),
            Vector3(local_bounds.position.x, local_bounds.end.y, local_bounds.end.z),
            Vector3(local_bounds.end.x, local_bounds.end.y, local_bounds.end.z),
        ]

        for corner in corners:
            var point := relative * corner
            if first:
                combined = AABB(point, Vector3.ZERO)
                first = false
            else:
                combined = combined.expand(point)

    return combined
