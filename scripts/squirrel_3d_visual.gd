extends Node3D
class_name Squirrel3DVisual

# ACORN HUNTER — rigged 3D Scout presentation.
# The imported GLB provides mesh + Skeleton3D. This wrapper owns gameplay yaw.
# Animation is authored at runtime as real Skeleton3D rotation tracks.

const MODEL_PATH := "res://cartoon squirrel 3d model1.glb"
const TARGET_HEIGHT: float = 1.85
const MODEL_YAW_OFFSET: float = 0.0

const IDLE_LENGTH: float = 1.20
const RUN_LENGTH: float = 0.56
const HIT_LENGTH: float = 0.18
const STUNNED_LENGTH: float = 0.60

var model_instance: Node3D = null
var skeleton: Skeleton3D = null
var animation_player: AnimationPlayer = null
var animation_library: AnimationLibrary = null

var current_mode: String = "idle"
var action_lock: float = 0.0
var stunned: bool = false
var skeleton_ready: bool = false

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

    var packed: PackedScene = load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("[Squirrel3D] Could not load %s" % MODEL_PATH)
        return false

    model_instance = packed.instantiate() as Node3D
    if model_instance == null:
        push_error("[Squirrel3D] Could not instantiate %s" % MODEL_PATH)
        return false

    add_child(model_instance)

    # Do not let an imported AnimationPlayer/autoplay clip fight our gameplay
    # controller. We make one dedicated player for the runtime skeletal clips.
    var imported_players: Array[Node] = model_instance.find_children("*", "AnimationPlayer", true, false)
    for candidate: Node in imported_players:
        var imported: AnimationPlayer = candidate as AnimationPlayer
        if imported == null:
            continue
        imported.stop(true)
        imported.autoplay = &""

    skeleton = model_instance.find_child("Skeleton3D", true, false) as Skeleton3D
    if skeleton == null:
        push_error("[Squirrel3D] Rigged model has no Skeleton3D.")
        return false

    _normalize_model()
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

    skeleton_ready = true

    print(
        "[Squirrel3D] Rig ready. bones=", skeleton.get_bone_count(),
        " head=", head_bones.size(),
        " arms=", left_arm_bones.size() + right_arm_bones.size(),
        " legs=", left_leg_bones.size() + right_leg_bones.size(),
        " tail=", tail_bones.size()
    )

    return true

func apply_active() -> void:
    stunned = false
    action_lock = 0.0
    current_mode = "idle"
    visible = true
    if animation_player != null:
        animation_player.speed_scale = 1.0
    _play_animation("Scout_Idle")

func apply_hit() -> void:
    if not skeleton_ready or stunned:
        return
    action_lock = HIT_LENGTH
    _play_animation("Scout_Hit")

func apply_stunned() -> void:
    if not skeleton_ready:
        return
    stunned = true
    action_lock = STUNNED_LENGTH
    _play_animation("Scout_Stunned")

func animate_squirrel(_phase: float, _state: int, speed: float,
        direction: Vector3, dt: float) -> void:
    if not skeleton_ready or model_instance == null:
        return

    action_lock = maxf(action_lock - dt, 0.0)

    # Gameplay direction always belongs to the outer wrapper.
    _face_direction(direction)

    if stunned or action_lock > 0.0:
        return

    var running: bool = direction.length_squared() > 0.01 and speed > 0.15

    if running:
        if current_mode != "run":
            current_mode = "run"
            animation_player.speed_scale = clampf(speed / 3.4, 0.75, 1.35)
            _play_animation("Scout_Run")
    elif current_mode != "idle":
        current_mode = "idle"
        animation_player.speed_scale = 1.0
        _play_animation("Scout_Idle")

func _face_direction(direction: Vector3) -> void:
    var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.0001:
        return
    flat = flat.normalized()
    # 360-degree yaw lives on the wrapper, never on the animated skeleton.
    rotation.y = atan2(-flat.x, -flat.z) + MODEL_YAW_OFFSET

func _play_animation(animation_name: StringName) -> void:
    if animation_player == null or animation_library == null:
        return
    if not animation_library.has_animation(animation_name):
        return
    if animation_player.current_animation == animation_name and animation_player.is_playing():
        return
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

    var bone_count: int = skeleton.get_bone_count()
    for bone_index: int in range(bone_count):
        bones.append(bone_index)
        base_rotations[bone_index] = skeleton.get_bone_pose_rotation(bone_index)

        var raw_name: String = str(skeleton.get_bone_name(bone_index))
        var name: String = raw_name.to_lower()
        var compact: String = name.replace("_", "").replace("-", "").replace(".", "")

        if _name_has_any(compact, ["head", "neck", "face", "skull"]):
            head_bones.append(bone_index)
        elif _name_has_any(compact, ["tail", "tail01", "tail02", "tail03", "tail04"]):
            tail_bones.append(bone_index)
        elif _name_has_any(compact, ["spine", "chest", "upperbody", "torso", "pelvis", "hips"]):
            spine_bones.append(bone_index)
        elif _is_left(compact) and _name_has_any(compact, ["arm", "upperarm", "forearm", "hand", "shoulder"]):
            left_arm_bones.append(bone_index)
        elif _is_right(compact) and _name_has_any(compact, ["arm", "upperarm", "forearm", "hand", "shoulder"]):
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

func _build_skeletal_animations() -> void:
    _add_animation(&"Scout_Idle", IDLE_LENGTH, true, 0)
    _add_animation(&"Scout_Run", RUN_LENGTH, true, 1)
    _add_animation(&"Scout_Hit", HIT_LENGTH, false, 2)
    _add_animation(&"Scout_Stunned", STUNNED_LENGTH, false, 3)

func _add_animation(animation_name: StringName, length: float,
        looped: bool, pose_kind: int) -> void:
    var animation: Animation = Animation.new()
    animation.length = length
    animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
    animation.step = 1.0 / 30.0

    var skeleton_path: String = str(model_instance.get_path_to(skeleton))

    for bone_index: int in bones:
        var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
        var bone_name: String = str(skeleton.get_bone_name(bone_index))
        animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone_name]))

        _insert_pose_key(animation, track, 0.0, bone_index, pose_kind, length)
        _insert_pose_key(animation, track, length * 0.5, bone_index, pose_kind, length)
        _insert_pose_key(animation, track, length, bone_index, pose_kind, length)

    var error: Error = animation_library.add_animation(animation_name, animation)
    if error != OK:
        push_error("[Squirrel3D] Could not add %s: %s" % [animation_name, error])

func _insert_pose_key(animation: Animation, track: int, time: float,
        bone_index: int, pose_kind: int, length: float) -> void:
    var rotation: Quaternion = base_rotations[bone_index]

    match pose_kind:
        0:
            rotation = _idle_rotation(bone_index, time, length)
        1:
            rotation = _run_rotation(bone_index, time, length)
        2:
            rotation = _hit_rotation(bone_index, time, length)
        3:
            rotation = _stunned_rotation(bone_index, time, length)

    animation.rotation_track_insert_key(track, time, rotation)

func _idle_rotation(bone_index: int, time: float, length: float) -> Quaternion:
    var wave: float = sin((time / length) * TAU)
    var offset: Vector3 = Vector3.ZERO

    if spine_bones.has(bone_index):
        offset.x = wave * 0.025
    elif head_bones.has(bone_index):
        offset.z = wave * 0.018
    elif tail_bones.has(bone_index):
        offset.x = wave * 0.040
    elif left_arm_bones.has(bone_index) or right_arm_bones.has(bone_index):
        offset.x = wave * 0.018

    return base_rotations[bone_index] * Quaternion.from_euler(offset)

func _run_rotation(bone_index: int, time: float, length: float) -> Quaternion:
    var wave: float = sin((time / length) * TAU)
    var offset: Vector3 = Vector3.ZERO

    if left_leg_bones.has(bone_index):
        offset.x = wave * 0.34
    elif right_leg_bones.has(bone_index):
        offset.x = -wave * 0.34
    elif left_arm_bones.has(bone_index):
        offset.x = -wave * 0.25
    elif right_arm_bones.has(bone_index):
        offset.x = wave * 0.25
    elif spine_bones.has(bone_index):
        offset.z = wave * 0.045
    elif head_bones.has(bone_index):
        offset.z = wave * 0.025
    elif tail_bones.has(bone_index):
        offset.x = wave * 0.09
        offset.z = wave * 0.06

    return base_rotations[bone_index] * Quaternion.from_euler(offset)

func _hit_rotation(bone_index: int, time: float, length: float) -> Quaternion:
    var p: float = clampf(time / length, 0.0, 1.0)
    var impulse: float = sin(p * PI)
    var offset: Vector3 = Vector3.ZERO

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

    return base_rotations[bone_index] * Quaternion.from_euler(offset)

func _stunned_rotation(bone_index: int, time: float, length: float) -> Quaternion:
    var p: float = clampf(time / length, 0.0, 1.0)
    var eased: float = 1.0 - pow(1.0 - p, 3.0)
    var offset: Vector3 = Vector3.ZERO

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

    return base_rotations[bone_index] * Quaternion.from_euler(offset)

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
