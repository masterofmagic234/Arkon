extends Node3D
class_name Squirrel3DVisual

# ACORN HUNTER — rigged 3D Scout presentation.
# The imported GLB provides the mesh + Skeleton3D. This wrapper owns only
# gameplay-facing yaw. Animation is driven by real Skeleton3D bone tracks.

const MODEL_PATH := "res://cartoon squirrel 3d model1.glb"
const TARGET_HEIGHT := 1.85
const MODEL_YAW_OFFSET := 0.0

const IDLE_LENGTH := 1.20
const RUN_LENGTH := 0.56
const HIT_LENGTH := 0.18
const STUNNED_LENGTH := 0.60

var model_instance: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_library: AnimationLibrary
var current_mode := "idle"
var action_lock := 0.0
var base_position := Vector3.ZERO
var base_rotation := Vector3.ZERO
var stunned := false
var skeleton_ready := false

var bones: Array[int] = []
var spine_bones: Array[int] = []
var head_bones: Array[int] = []
var left_arm_bones: Array[int] = []
var right_arm_bones: Array[int] = []
var left_leg_bones: Array[int] = []
var right_leg_bones: Array[int] = []
var tail_bones: Array[int] = []
var base_rotations: Dictionary = {}

func setup() -> bool:
    if model_instance != null:
        return skeleton_ready

    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Squirrel3D] Could not load %s" % MODEL_PATH)
        return false

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Squirrel3D] %s did not instantiate as Node3D" % MODEL_PATH)
        return false

    add_child(model_instance)

    # Disable any animation player imported from the GLB. We create our own
    # player below so no imported track can fight the gameplay animation.
    var imported_players := model_instance.find_children("*", "AnimationPlayer", true, false)
    for candidate in imported_players:
        var imported := candidate as AnimationPlayer
        if imported == null:
            continue
        imported.stop(true)
        imported.autoplay = &""

    skeleton = model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
    if skeleton == null:
        push_error("[Squirrel3D] Rigged model contains no Skeleton3D.")
        return false

    _normalize_model()

    # Reset to the GLB rest pose before sampling bone rotations.
    skeleton.reset_bone_poses()
    _build_bone_map()

    animation_player = AnimationPlayer.new()
    animation_player.name = "ScoutAnimationPlayer"
    animation_player.root_node = NodePath("..")
    animation_player.playback_default_blend_time = 0.10
    model_instance.add_child(animation_player)

    animation_library = AnimationLibrary.new()
    animation_player.add_animation_library(&"", animation_library)

    _build_skeletal_animations()

    base_position = model_instance.position
    base_rotation = model_instance.rotation
    skeleton_ready = true

    print("[Squirrel3D] Rig ready. Bones: ", skeleton.get_bone_count(),
        " spine=", spine_bones.size(),
        " head=", head_bones.size(),
        " arms=", left_arm_bones.size() + right_arm_bones.size(),
        " legs=", left_leg_bones.size() + right_leg_bones.size(),
        " tail=", tail_bones.size())

    if left_leg_bones.is_empty() or right_leg_bones.is_empty():
        push_warning("[Squirrel3D] Could not identify both leg chains; run animation will be limited.")
    return true

func apply_active() -> void:
    stunned = false
    action_lock = 0.0
    visible = true
    _play_animation("Scout_Idle", true)

func apply_hit() -> void:
    if stunned or animation_player == null:
        return
    action_lock = HIT_LENGTH
    _play_animation("Scout_Hit", false)

func apply_stunned() -> void:
    stunned = true
    action_lock = STUNNED_LENGTH
    _play_animation("Scout_Stunned", false)

func animate_squirrel(_phase: float, _state: int, speed: float,
        direction: Vector3, dt: float) -> void:
    if not skeleton_ready or model_instance == null:
        return

    action_lock = maxf(0.0, action_lock - dt)
    if stunned:
        return
    if action_lock > 0.0:
        return

    _face_direction(direction)

    var running := direction.length_squared() > 0.01 and speed > 0.15
    if running:
        if current_mode != "run":
            current_mode = "run"
            animation_player.speed_scale = clampf(speed / 3.4, 0.75, 1.35)
            _play_animation("Scout_Run", true)
    else:
        if current_mode != "idle":
            current_mode = "idle"
            animation_player.speed_scale = 1.0
            _play_animation("Scout_Idle", true)

func _face_direction(direction: Vector3) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.01:
        return
    flat = flat.normalized()
    # Only the outer wrapper rotates. The skeleton and its bone animation stay
    # in the model's local space, so locomotion can freely face all 360 degrees.
    rotation.y = atan2(-flat.x, -flat.z) + MODEL_YAW_OFFSET

func _play_animation(animation_name: StringName, looped: bool) -> void:
    if animation_player == null or not animation_library.has_animation(animation_name):
        return

    if animation_player.current_animation == animation_name and animation_player.is_playing():
        return

    var animation := animation_library.get_animation(animation_name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    animation_player.play(animation_name, 0.10)

func _build_bone_map() -> void:
    bones.clear()
    spine_bones.clear()
    head_bones.clear()
    left_arm_bones.clear()
    right_arm_bones.clear()
    left_leg_bones.clear()
    right_leg_bones.clear()
    tail_bones.clear()
    base_rotations.clear()

    for bone_index in skeleton.get_bone_count():
        bones.append(bone_index)
        base_rotations[bone_index] = skeleton.get_bone_pose_rotation(bone_index)

        var name := str(skeleton.get_bone_name(bone_index)).to_lower()
        var compact := name.replace("_", "").replace("-", "").replace(".", "")

        if _name_has_any(compact, [
            "head", "neck", "face", "skull"
        ]):
            head_bones.append(bone_index)
        elif _name_has_any(compact, [
            "tail", "tail01", "tail02", "tail03", "tail04"
        ]):
            tail_bones.append(bone_index)
        elif _name_has_any(compact, [
            "spine", "chest", "upperbody", "torso", "pelvis", "hips"
        ]):
            spine_bones.append(bone_index)
        elif _is_left(compact) and _name_has_any(compact, [
            "arm", "upperarm", "forearm", "hand", "shoulder"
        ]):
            left_arm_bones.append(bone_index)
        elif _is_right(compact) and _name_has_any(compact, [
            "arm", "upperarm", "forearm", "hand", "shoulder"
        ]):
            right_arm_bones.append(bone_index)
        elif _is_left(compact) and _name_has_any(compact, [
            "leg", "thigh", "calf", "shin", "foot", "ankle"
        ]):
            left_leg_bones.append(bone_index)
        elif _is_right(compact) and _name_has_any(compact, [
            "leg", "thigh", "calf", "shin", "foot", "ankle"
        ]):
            right_leg_bones.append(bone_index)

func _name_has_any(name: String, patterns: Array) -> bool:
    for pattern in patterns:
        if name.contains(str(pattern)):
            return true
    return false

func _is_left(name: String) -> bool:
    return _name_has_any(name, ["left", "lft", "limb_l", "arm_l", "leg_l", "hand_l", "foot_l"])

func _is_right(name: String) -> bool:
    return _name_has_any(name, ["right", "rgt", "limb_r", "arm_r", "leg_r", "hand_r", "foot_r"])

func _build_skeletal_animations() -> void:
    _add_animation("Scout_Idle", IDLE_LENGTH, true,
        func(t: float, bone_index: int) -> Quaternion:
            var base: Quaternion = base_rotations[bone_index]
            var wave := sin((t / IDLE_LENGTH) * TAU)
            var name := str(skeleton.get_bone_name(bone_index)).to_lower()
            var offset := Vector3.ZERO
            if spine_bones.has(bone_index):
                offset.x = wave * 0.025
            elif head_bones.has(bone_index):
                offset.z = wave * 0.018
            elif tail_bones.has(bone_index):
                offset.x = wave * 0.035
            elif left_arm_bones.has(bone_index) or right_arm_bones.has(bone_index):
                offset.x = wave * 0.018
            if name.contains("hand") or name.contains("foot"):
                offset *= 0.4
            return base * Quaternion.from_euler(offset)
        )

    _add_animation("Scout_Run", RUN_LENGTH, true,
        func(t: float, bone_index: int) -> Quaternion:
            var base: Quaternion = base_rotations[bone_index]
            var wave := sin((t / RUN_LENGTH) * TAU)
            var phase := -wave if right_leg_bones.has(bone_index) or right_arm_bones.has(bone_index) else wave
            var offset := Vector3.ZERO
            if left_leg_bones.has(bone_index) or right_leg_bones.has(bone_index):
                offset.x = phase * 0.32
            elif left_arm_bones.has(bone_index) or right_arm_bones.has(bone_index):
                offset.x = phase * 0.24
            elif spine_bones.has(bone_index):
                offset.z = wave * 0.045
            elif head_bones.has(bone_index):
                offset.z = wave * 0.025
            elif tail_bones.has(bone_index):
                offset.x = wave * 0.09
                offset.z = wave * 0.06
            return base * Quaternion.from_euler(offset)
        )

    _add_animation("Scout_Hit", HIT_LENGTH, false,
        func(t: float, bone_index: int) -> Quaternion:
            var base: Quaternion = base_rotations[bone_index]
            var p := clampf(t / HIT_LENGTH, 0.0, 1.0)
            var impulse := sin(p * PI)
            var offset := Vector3.ZERO
            if head_bones.has(bone_index):
                offset.z = -0.16 * impulse
            elif spine_bones.has(bone_index):
                offset.z = -0.10 * impulse
            elif left_arm_bones.has(bone_index):
                offset.x = 0.16 * impulse
            elif right_arm_bones.has(bone_index):
                offset.x = -0.16 * impulse
            elif tail_bones.has(bone_index):
                offset.x = 0.12 * impulse
            return base * Quaternion.from_euler(offset)
        )

    _add_animation("Scout_Stunned", STUNNED_LENGTH, false,
        func(t: float, bone_index: int) -> Quaternion:
            var base: Quaternion = base_rotations[bone_index]
            var p := clampf(t / STUNNED_LENGTH, 0.0, 1.0)
            var eased := 1.0 - pow(1.0 - p, 3.0)
            var offset := Vector3.ZERO
            if head_bones.has(bone_index):
                offset.z = deg_to_rad(-12.0) * eased
            elif spine_bones.has(bone_index):
                offset.z = deg_to_rad(-20.0) * eased
            elif left_arm_bones.has(bone_index):
                offset.x = deg_to_rad(24.0) * eased
            elif right_arm_bones.has(bone_index):
                offset.x = deg_to_rad(-24.0) * eased
            elif left_leg_bones.has(bone_index) or right_leg_bones.has(bone_index):
                offset.x = deg_to_rad(-10.0) * eased
            elif tail_bones.has(bone_index):
                offset.x = deg_to_rad(14.0) * eased
            return base * Quaternion.from_euler(offset)
        )

func _add_animation(animation_name: StringName, length: float, looped: bool,
        pose_function: Callable) -> void:
    var animation := Animation.new()
    animation.length = length
    animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    animation.step = 1.0 / 30.0

    var t_values := [0.0, length * 0.5, length]
    var skeleton_path := str(model_instance.get_path_to(skeleton))

    for bone_index in bones:
        var track := animation.add_track(Animation.TYPE_ROTATION_3D)
        var bone_name := str(skeleton.get_bone_name(bone_index))
        animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone_name]))

        for t in t_values:
            var value: Quaternion = pose_function.call(t, bone_index)
            animation.rotation_track_insert_key(track, t, value)

    var error := animation_library.add_animation(animation_name, animation)
    if error != OK:
        push_error("[Squirrel3D] Failed to add animation %s: %s" % [animation_name, error])

func _normalize_model() -> void:
    var bounds := _collect_bounds()
    if bounds.size.y <= 0.001:
        push_error("[Squirrel3D] Model bounds are empty.")
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

    for child in model_instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := child as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var local_bounds := mesh_instance.get_aabb()
        var relative := model_instance.global_transform.affine_inverse() * mesh_instance.global_transform
        var corners: Array[Vector3] = [
            Vector3(local_bounds.position.x, local_bounds.position.y, local_bounds.position.z),
            Vector3(local_bounds.end.x, local_bounds.position.y, local_bounds.position.z),
            Vector3(local_bounds.position.x, local_bounds.end.y, local_bounds.position.z),
            Vector3(local_bounds.end.x, local_bounds.end.y, local_bounds.position.z),
            Vector3(local_bounds.position.x, local_bounds.position.y, local_bounds.end.z),
            Vector3(local_bounds.end.x, local_bounds.position.y, local_bounds.end.z),
            Vector3(local_bounds.position.x, local_bounds.end.y, local_bounds.end.z),
            Vector3(local_bounds.end.x, local_bounds.end.y, local_bounds.end.z),
        ]

        for corner: Vector3 in corners:
            var point: Vector3 = relative * corner
            if first:
                combined = AABB(point, Vector3.ZERO)
                first = false
            else:
                combined = combined.expand(point)

    return combined
