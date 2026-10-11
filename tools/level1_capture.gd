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
    for i in range(20): await process_frame
    for enemy in get_nodes_in_group("level1_enemy"):
        enemy.set_physics_process(false)
    var player := game.get_node("Player") as Node3D
    player.set_physics_process(false)
    var camera := game.get_node("Player/Camera3D") as Camera3D
    var shots := [
        ["01-entry",Vector2i(5,30),Vector2i(9,28),3.0],
        ["02-first-oak",Vector2i(14,27),Vector2i(9,28),3.8],
        ["03-moon-garden",Vector2i(14,15),Vector2i(11,9),2.1],
        ["04-pavilion",Vector2i(17,10),Vector2i(17,4),3.0],
        ["05-courtyard",Vector2i(26,8),Vector2i(34,5),3.0],
        ["06-ruins",Vector2i(37,14),Vector2i(34,5),2.0],
        ["07-legendary-oak",Vector2i(36,21),Vector2i(38,27),5.5],
        ["08-exit",Vector2i(41,28),Vector2i(43,31),1.3],
    ]
    for shot in shots:
        player.position = LevelData.cell_center_world(shot[1])+Vector3.UP*0.9
        player.rotation = Vector3.ZERO
        camera.look_at(LevelData.cell_center_world(shot[2])+Vector3.UP*float(shot[3]))
        for i in range(5): await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+shot[0]+".png")
        print("PARK CAPTURE: ",shot[0])
    game.queue_free()
    for i in range(3): await process_frame
    root.get_node("AudioManager").shutdown()
    quit(0)
