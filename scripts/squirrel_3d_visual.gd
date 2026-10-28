extends Node3D
class_name Squirrel3DVisual
## Baked anatomical skin and sampled clips. No runtime reweighting or generic
## Euler bend applied to every bone in an entire limb chain.
const MODEL_PATH := "res://scout_rigged.glb"
const TANK_MODEL_PATH := "res://assets/level1/characters/tank_squirrel.glb"
const TARGET_HEIGHT := 2.15
const MODEL_YAW_OFFSET := PI # Both supplied models are baked to face +Z.
const HIT_LENGTH := .24
const STUNNED_LENGTH := 1.10
const GROUND_CLEARANCE := 0.0
@export_file("*.glb") var model_path: String = MODEL_PATH
@export var target_height := TARGET_HEIGHT
var model_instance: Node3D
var skeleton: Skeleton3D
var imported_animation_player: AnimationPlayer
var imported_animation_names: Array[StringName] = []
var imported_animation_cache: Dictionary = {}
var current_mode := "idle"
var action_lock := 0.0
var animation_clock := 0.0
var stunned := false
var presentation_ready := false
var skeleton_ready := false
var fallback_reaction := 0
var base_model_position := Vector3.ZERO
var base_model_rotation := Vector3.ZERO
var bones: Array[int] = []
var spine_bones: Array[int] = []
var head_bones: Array[int] = []
var left_arm_bones: Array[int] = []
var right_arm_bones: Array[int] = []
var left_leg_bones: Array[int] = []
var right_leg_bones: Array[int] = []
var tail_bones: Array[int] = []
var base_rotations: Dictionary = {}
var action: StringName = &"auto"
var action_progress := -1.0
var action_time := 0.0
var _defeated := false
var _has_facing := false
var _last_external_frame := -100
var _externally_driven := false
var _throw_prop: Node3D
var _active_clip: StringName = &""
const LOOPS = [&"idle",&"walk",&"run",&"aim",&"recover",&"stunned"]

func setup(scene_override: Node3D = null) -> bool:
    if presentation_ready: return skeleton_ready
    if scene_override != null:
        model_instance = scene_override
    else:
        var packed := load(model_path) as PackedScene
        if packed == null: push_error("[Squirrel3D] Missing model: " + model_path); return false
        model_instance = packed.instantiate() as Node3D
    if model_instance == null: return false
    add_child(model_instance)
    skeleton = model_instance.find_child("Skeleton3D",true,false) as Skeleton3D
    _discover_imported_animations()
    _normalize_model()
    _prepare_android_materials()
    base_model_position = model_instance.position
    base_model_rotation = model_instance.rotation
    if skeleton == null:
        push_error("[Squirrel3D] A genuinely skinned rig is required: " + model_path)
        return false
    skeleton.show_rest_only = false
    skeleton.reset_bone_poses()
    _build_bone_map()
    _make_throw_prop()
    skeleton_ready = true
    presentation_ready = true
    print("[Squirrel3D] Anatomical rig: ",model_path," bones=",bones.size()," tail=",tail_bones.size()," clips=",imported_animation_names.size())
    return true

func _discover_imported_animations() -> void:
    imported_animation_names.clear()
    imported_animation_cache.clear()
    for candidate in model_instance.find_children("*","AnimationPlayer",true,false):
        if imported_animation_player == null: imported_animation_player = candidate
        for library_name in candidate.get_animation_library_list():
            var library: AnimationLibrary = candidate.get_animation_library(library_name)
            for animation_name in library.get_animation_list():
                imported_animation_names.append(animation_name)
                var clip := library.get_animation(animation_name)
                clip.loop_mode = Animation.LOOP_LINEAR if animation_name in LOOPS else Animation.LOOP_NONE
    if imported_animation_player != null:
        imported_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        imported_animation_player.active = true
        imported_animation_player.stop()

func set_action(value: StringName, phase_progress: float = -1.0) -> void:
    if value != action:
        action = value
        action_time = 0.0
    action_progress = phase_progress
    if value == &"defeated" and not _defeated: apply_defeated()

func apply_active() -> void:
    if not presentation_ready: return
    stunned = false; _defeated = false; action_lock = 0.0; fallback_reaction = 0
    action = &"auto"; action_progress = -1; action_time = 0; animation_clock = 0
    current_mode = "idle"; visible = true; _has_facing = false; _active_clip = &""
    model_instance.position = base_model_position
    model_instance.rotation = base_model_rotation
    skeleton.reset_bone_poses()
    if imported_animation_player != null: imported_animation_player.stop()

func apply_hit() -> void:
    if not presentation_ready or stunned: return
    action_lock = HIT_LENGTH
    _active_clip = &""
    fallback_reaction = 1

func apply_stunned() -> void:
    if not presentation_ready: return
    stunned = true; action_lock = STUNNED_LENGTH; fallback_reaction = 2

func apply_defeated() -> void:
    if not presentation_ready or _defeated: return
    _defeated = true; stunned = true; action_lock = 0; action_time = 0
    action = &"defeated"; fallback_reaction = 2

func _process(delta: float) -> void:
    # Truly ambient character props may breathe, but never perform gameplay AI.
    # A live guard's explicit physics update always owns its animation clock.
    if presentation_ready and not _externally_driven:
        _animate(0,Vector3.ZERO,delta)

func animate_squirrel(_phase: float, _state: int, speed: float, direction: Vector3, dt: float) -> void:
    _last_external_frame = Engine.get_physics_frames()
    _externally_driven = true
    _animate(speed,direction,dt)

func _animate(speed: float,direction: Vector3,dt: float) -> void:
    if not presentation_ready or imported_animation_player == null: return
    animation_clock += dt
    action_time += dt
    action_lock = maxf(0,action_lock-dt)
    if not _defeated: _face_direction(direction,dt)
    var clip: StringName = &"idle"
    var rate := 1.0
    var progress := -1.0
    if _defeated:
        clip = &"death"
    elif stunned:
        clip = &"stunned"
    elif action_lock > 0:
        clip = &"hit"
    else:
        match action:
            &"alert": clip = &"alert"
            &"aim",&"ranged_windup": clip = &"aim"
            &"fire",&"shoot",&"ranged_fire": clip = &"fire"
            &"melee",&"melee_tell",&"melee_strike": clip = &"melee"
            &"windup": clip = &"charge_tell"
            &"charge": clip = &"charge"
            &"stomp_windup": clip = &"stomp_tell"
            &"shockwave",&"stomp": clip = &"stomp"
            &"recover": clip = &"recover"
            _:
                if speed > .15: clip = &"run" if speed > 1.65 else &"walk"
        if action_progress >= 0 and clip not in LOOPS: progress = action_progress
    if clip in [&"walk",&"run"]:
        # Clip stance travels 2*amplitude in 60% of a cycle. Scale cadence from
        # real horizontal speed and actual normalized size instead of phase time.
        var source_height := .8525 if model_path == TANK_MODEL_PATH else 1.85
        var amplitude := (.065 if clip==&"walk" else .10) if model_path==TANK_MODEL_PATH else (.19 if clip==&"walk" else .24)
        var duration := .72 if clip==&"walk" else .46
        var nominal_speed := 2*amplitude*(target_height/source_height)/(.60*duration)
        rate = clampf(speed/maxf(.1,nominal_speed),.35,2.4)
    _play_clip(clip,dt*rate,progress)
    if is_instance_valid(_throw_prop):
        var early_throw := clip==&"fire" and imported_animation_player.current_animation_position < imported_animation_player.current_animation_length*.42
        _throw_prop.visible = not stunned and (clip==&"aim" or early_throw)

func _play_clip(clip: StringName,delta: float,progress: float = -1) -> void:
    if not imported_animation_names.has(clip):
        # Old authoring previews remain inspectable; production 1.47 models
        # have every required clip and the rig test rejects a missing one.
        clip = &"idle" if imported_animation_names.has(&"idle") else imported_animation_names[0]
    if _active_clip != clip:
        imported_animation_player.play(clip,.10 if clip not in [&"hit",&"death"] else .06)
        _active_clip = clip
    elif not imported_animation_player.is_playing() and clip in LOOPS:
        imported_animation_player.play(clip,.10)
    current_mode = str(clip)
    if not imported_animation_player.is_playing() and clip not in LOOPS:
        imported_animation_player.seek(imported_animation_player.get_animation(clip).length,true)
        return
    imported_animation_player.advance(delta)
    if progress >= 0:
        imported_animation_player.seek(clampf(progress,0,1)*imported_animation_player.current_animation_length,true)

func _face_direction(direction: Vector3,dt: float = .0166667) -> void:
    var flat := Vector3(direction.x,0,direction.z)
    if flat.length_squared() < .0001: return
    var target := atan2(-flat.x,-flat.z)+MODEL_YAW_OFFSET
    rotation.x = 0; rotation.z = 0
    rotation.y = target if not _has_facing else lerp_angle(rotation.y,target,1-exp(-12*dt))
    _has_facing = true

func _build_bone_map() -> void:
    bones.clear();spine_bones.clear();head_bones.clear();left_arm_bones.clear();right_arm_bones.clear();left_leg_bones.clear();right_leg_bones.clear();tail_bones.clear();base_rotations.clear()
    for i in range(skeleton.get_bone_count()):
        bones.append(i);base_rotations[i]=skeleton.get_bone_pose_rotation(i)
        var n := str(skeleton.get_bone_name(i)).to_lower().replace("_","").replace(".","")
        if "tail" in n: tail_bones.append(i)
        elif n in ["head","neck","necktwist01","necktwist02"]: head_bones.append(i)
        elif n in ["pelvis","spine","chest","spine01","spine02"]: spine_bones.append(i)
        elif n in ["armupperl","armforel","handl","lupperarm","lforearm","lhand"]: left_arm_bones.append(i)
        elif n in ["armupperr","armforer","handr","rupperarm","rforearm","rhand"]: right_arm_bones.append(i)
        elif n in ["legthighl","legshinl","footl","lthigh","lcalf","lfoot"]: left_leg_bones.append(i)
        elif n in ["legthighr","legshinr","footr","rthigh","rcalf","rfoot"]: right_leg_bones.append(i)


func throw_origin() -> Vector3:
    if skeleton != null and is_instance_valid(_throw_prop):
        var hand := skeleton.find_bone("hand.R")
        if hand >= 0:
            skeleton.force_update_all_bone_transforms()
            return skeleton.global_transform*skeleton.get_bone_global_pose(hand)*_throw_prop.position
    return global_position+Vector3.UP*target_height*.65

func make_thrown_visual() -> Node3D:
    if not is_instance_valid(_throw_prop): return null
    skeleton.force_update_all_bone_transforms()
    # Duplicate just this small prop; Mesh and Material resources stay shared.
    # The projectile parent owns motion. Preserve the exact held world scale
    # and orientation so its first rendered frame is a continuous handoff.
    var result := _throw_prop.duplicate() as Node3D
    result.transform = Transform3D(_throw_prop.global_basis,Vector3.ZERO)
    result.visible = true
    return result

func _make_throw_prop() -> void:
    if model_path==TANK_MODEL_PATH or skeleton.find_bone("hand.R")<0: return
    var hand := BoneAttachment3D.new()
    hand.name = "PreparedConeHand"
    hand.bone_name = &"hand.R"
    skeleton.add_child(hand)
    _throw_prop = Node3D.new()
    _throw_prop.name = "PreparedPineCone"
    _throw_prop.position = Vector3(0,-.015,.045)
    _throw_prop.rotation.x = 1.92
    hand.add_child(_throw_prop)
    var bark := StandardMaterial3D.new()
    bark.albedo_color=Color("8d613d");bark.roughness=.95;bark.metallic_specular=.05
    var body := MeshInstance3D.new()
    var egg := SphereMesh.new();egg.radius=.039;egg.height=.125;egg.radial_segments=10;egg.rings=6
    body.mesh=egg;body.material_override=bark;_throw_prop.add_child(body)
    # One merged low-poly scale surface gives the held ammunition a pine-cone
    # silhouette, rather than a floating smooth ball or an invisible firearm.
    var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ring in range(4):
        var y: float=-.045+ring*.028
        var radius: float=.036*sin((ring+1.0)/5.0*PI)
        for piece in range(7):
            var angle: float=(piece+ring*.5)*TAU/7
            var outward := Vector3(cos(angle),0,sin(angle))
            var side := Vector3(-sin(angle),0,cos(angle))*.014
            var p := outward*radius+Vector3.UP*y
            var tip := p+outward*.012+Vector3.UP*.025
            for point in [p-side,p+side,tip]:tool.add_vertex(point)
    tool.generate_normals()
    var scales := MeshInstance3D.new();scales.mesh=tool.commit();scales.material_override=bark;_throw_prop.add_child(scales)
    _throw_prop.hide()

func _prepare_android_materials() -> void:
    for node in model_instance.find_children("*","MeshInstance3D",true,false):
        if node.mesh == null: continue
        for index in range(node.mesh.get_surface_count()):
            var source := node.mesh.surface_get_material(index) as StandardMaterial3D
            if source == null: continue
            var material := source.duplicate() as StandardMaterial3D
            material.metallic=0;material.metallic_texture=null;material.metallic_specular=.10
            material.roughness=.92;material.roughness_texture=null
            material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED;material.emission_enabled=false
            material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
            node.set_surface_override_material(index,material)

func _normalize_model() -> void:
    var bounds := _collect_bounds()
    if bounds.size.y <= .001: push_error("[Squirrel3D] Empty mesh bounds"); return
    var factor := target_height/bounds.size.y
    var anchor := bounds.position+bounds.size*.5
    # The big curled tail is outside the actor capsule. Center the torso over
    # its physical body using the real pelvis, not the whole tail AABB center.
    if skeleton != null:
        var pelvis := skeleton.find_bone("Pelvis")
        if pelvis < 0: pelvis = skeleton.find_bone("pelvis")
        if pelvis >= 0:
            anchor = model_instance.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(pelvis).origin
    model_instance.scale=Vector3.ONE*factor
    model_instance.position=Vector3(-anchor.x*factor,-bounds.position.y*factor,-anchor.z*factor)

func _collect_bounds() -> AABB:
    var first := true
    var combined := AABB()
    for node in model_instance.find_children("*","MeshInstance3D",true,false):
        if node.mesh == null: continue
        var bounds: AABB = node.get_aabb()
        var relative: Transform3D = model_instance.global_transform.affine_inverse()*node.global_transform
        for corner in range(8):
            var p := bounds.position+Vector3(bounds.size.x if corner&1 else 0,bounds.size.y if corner&2 else 0,bounds.size.z if corner&4 else 0)
            var point: Vector3 = relative*p
            if first: combined=AABB(point,Vector3.ZERO);first=false
            else:combined=combined.expand(point)
    return combined
