extends SceneTree

var failures := 0

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        push_error(message)
        failures += 1

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
    check(tank.skeleton.get_bone_count() >= 78, "source rig lost")
    check(tank.left_leg_bones.size() == 1 and tank.right_leg_bones.size() == 1, "leg side mapper failed")
    check(tank.left_arm_bones.size() == 1 and tank.right_arm_bones.size() == 1, "arm side mapper failed")
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
    if failures == 0:
        print("TANK RIG: PASS bones=", tank.skeleton.get_bone_count(), " left_arm=", tank.left_arm_bones, " normalized_height=", tank.model_instance.scale.y * tank._collect_bounds().size.y)
    tank.free(); scout.free()
    quit(0 if failures == 0 else 1)
