extends SceneTree
const LevelData = preload("res://scripts/level_data.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var output := "/tmp/park-capture"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1280,720)
    var game := load("res://game.tscn").instantiate() as Node3D
    root.add_child(game)
    current_scene = game
    for enemy in get_nodes_in_group("level1_enemy"):
        enemy.set_physics_process(false)
    var player := game.get_node("Player") as Node3D
    player.set_physics_process(false)
    for i in range(20): await process_frame
    for enemy in get_nodes_in_group("level1_enemy"): enemy.set_physics_process(false)
    # Staged presentation views, with identical camera poses to the original
    # park. Hide transient banners only in this capture fixture.
    game.zone_banner.visible=false
    game.get_node("HUD/Message").visible=false
    var camera := game.get_node("Player/Camera3D") as Camera3D
    var report := {"godot":Engine.get_version_info()["string"],"adapter":RenderingServer.get_video_adapter_name(),"views":[],"tree_triangles":0}
    for node in game.get_node("Level1Environment/ParkScenery").get_children():
        if node is MultiMeshInstance3D and String(node.name).begins_with("ParkBatch_oak"):
            report["tree_triangles"]+=node.multimesh.mesh.get_faces().size()/3*node.multimesh.instance_count
    var trees = game.get_node("Level1Environment").trees
    report["trees"] = trees.planted
    report["distant_trees"] = trees.distant_count
    report["cutout_sprigs"] = trees.sprig_count
    var shots := [
        ["01-entry",Vector2i(5,30),Vector2i(9,28),3.0],
        ["02-first-oak",Vector2i(14,27),Vector2i(9,28),3.8],
        ["03-moon-garden",Vector2i(14,15),Vector2i(11,9),2.1],
        ["04-pavilion",Vector2i(17,10),Vector2i(17,4),3.0],
        ["05-courtyard",Vector2i(26,8),Vector2i(34,5),3.0],
        ["06-ruins",Vector2i(37,14),Vector2i(34,5),2.0],
        ["07-legendary-oak",Vector2i(36,21),Vector2i(38,27),5.5],
        ["08-exit",Vector2i(41,28),Vector2i(43,31),1.3],
        ["09-lakeside",Vector2i(15,13),Vector2i(10,9),1.0],
        ["10-outer-wall",Vector2i(12,31),Vector2i(12,34),1.4],
        ["11-grass-detail",Vector2i(11,30),Vector2i(12,31),0.05],
        ["12-path-arch",Vector2i(26,8),Vector2i(29,9),2.0],
        ["13-squirrel",Vector2i(14,28),Vector2i(12,27),1.2],
    ]
    for shot in shots:
        player.position = LevelData.cell_center_world(shot[1])+Vector3.UP*0.9
        player.rotation = Vector3.ZERO
        camera.look_at(LevelData.cell_center_world(shot[2])+Vector3.UP*float(shot[3]))
        for i in range(16): await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+shot[0]+".png")
        report["views"].append({"name":shot[0],"draw_calls":RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)})
        print("PARK CAPTURE: ",shot[0])
    var file := FileAccess.open(output+"/render-budget.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")+"\n")
    file.close()
    game.queue_free()
    for i in range(3): await process_frame
    root.get_node("AudioManager").shutdown()
    quit(0)
