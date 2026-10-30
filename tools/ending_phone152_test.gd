extends SceneTree
## Inspect actual shaped labels and container bounds, not just a clipped image.
const ENDING := "res://scenes/ending_cutscene.tscn"
const PixelStyle := preload("res://scripts/pixel_interface_theme.gd")
const Teardown := preload("res://tools/level3_test_teardown.gd")
var output := "user://ending-phone152"
var visual := false
var failures: Array[String] = []
var scene: Control
var report := {"cases":[],"captures":[],"source_hashes":{},"failures":[],"native":false}

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual":visual=true
        elif arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if ok:return
    failures.append(message)
    push_error("ENDING PHONE152: "+message)

func advance() -> void:
    await process_frame
    if visual:
        RenderingServer.call_deferred("force_draw",true)
        await RenderingServer.frame_post_draw

func settled() -> void:
    # A resized Container and a changed font each invalidate minimum size;
    # inspect after the production layout queue has completed both passes.
    for i in range(4):await advance()

func global_rect(control: Control) -> Rect2:
    return pixel_transform(control)*Rect2(Vector2.ZERO,control.size)

func pixel_transform(control: Control) -> Transform2D:
    return root.get_stretch_transform()*control.get_global_transform_with_canvas()

func rect_array(rect: Rect2) -> Array:
    return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func inside(inner: Rect2, outer: Rect2, tolerance := 1.0) -> bool:
    return inner.position.x>=outer.position.x-tolerance and inner.position.y>=outer.position.y-tolerance and inner.end.x<=outer.end.x+tolerance and inner.end.y<=outer.end.y+tolerance

func inspect_label(label: Label, bubble: Control, display: Control, context: String) -> Dictionary:
    var bounds := global_rect(label)
    var bubble_bounds := global_rect(bubble)
    check(inside(bounds,bubble_bounds),context+": label rect inside its actual bubble")
    check(inside(bounds,global_rect(display)),context+": label rect inside phone display")
    check(label.get_line_count()<=label.get_visible_line_count(),context+": every shaped line visible")
    var glyphs := 0
    var expected_glyphs := 0
    var glyph_bounds: Array = []
    var glyph_union := Rect2()
    for index in range(label.text.length()):
        if label.text[index] in [" ","\n","\t"]:continue
        expected_glyphs+=1
        var glyph: Rect2=label.get_character_bounds(index)
        check(glyph.size.x>0 and glyph.size.y>0,context+": nonblank character "+str(index)+" has an actual shaped glyph")
        if glyph.size.x<=0 or glyph.size.y<=0:continue
        glyphs+=1
        check(inside(glyph,Rect2(Vector2.ZERO,label.size),1.25),context+": shaped glyph "+str(index)+" inside label, not clipped offscreen")
        var glyph_global: Rect2=pixel_transform(label)*glyph
        check(inside(glyph_global,bubble_bounds,1.25),context+": shaped glyph "+str(index)+" inside bubble")
        glyph_bounds.append({"index":index,"character":label.text[index],"rect":rect_array(glyph_global)})
        glyph_union=glyph_global if glyphs==1 else glyph_union.merge(glyph_global)
    check(glyphs==expected_glyphs and glyphs>0,context+": actual font covers every nonblank character")
    var font_size := label.get_theme_font_size("font_size")
    return {"text":label.text,"rect":rect_array(bounds),"bubble_rect":rect_array(bubble_bounds),"glyph_union_rect":rect_array(glyph_union),"padding_pixels":[bounds.position.x-bubble_bounds.position.x,bounds.position.y-bubble_bounds.position.y,bubble_bounds.end.x-bounds.end.x,bubble_bounds.end.y-bounds.end.y],"lines":label.get_line_count(),"visible_lines":label.get_visible_line_count(),"glyphs_checked":glyphs,"glyph_bounds":glyph_bounds,"font_size":font_size,"effective_font_pixels":font_size*pixel_transform(label).x.length(),"font_family":label.get_theme_font("font").get_font_name(),"minimum_canvas_size":[label.get_combined_minimum_size().x,label.get_combined_minimum_size().y]}

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    root.get_node("PauseManager").resume()
    root.get_node("GameState").sfx_muted=true
    root.get_node("GameState").music_muted=true
    if visual:
        check(DisplayServer.get_name()!="headless","native captures need an actual display")
        report.native=DisplayServer.get_name()!="headless"
    scene=load(ENDING).instantiate()
    root.add_child(scene);current_scene=scene
    scene.set_process(false)
    check(scene.HER_MESSAGE=="Ты не поверишь что мне только что приснилось......" and scene.HIS_MESSAGE=="вещай, любимая","exact original exchange unchanged")
    var viewports := [Vector2i(1280,720),Vector2i(2582,1220),Vector2i(3088,1440),Vector2i(854,480),Vector2i(720,1280)]
    for mode in [Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,Window.CONTENT_SCALE_MODE_DISABLED]:
        root.content_scale_mode=mode
        root.content_scale_size=Vector2i(1280,720)
        root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
        for viewport in viewports:
            root.size=viewport
            await settled()
            for font_variant in ["phone-native","wide-pixel-stress"]:
                for label in [scene.get("_her_text"),scene.get("_his_text")]:
                    label.add_theme_font_override("font",scene.get("_phone_font") if font_variant=="phone-native" else PixelStyle.font())
                    label.add_theme_font_size_override("font_size",18 if font_variant=="phone-native" else 24)
                var draft: Label=scene.get("_draft")
                draft.add_theme_font_override("font",scene.get("_phone_font") if font_variant=="phone-native" else PixelStyle.font())
                draft.add_theme_font_size_override("font_size",16 if font_variant=="phone-native" else 24)
                for stage in [[13.5,"draft"],[14.5,"message"],[21.5,"reply"]]:
                    scene.seek_for_capture(float(stage[0]))
                    await settled()
                    var context: String=str(viewport)+"/"+str(mode)+"/"+String(font_variant)+"/"+String(stage[1])
                    var device: Control=scene.get("_phone_screen")
                    var display: Control=scene.get("_phone_surface")
                    var chat: Control=scene.get("_phone_chat")
                    check(device.visible,context+": phone is actually visible")
                    check(inside(global_rect(device),Rect2(Vector2.ZERO,Vector2(root.size))),context+": physical device fits actual cinematic viewport")
                    check(inside(global_rect(display),global_rect(device)),context+": display inside physical bezel")
                    check(inside(global_rect(chat),global_rect(display)),context+": conversation viewport inside display")
                    var stretch := root.get_stretch_transform()
                    var composer: Control=display.find_child("MessageComposer",true,false)
                    var header: Control=display.find_child("PhoneContactHeader",true,false)
                    var item := {"case_id":context,"requested_screen":[viewport.x,viewport.y],"screen":[root.size.x,root.size.y],"canvas_size":[scene.size.x,scene.size.y],"canvas_to_pixel_transform":[stretch.x.x,stretch.x.y,stretch.y.x,stretch.y.y,stretch.origin.x,stretch.origin.y],"stretch_mode":mode,"font_variant":font_variant,"stage":stage[1],"device_rect":rect_array(global_rect(device)),"display_rect":rect_array(global_rect(display)),"conversation_rect":rect_array(global_rect(chat)),"composer_rect":rect_array(global_rect(composer)),"header_rect":rect_array(global_rect(header)),"labels":[]}
                    if scene.get("_her_bubble").visible:
                        check(inside(global_rect(scene.get("_her_bubble")),global_rect(chat)),context+": outgoing bubble fully visible without scrolling")
                        item.labels.append(inspect_label(scene.get("_her_text"),scene.get("_her_bubble"),display,context+"/Taya"))
                    if scene.get("_his_bubble").visible:
                        check(inside(global_rect(scene.get("_his_bubble")),global_rect(chat)),context+": reply bubble fully visible without scrolling")
                        item.labels.append(inspect_label(scene.get("_his_text"),scene.get("_his_bubble"),display,context+"/Danil"))
                    if draft.visible:
                        check(draft.text==scene.HER_MESSAGE,context+": complete unsent draft, not a shortened surrogate")
                        item.labels.append(inspect_label(draft,draft.get_parent().get_parent().get_parent(),display,context+"/draft"))
                    report.cases.append(item)
                    if visual and mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and font_variant=="phone-native":
                        var name := "%dx%d-%s.png"%[viewport.x,viewport.y,String(stage[1])]
                        check(root.get_texture().get_image().save_png(output.path_join(name))==OK,"native capture "+name)
                        report.captures.append(name)
    scene.queue_free();current_scene=null
    for i in range(5):await advance()
    await Teardown.drain_audio(self)
    for path in ["res://scripts/ending_cutscene.gd","res://tools/ending_phone152_test.gd"]:
        report.source_hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
    report.failures=failures
    report["result"]="PASS" if failures.is_empty() else "FAIL"
    FileAccess.open(output.path_join("phone152-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    if failures.is_empty():print("ENDING PHONE152: PASS — actual shaped glyphs, dynamic bubbles and draft fit five real viewport sizes, production stretch and raw canvas, native and wide pixel fonts")
    quit(0 if failures.is_empty() else 1)
