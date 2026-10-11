extends SceneTree
# Offline native authoring: retain the supplied wall/grain pixels and cache
# thousands of immutable floor drawing commands into one lit texture.
func _init() -> void: call_deferred("_run")
func _run() -> void:
    root.size=Vector2i(1088,782)
    root.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    var floor_ := preload("res://scripts/level3_layout_floor.gd").new()
    floor_.authoring_bake=true
    floor_.position=Vector2(160,100)
    root.add_child(floor_)
    for i in range(4): await process_frame
    await RenderingServer.frame_post_draw
    var output := "res://assets/level3/materials/diner_floor.png"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
    var result := root.get_texture().get_image().save_png(output)
    if result!=OK:
        push_error("LEVEL 3 FLOOR BAKE: save failed")
        quit(1)
        return
    print("LEVEL 3 FLOOR BAKE: PASS — 1088 × 782; supplied wall/grain assets; one runtime texture")
    floor_.queue_free()
    await process_frame
    root.get_node("AudioManager").shutdown()
    OS.delay_msec(80)
    quit(0)
