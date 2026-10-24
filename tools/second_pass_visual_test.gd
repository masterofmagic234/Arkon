extends SceneTree
# Native pixel probe: a muzzle's transform must not displace the next tracer.
func _init() -> void: call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Run this pixel probe with a native display")
        quit(1)
        return
    var viewport := SubViewport.new()
    viewport.size=Vector2i(320,200)
    viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var effects := preload("res://scripts/level3_effects.gd").new()
    viewport.add_child(effects)
    effects.set_process(false)
    effects.muzzle(Vector2(30,40),.5)
    effects.trace(Vector2(180,120),Vector2(280,120),Color.WHITE)
    effects.queue_redraw()
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var picture := viewport.get_texture().get_image()
    var pixel := picture.get_pixel(240,120)
    # The thin antialiased line has partial pixel coverage (about 0.73 on Mesa).
    if pixel.r<.5 or pixel.g<.5 or pixel.b<.5 or pixel.a<.4:
        push_error("SECOND PASS VISUAL: tracer moved away from its world position: "+str(pixel))
        quit(1)
        return
    viewport.queue_free()
    await process_frame
    print("SECOND PASS VISUAL: PASS — native tracer stays at its world position after a transformed muzzle")
    quit(0)
