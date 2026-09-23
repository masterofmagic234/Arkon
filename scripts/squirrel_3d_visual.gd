extends Node3D
class_name Squirrel3DVisual

# ACORN HUNTER — Scout 3D presentation.
# Gameplay yaw is owned by this wrapper so the squirrel can face every direction.
# When the GLB contains a Skeleton3D, animation is performed directly on bone poses.
# When the GLB is unrigged, a clearly marked root-motion fallback keeps presentation
# functional until a genuinely skinned/rigged asset is supplied.

const MODEL_PATH := "res://cartoon+squirrel+3d+model.glb"
const TARGET_HEIGHT: float = 1.85
const MODEL_YAW_OFFSET: float = 0.0

const HIT_LENGTH: float = 0.18
const STUNNED_LENGTH: float = 0.60

var model_instance: Node3D = null
var skeleton: Skeleton3D = null

var current_mode: String = "idle"
var action_lock: float = 0.0
var stunned: bool = false
var presentation_ready: bool = false
var skeleton_ready: bool = false
var fallback_reaction: int = 0

var base_model_position: Vector3 = Vector3.ZERO
var base_model_rotation: Vector3 = Vector3.ZERO

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
    if presentation_ready:
        return skeleton_ready

    var packed: PackedScene = load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Squirrel3D] Could not load %s" % MODEL_PATH)
        return false

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Squirrel3D] Could not instantiate %s" % MODEL_PATH)
        return false

    add_child(model_instance)

    skeleton = model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
    _normalize_model()

    base_model_position = model_instance.position
    base_model_rotation = model_instance.rotation

    if skeleton == null:
        push_warning(
            "[Squirrel3D] %s has no Skeleton3D. 360-degree root rotation is enabled, but skeletal animation is unavailable."
            % MODEL_PATH
        )
        presentation_ready = true
        return true

    skeleton.reset_bone_poses()
    _build_bone_map()

    skeleton_ready = true
    presentation_ready = true

    print(
        "[Squirrel3D] Rig ready. bones=", skeleton.get_bone_count(),
        " head=", head_bones.size(),
        " arms=", left_arm_bones.size() + right_arm_bones.size(),
        " legs=", left_leg_bones.size() + right_leg_bones.size(),
        " tail=", tail_bones.size()
    )

    return true

func apply_active() -> void:
    if not presentation_ready:
        return

    stunned = false
    action_lock = 0.0
    fallback_reaction = 0
    current_mode = "idle"
    visible = true

    if model_instance != null:
        model_instance.position = base_model_position
        model_instance.rotation = base_model_rotation

    if skeleton_ready:
        skeleton.reset_bone_poses()

func apply_hit() -> void:
    if not presentation_ready or stunned:
        return

    action_lock = HIT_LENGTH
    fallback_reaction = 1

func apply_stunned() -> void:
    if not presentation_ready:
        return

    stunned = true
    action_lock = STUNNED_LENGTH
    fallback_reaction = 2

func animate_squirrel(phase: float, _state: int, speed: float,
        direction: Vector3, dt: float) -> void:
    if not presentation_ready or model_instance == null:
        return

    action_lock = maxf(action_lock - dt, 0.0)
    _face_direction(direction)

    var running: bool = direction.length_squared() > 0.01 and speed > 0.15

    if stunned:
        if skeleton_ready:
            _animate_skeleton_stunned(action_lock)
        else:
            _animate_unrigged_fallback(phase, false, action_lock)
        return

    if action_lock > 0.0:
        if skeleton_ready:
            _animate_skeleton_hit(action_lock)
        else:
            _animate_unrigged_fallback(phase, false, action_lock)
        return

    if running:
        current_mode = "run"
    else:
        current_mode = "idle"

    if skeleton_ready:
        _animate_skeleton(phase, running)
    else:
        _animate_unrigged_fallback(phase, running, 0.0)

func _face_direction(direction: Vector3) -> void:
    var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.0001:
        return

    flat = flat.normalized()
    rotation.x = 0.0
    rotation.z = 0.0
    rotation.y = atan2(-flat.x, -flat.z) + MODEL_YAW_OFFSET

func _animate_skeleton(phase: float, running: bool) -> void:
    _reset_skeleton_to_base()

    var wave: float = sin(phase * TAU)
    var wave_2: float = sin(phase * TAU * 2.0)

    if running:
        for bone_index: int in left_leg_bones:
            _set_bone_offset(bone_index, Vector3(wave_2 * 0.34, 0.0, 0.0))
        for bone_index: int in right_leg_bones:
            _set_bone_offset(bone_index, Vector3(-wave_2 * 0.34, 0.0, 0.0))

        for bone_index: int in left_arm_bones:
            _set_bone_offset(bone_index, Vector3(-wave_2 * 0.25, 0.0, 0.0))
        for bone_index: int in right_arm_bones:
            _set_bone_offset(bone_index, Vector3(wave_2 * 0.25, 0.0, 0.0))

        for bone_index: int in spine_bones:
            _set_bone_offset(bone_index, Vector3(0.0, 0.0, wave * 0.045))
        for bone_index: int in head_bones:
            _set_bone_offset(bone_index, Vector3(0.0, 0.0, wave * 0.025))
        for bone_index: int in tail_bones:
            _set_bone_offset(bone_index, Vector3(wave * 0.09, 0.0, wave * 0.06))
    else:
        for bone_index: int in spine_bones:
            _set_bone_offset(bone_index, Vector3(wave * 0.025, 0.0, 0.0))
        for bone_index: int in head_bones:
            _set_bone_offset(bone_index, Vector3(0.0, 0.0, wave * 0.018))
        for bone_index: int in tail_bones:
            _set_bone_offset(bone_index, Vector3(wave * 0.04, 0.0, 0.0))
        for bone_index: int in left_arm_bones:
            _set_bone_offset(bone_index, Vector3(wave * 0.018, 0.0, 0.0))
        for bone_index: int in right_arm_bones:
            _set_bone_offset(bone_index, Vector3(wave * 0.018, 0.0, 0.0))

func _animate_skeleton_hit(remaining: float) -> void:
    _reset_skeleton_to_base()

    var p: float = 1.0 - (remaining / HIT_LENGTH)
    var impulse: float = sin(clampf(p, 0.0, 1.0) * PI)

    for bone_index: int in head_bones:
        _set_bone_offset(bone_index, Vector3(0.0, 0.0, -0.16 * impulse))
    for bone_index: int in spine_bones:
        _set_bone_offset(bone_index, Vector3(0.0, 0.0, -0.10 * impulse))
    for bone_index: int in left_arm_bones:
        _set_bone_offset(bone_index, Vector3(0.16 * impulse, 0.0, 0.0))
    for bone_index: int in right_arm_bones:
        _set_bone_offset(bone_index, Vector3(-0.16 * impulse, 0.0, 0.0))
    for bone_index: int in tail_bones:
        _set_bone_offset(bone_index, Vector3(0.12 * impulse, 0.0, 0.0))

func _animate_skeleton_stunned(remaining: float) -> void:
    _reset_skeleton_to_base()

    var p: float = 1.0 - (remaining / STUNNED_LENGTH)
    var eased: float = 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 3.0)

    for bone_index: int in head_bones:
        _set_bone_offset(bone_index, Vector3(0.0, 0.0, deg_to_rad(-12.0) * eased))
    for bone_index: int in spine_bones:
        _set_bone_offset(bone_index, Vector3(0.0, 0.0, deg_to_rad(-20.0) * eased))
    for bone_index: int in left_arm_bones:
        _set_bone_offset(bone_index, Vector3(deg_to_rad(24.0) * eased, 0.0, 0.0))
    for bone_index: int in right_arm_bones:
        _set_bone_offset(bone_index, Vector3(deg_to_rad(-24.0) * eased, 0.0, 0.0))
    for bone_index: int in left_leg_bones:
        _set_bone_offset(bone_index, Vector3(deg_to_rad(-10.0) * eased, 0.0, 0.0))
    for bone_index: int in right_leg_bones:
        _set_bone_offset(bone_index, Vector3(deg_to_rad(-10.0) * eased, 0.0, 0.0))
    for bone_index: int in tail_bones:
        _set_bone_offset(bone_index, Vector3(deg_to_rad(14.0) * eased, 0.0, 0.0))

func _reset_skeleton_to_base() -> void:
    for bone_index: int in bones:
        skeleton.set_bone_pose_rotation(bone_index, base_rotations[bone_index])

func _set_bone_offset(bone_index: int, euler_offset: Vector3) -> void:
    var base: Quaternion = base_rotations[bone_index]
    skeleton.set_bone_pose_rotation(
        bone_index,
        base * Quaternion.from_euler(euler_offset)
    )

func _animate_unrigged_fallback(phase: float, running: bool, remaining: float) -> void:
    # This branch is intentionally not called skeletal animation.
    var bob: float = 0.0
    var pitch: float = 0.0
    var roll: float = 0.0

    if fallback_reaction == 1 and remaining > 0.0:
        var p: float = 1.0 - (remaining / HIT_LENGTH)
        var impulse: float = sin(clampf(p, 0.0, 1.0) * PI)
        pitch = -0.16 * impulse
        bob = 0.05 * impulse
    elif fallback_reaction == 2:
        pitch = deg_to_rad(-20.0)
        roll = deg_to_rad(8.0)
    elif running:
        bob = sin(phase * TAU * 2.0) * 0.035
        pitch = sin(phase * TAU * 2.0) * 0.08
        roll = sin(phase * TAU) * 0.05
    else:
        bob = sin(phase * TAU) * 0.025

    model_instance.position = base_model_position + Vector3(0.0, bob, 0.0)
    model_instance.rotation = base_model_rotation
    model_instance.rotation.x += pitch
    model_instance.rotation.z += roll

    if fallback_reaction == 1 and remaining <= 0.0:
        fallback_reaction = 0

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

    var bone_count: int = skeleton.get_bone_count()

    for bone_index: int in range(bone_count):
        bones.append(bone_index)
        base_rotations[bone_index] = skeleton.get_bone_pose_rotation(bone_index)

        var raw_name: String = str(skeleton.get_bone_name(bone_index))
        var compact: String = raw_name.to_lower().replace("_", "").replace("-", "").replace(".", "")

        if _name_has_any(compact, ["head", "neck", "face", "skull"]):
            head_bones.append(bone_index)
        elif _name_has_any(compact, ["tail"]):
            tail_bones.append(bone_index)
        elif _name_has_any(compact, ["spine", "chest", "upperbody", "torso", "pelvis", "hips"]):
            spine_bones.append(bone_index)
        elif _is_left(compact) and _name_has_any(compact, ["arm", "forearm", "hand", "shoulder"]):
            left_arm_bones.append(bone_index)
        elif _is_right(compact) and _name_has_any(compact, ["arm", "forearm", "hand", "shoulder"]):
            right_arm_bones.append(bone_index)
        elif _is_left(compact) and _name_has_any(compact, ["leg", "thigh", "calf", "shin", "foot", "ankle"]):
            left_leg_bones.append(bone_index)
        elif _is_right(compact) and _name_has_any(compact, ["leg", "thigh", "calf", "shin", "foot", "ankle"]):
            right_leg_bones.append(bone_index)

func _name_has_any(name: String, patterns: Array[String]) -> bool:
    for pattern: String in patterns:
        if name.contains(pattern):
            return true
    return false

func _is_left(name: String) -> bool:
    return _name_has_any(name, ["left", "lft", "arml", "legl", "handl", "footl"])

func _is_right(name: String) -> bool:
    return _name_has_any(name, ["right", "rgt", "armr", "legr", "handr", "footr"])

func _normalize_model() -> void:
    var bounds: AABB = _collect_bounds()
    if bounds.size.y <= 0.001:
        push_error("[Squirrel3D] Model bounds are empty.")
        return

    var scale_factor: float = TARGET_HEIGHT / bounds.size.y
    model_instance.scale = Vector3.ONE * scale_factor

    var center: Vector3 = bounds.position + bounds.size * 0.5
    model_instance.position = Vector3(
        -center.x * scale_factor,
        -bounds.position.y * scale_factor,
        -center.z * scale_factor
    )

func _collect_bounds() -> AABB:
    var first: bool = true
    var combined: AABB = AABB()

    var meshes: Array[Node] = model_instance.find_children("*", "MeshInstance3D", true, false)

    for child: Node in meshes:
        var mesh_instance: MeshInstance3D = child as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue

        var local_bounds: AABB = mesh_instance.get_aabb()
        var relative: Transform3D = model_instance.global_transform.affine_inverse() * mesh_instance.global_transform

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
