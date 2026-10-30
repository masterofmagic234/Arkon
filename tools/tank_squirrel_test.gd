extends SceneTree

var failures := 0
const REQUIRED_CLIPS = ["idle", "walk", "run", "turn_left", "turn_right", "alert", "aim", "fire", "melee", "charge_tell", "charge", "stomp_tell", "stomp", "recover", "hit", "stunned", "death", "death_forward", "death_back", "death_left", "death_right"]

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        push_error(message)
        failures += 1

func check_coat_materials(visual: Node3D) -> void:
    var surfaces := 0
    for node in visual.model_instance.find_children("*", "MeshInstance3D", true, false):
        for surface in range(node.mesh.get_surface_count()):
            var source := node.mesh.surface_get_material(surface) as StandardMaterial3D
            var active := node.get_active_material(surface) as StandardMaterial3D
            if source == null:
                continue
            surfaces += 1
            check(active != null and active != source, "coat adjustment modified the imported material resource")
            if active == null:
                continue
            check(active.albedo_texture == source.albedo_texture and active.albedo_color == source.albedo_color, "matte coat lost authored fur color")
            check(active.normal_texture == source.normal_texture and active.normal_enabled == source.normal_enabled, "matte coat lost authored normal detail")
            check(active.metallic == 0 and active.metallic_texture == null, "coat regained imported metallic response")
            check(active.metallic_specular <= .10001 and active.roughness >= .9 and active.roughness_texture == null, "coat can regain glossy sky reflections")
    check(surfaces > 0, "coat material check did not inspect an imported surface")

func run() -> void:
    var visual_script = load("res://scripts/squirrel_3d_visual.gd")
    var tank = visual_script.new()
    tank.model_path = "res://assets/level1/characters/tank_squirrel.glb"
    tank.target_height = 2.35
    root.add_child(tank)
    if not tank.setup():
        push_error("Tank setup failed")
        tank.free()
        quit(1)
        return
    check(tank.presentation_ready and tank.skeleton_ready, "tank rig unavailable")
    check_coat_materials(tank)
    for chain in [["BoneRoot","Pelvis","Spine01","Spine02","Neck","Head"],["Spine02","Scapula.L","L_Upperarm","L_Forearm","L_Hand"],["Spine02","Scapula.R","R_Upperarm","R_Forearm","R_Hand"],["Pelvis","L_Thigh","L_Calf","L_Foot"],["Pelvis","R_Thigh","R_Calf","R_Foot"]]:
        for index in range(chain.size()):
            var bone: int=tank.skeleton.find_bone(chain[index])
            check(bone>=0,"missing newly authored guardian joint: "+chain[index])
            if bone>=0 and index>0:check(tank.skeleton.get_bone_parent(bone)==tank.skeleton.find_bone(chain[index-1]),"guardian chain disconnect: "+chain[index])
    check(tank.skeleton.find_bone("Waist")<0,"old split torso branch survived new rig")
    check(tank.left_leg_bones.size() == 3 and tank.right_leg_bones.size() == 3, "thigh/knee/ankle side mapper failed")
    check(tank.left_arm_bones.size() == 3 and tank.right_arm_bones.size() == 3, "shoulder/elbow/paw side mapper failed")
    check(tank.tail_bones.size() == 6, "authored tail chain missing")
    check(tank.imported_animation_names.size() == REQUIRED_CLIPS.size(), "living/directional-defeat clip inventory changed")
    for clip in REQUIRED_CLIPS:
        check(tank.imported_animation_names.has(StringName(clip)), "authored clip missing: " + clip)
    check(absf(tank.model_instance.scale.y * tank._collect_bounds().size.y - 2.35) < .01, "normalized height wrong")
    var arm: int = tank.left_arm_bones[0]
    var rest: Quaternion = tank.skeleton.get_bone_pose_rotation(arm)
    tank.animate_squirrel(0, 0, 2.0, Vector3.FORWARD, .13)
    var moving: Quaternion = tank.skeleton.get_bone_pose_rotation(arm)
    check(rest.angle_to(moving) > .01, "weighted arm locomotion did not advance")
    tank.apply_hit()
    tank.animate_squirrel(0, 0, 0, Vector3.ZERO, .09)
    check(tank.action_lock > 0, "hit reaction missing")
    tank.apply_stunned()
    tank.animate_squirrel(0, 0, 0, Vector3.ZERO, .3)
    check(tank.stunned, "stun reaction missing")
    tank.apply_active()
    check(not tank.stunned and tank.action_lock == 0, "reset did not restore actor")
    var scout = visual_script.new()
    root.add_child(scout)
    check(scout.setup(), "default Scout API regressed")
    check(scout.model_path == "res://scout_rigged.glb", "default skin changed")
    check_coat_materials(scout)
    if failures == 0:
        print("TANK RIG: PASS bones=", tank.skeleton.get_bone_count(), " left_arm=", tank.left_arm_bones, " normalized_height=", tank.model_instance.scale.y * tank._collect_bounds().size.y)
    tank.free(); scout.free()
    quit(0 if failures == 0 else 1)
