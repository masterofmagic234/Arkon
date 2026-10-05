extends SceneTree

const RaceAuthoredTrackData = preload(
    "res://scripts/race_authored_track_data.gd"
)
const RaceLevelData = preload(
    "res://scripts/race_level_data.gd"
)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in [
        "race_left",
        "race_right",
        "race_accel",
        "race_brake"
    ]:
        if not InputMap.has_action(action):
            _fail(
                "Missing Level 2 InputMap action: %s"
                % action
            )
            return

    if str(ProjectSettings.get_setting(
        "application/run/main_scene",
        ""
    )) != "res://game.tscn":
        _fail("Full game boot scene is not Level 1")
        return

    for path in [
        "res://scenes/level2.tscn",
        "res://scenes/level2_racer.tscn",
        "res://scenes/level2_racer_3d.tscn",
        "res://scripts/race_director.gd",
        "res://scripts/level2_racer.gd",
        "res://scripts/components/race_movement_component.gd",
        "res://scripts/components/race_ai_component.gd",
        "res://scripts/race_authored_track_data.gd",
        "res://scripts/race_track_view.gd",
        "res://scripts/race_minimap_nes.gd",
        "res://scripts/level2_racer_visual_3d.gd",
        "res://scripts/level2_mobile_input.gd",
        "res://nfs_shift_psp_-_london_short.glb",
        "res://240_sx_nfs_pro_street.glb"
    ]:
        if not ResourceLoader.exists(path):
            _fail(
                "Missing Level 2 authored resource: %s"
                % path
            )
            return

    var centerline: PackedVector3Array = (
        RaceAuthoredTrackData.build_centerline()
    )
    if centerline.size() < 100:
        _fail(
            "London centerline contains too few points: %d"
            % centerline.size()
        )
        return

    var track_length := 0.0
    for i in centerline.size():
        track_length += (
            centerline[
                (i + 1) % centerline.size()
            ]
            - centerline[i]
        ).length()

    if track_length < 430.0 or track_length > 540.0:
        _fail(
            "London authored track length is unexpected after world-scale correction: %.2f"
            % track_length
        )
        return
    if not str(FileAccess.get_file_as_string(
        "res://scripts/race_authored_track_data.gd"
    )).contains("const TRACK_SCALE := 10.20"):
        _fail("London authored track scale regression detected")
        return

    var scene := load(
        "res://scenes/level2.tscn"
    ) as PackedScene
    if scene == null:
        _fail("Level 2 scene failed to load")
        return

    var root := scene.instantiate()
    get_root().add_child(root)

    for _i in range(8):
        await process_frame

    var track_view := root.get_node_or_null(
        "Track"
    ) as Node3D
    var authored_track := track_view.get_node_or_null(
        "AuthoredTrack"
    ) as Node3D if track_view != null else null
    var road_collision := track_view.get_node_or_null(
        "RoadCollision"
    ) as StaticBody3D if track_view != null else null

    if authored_track == null:
        root.queue_free()
        _fail(
            "Authored London GLB was not instantiated"
        )
        return

    if road_collision == null:
        root.queue_free()
        _fail(
            "Authored London road collision is missing"
        )
        return

    if road_collision.get_child_count() < 60:
        root.queue_free()
        _fail(
            "Authored London road collision has too few shapes: %d"
            % road_collision.get_child_count()
        )
        return

    var player := root.get_node_or_null(
        "Racers/Player"
    ) as VehicleBody3D
    if player == null:
        root.queue_free()
        _fail(
            "Level 2 Player is not VehicleBody3D"
        )
        return

    var movement := player.get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent
    if movement == null:
        root.queue_free()
        _fail(
            "Level 2 player movement component missing"
        )
        return

    var visual := player.get_node_or_null(
        "Visuals"
    ) as Node3D
    if (
        visual == null
        or not visual.has_method("is_model_ready")
    ):
        root.queue_free()
        _fail(
            "240SX visual component missing"
        )
        return

    for _i in range(24):
        await process_frame
        if bool(visual.call("is_model_ready")):
            break

    if not bool(visual.call("is_model_ready")):
        root.queue_free()
        _fail("240SX GLB did not finish loading")
        return

    if absf(
        movement.track_length
        - track_length
    ) > 0.5:
        root.queue_free()
        _fail(
            "Player path length mismatch: %.3f vs %.3f"
            % [
                movement.track_length,
                track_length
            ]
        )
        return

    var wheels := player.find_children(
        "*",
        "VehicleWheel3D",
        true,
        false
    )
    if wheels.size() != 4:
        root.queue_free()
        _fail(
            "Player wheel count is %d, expected 4"
            % wheels.size()
        )
        return

    var space_state: PhysicsDirectSpaceState3D = (
        root.get_world_3d().direct_space_state
    )
    var ray_hits := 0
    for wheel_node in wheels:
        var wheel := wheel_node as VehicleWheel3D
        if wheel == null:
            continue
        var query := PhysicsRayQueryParameters3D.create(
            wheel.global_position,
            wheel.global_position
            + Vector3.DOWN * 2.0,
            1
        )
        query.exclude = [player.get_rid()]
        if not space_state.intersect_ray(query).is_empty():
            ray_hits += 1

    if ray_hits < 2:
        root.queue_free()
        _fail(
            "Imported London road is not under the starting wheels: %d/4 hits"
            % ray_hits
        )
        return

    player.start_race()
    movement.set_external_input(
        0.0,
        1.0,
        0.0
    )

    var start := player.global_position
    for _i in range(120):
        await physics_frame

    movement.clear_external_input()

    var delta_position := (
        player.global_position - start
    )
    var horizontal := Vector2(
        delta_position.x,
        delta_position.z
    ).length()
    var forward_speed := movement.get_forward_speed()

    if (
        player.global_position.y < -2.0
        or horizontal < 4.0
        or forward_speed < 4.0
    ):
        root.queue_free()
        _fail(
            "240SX does not move on authored London road: "
            + "y=%.3f horizontal=%.3f forward=%.3f"
            % [
                player.global_position.y,
                horizontal,
                forward_speed
            ]
        )
        return

    var heading_before := -player.global_transform.basis.z
    heading_before.y = 0.0
    if heading_before.length_squared() > 0.0001:
        heading_before = heading_before.normalized()

    movement.set_external_input(
        1.0,
        1.0,
        0.0
    )
    for _i in range(45):
        await physics_frame

    movement.clear_external_input()

    var heading_after := -player.global_transform.basis.z
    heading_after.y = 0.0
    if heading_after.length_squared() > 0.0001:
        heading_after = heading_after.normalized()

    if heading_before.dot(heading_after) > 0.999:
        root.queue_free()
        _fail(
            "240SX steering produced no heading response"
        )
        return

    root.queue_free()

    print(
        "LEVEL2 SMOKE TEST: PASS; authored_london=true "
        + "points=%d length=%.2f road_shapes=%d"
        % [
            centerline.size(),
            track_length,
            road_collision.get_child_count()
        ]
    )
    quit(0)

func _fail(message: String) -> void:
    push_error(
        "LEVEL2 SMOKE TEST: " + message
    )
    quit(1)
