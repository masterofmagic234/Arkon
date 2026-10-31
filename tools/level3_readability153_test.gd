extends SceneTree
## Staged art/UI inspection in the actual diner, not a played campaign.
const Hero = preload("res://scripts/level3_hero_visual.gd")
const Story = preload("res://scripts/level3_story.gd")
const Teardown = preload("res://tools/level3_test_teardown.gd")
var failed := false
var visual := false
var output := "user://readability153"
var reference_shader := ""
var checks := 0
var captures: Array[String] = []
var pixel_metrics: Array[Dictionary] = []
var game: Node

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg=="--visual": visual=true
        elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        elif arg.begins_with("--reference-shader="): reference_shader=arg.trim_prefix("--reference-shader=")
    call_deferred("run")

func check(value: bool,why: String) -> void:
    checks+=1
    if not value:
        failed=true
        push_error("LEVEL3 READABILITY153: "+why)

func ticks(count: int) -> void:
    for i in range(count): await physics_frame

func run() -> void:
    root.size=Vector2i(1280,720)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    await ticks(8)
    game.set_process(false)
    game.mission.set_process(false)
    game.player.set_physics_process(false)
    game.interaction_arrow.set_process(false)
    game.hud.mobile_active=true;game.hud._layout()
    # The fixture freezes gameplay clocks; expire the ordinary2.6s entry hint
    # so it does not masquerade as a live kitchen goal in staged captures.
    game._hint_timer=0
    var source_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/level3/taya152/source-manifest.json"))
    check(source_manifest.sources.size()==7,"original source inventory changed")
    for source_path: String in source_manifest.sources:
        check(FileAccess.get_sha256("res://"+source_path)==source_manifest.sources[source_path],"original source PNG changed: "+source_path)
    var arrow=game.interaction_arrow
    for child in game.environment.order_marker.get_children():
        if child is Label:check(not child.visible,"old pizza text overlaps the interaction arrow")
    var phases: Array[StringName]=[&"street",&"kitchen",&"cleared",&"pizza",&"exit"]
    var kinds: Array[StringName]=[&"reception",&"chef",&"chef",&"order",&"car"]
    var positions: Array[Vector2]=[Story.RECEPTION,game.mission.chef.global_position,game.mission.chef.global_position,game._scaled_cell_world(game.StoreData.ORDER_CELL),game.mission.car.global_position]
    game._enemies_alive=0
    for i in range(phases.size()):
        game.mission.phase=phases[i]
        game.order_collected=phases[i]==&"exit"
        arrow._process(.05)
        check(arrow.visible and arrow.target_kind==kinds[i],"wrong current story interaction at "+String(phases[i]))
        check(arrow.target_position.is_equal_approx(positions[i]),"arrow does not identify the real object at "+String(phases[i]))
    for phase: StringName in [&"reception",&"conversation",&"arrival",&"deployment",&"breach",&"return",&"assault",&"aftermath",&"boarding"]:
        game.mission.phase=phase;arrow._process(.05)
        check(not arrow.visible,"arrow leaks into dialogue/cinematic/combat "+String(phase))
    game.mission.phase=&"pizza";game.order_collected=false;game._enemies_alive=1;arrow._process(.05)
    check(not arrow.visible,"pizza arrow visible while enemies remain")
    game._enemies_alive=0;game.order_collected=true;arrow._process(.05)
    check(not arrow.visible,"collected pizza still marked")
    game.mission.phase=&"exit";game.mission.boarding_started=true;arrow._process(.05)
    check(not arrow.visible,"already-boarded car still marked")
    game.mission.boarding_started=false
    game.mission.phase=&"street";game.order_collected=false
    var low:=INF;var high:=-INF
    for i in range(120):
        arrow._process(1.0/60)
        low=minf(low,arrow.position.y-arrow.target_position.y)
        high=maxf(high,arrow.position.y-arrow.target_position.y)
        check(is_equal_approx(arrow.position.x,arrow.target_position.x),"bob drifts away from object")
    check(is_equal_approx(high-low,4.0),"arrow bob is absent or excessive")
    var rig=game.player._visual
    check(game.player.get_node("CollisionShape2D").shape.radius==7,"visual change modified physical player radius")
    check(rig.muzzle_socket.position==Vector2(18,0),"visual change modified safe physical muzzle")
    rig.set_weapon_drawn(false)
    check(is_equal_approx(rig.body_sprite.material.get_shader_parameter("shoulder_width"),.72),"broad peaceful silhouette remains")
    rig.set_weapon_drawn(true)
    check(is_equal_approx(rig.body_sprite.material.get_shader_parameter("shoulder_width"),.90),"armed silhouette not consistent")
    if visual:
        check(DisplayServer.get_name()!="headless","native capture requires framebuffer")
        DirAccess.make_dir_recursive_absolute(output)
        game.player.global_position=Vector2(624,270)
        check(game._is_spawn_clear(game.player.global_position),"actual kitchen inspection point blocked")
        game.player.rotation=0
        game.player.set_combat_enabled(false)
        game.mission.phase=&"kitchen";arrow._process(0)
        game._update_hud()
        if not reference_shader.is_empty():
            var original: Shader=rig.body_sprite.material.shader
            var prior:=Shader.new();prior.code=FileAccess.get_file_as_string(reference_shader)
            rig.body_sprite.material.shader=prior
            await capture("before152-peaceful",1.7)
            await capture("before152-peaceful-2x",3.4)
            rig.body_sprite.material.shader=original
        await capture("after153-peaceful",1.7)
        await capture("after153-peaceful-2x",3.4)
        await inspect_body_pixels(rig,false)
        for i in range(4):
            rig.gait_distance=i*Hero.STRIDE/4;rig.gait_weight=1
            rig.update_motion(.00001,Vector2(90,0))
            await capture("after153-walk-%d"%i,3.4)
        game.player.set_combat_enabled(true);game.player.equip_weapon(&"pistol",12)
        game.mission.phase=&"assault";arrow._process(0);game._update_hud()
        await capture("after153-armed",1.7)
        await capture("after153-armed-2x",3.4)
        await inspect_body_pixels(rig,true)
        game.mission.phase=&"pizza";game.order_collected=false;game._enemies_alive=0
        game.environment.order_marker.show();arrow._process(0);game._update_hud()
        await capture("after153-pizza-arrow",1.7)
        game.mission.phase=&"exit";game.order_collected=true;game.player.set_combat_enabled(false)
        game.player.global_position=Story.CAR_POSITION+Vector2(65,0);arrow._process(0);game._update_hud()
        await capture("after153-car-arrow",1.7)
    DirAccess.make_dir_recursive_absolute(output)
    FileAccess.open(output.path_join("readability153-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"result":"FAIL" if failed else "PASS","checks":checks,"captures":captures,"pixel_metrics":pixel_metrics,"arrow_targets":["reception","chef","order","car"],"bob_world_pixels":high-low,"native":visual,"scope":"Actual production diner staged positions/equipment/phases/camera; transparent native sprite readback separately measures actual source pixel footprint/red palette. Not a full mission or phone performance measurement."},"  ")+"\n")
    game.queue_free();current_scene=null
    await ticks(4);await Teardown.drain_audio(self)
    if not failed:print("LEVEL3 READABILITY153: PASS")
    quit(1 if failed else 0)

func capture(label: String,zoom_: float) -> void:
    game.camera.position_smoothing_enabled=false
    game.camera.zoom=Vector2.ONE*zoom_
    game.camera.global_position=game.player.global_position+Vector2(40,0)
    game.camera.reset_smoothing()
    await process_frame
    RenderingServer.force_draw(true)
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
    captures.append(label+".png")

func inspect_body_pixels(rig: Node2D,armed: bool) -> void:
    var viewport:=SubViewport.new()
    viewport.size=Vector2i(192,192)
    viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var sprite:=Sprite2D.new()
    sprite.texture=rig.body_sprite.texture
    sprite.hframes=8
    sprite.frame=0
    sprite.position=Vector2(96,96)
    sprite.scale=Vector2.ONE*4
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    viewport.add_child(sprite);root.add_child(viewport)
    var material_: ShaderMaterial=rig.body_sprite.material.duplicate()
    material_.set_shader_parameter("authored_head_center",Vector2(21.5,16) if armed else Vector2(15.5,16))
    var current: Shader=material_.shader
    var prior: Shader=current
    if not reference_shader.is_empty():
        prior=Shader.new();prior.code=FileAccess.get_file_as_string(reference_shader)
    sprite.material=material_
    var rows: Array[Dictionary]=[]
    for before in [true,false]:
        material_.shader=prior if before else current
        material_.set_shader_parameter("shoulder_width",1.0 if before else (.90 if armed else .72))
        await process_frame
        RenderingServer.force_draw(true)
        var image:=viewport.get_texture().get_image()
        var rect:=image.get_used_rect()
        var red:=0
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                var c:=image.get_pixel(x,y)
                if c.a>.9 and c.r>.3 and c.r>c.g*2.1 and c.r>c.b*1.7:red+=1
        var row: Dictionary={"version":("before152" if not reference_shader.is_empty() else "original_width_current_palette") if before else "after153","width":rect.size.x,"shoulder_extent":rect.size.y,"red_pixels":red}
        rows.append(row)
        var before_label: String="before152" if not reference_shader.is_empty() else "original-width"
        var label: String=("armed" if armed else "peaceful")+"-alpha-"+(before_label if before else "after153")+".png"
        image.save_png(output.path_join(label));captures.append(label)
    check(rows[1].shoulder_extent<rows[0].shoulder_extent,"actual native shoulder footprint did not narrow")
    check(rows[1].red_pixels>=160,"red hair remains unreadable in actual shader pixels")
    if not reference_shader.is_empty():
        check(rows[1].red_pixels>rows[0].red_pixels+48,"red hair did not become more readable than the152 baseline")
    pixel_metrics.append({"stance":"armed" if armed else "peaceful","samples":rows,"scale":4,"source_png_bytes_unchanged":true})
    viewport.queue_free()
    await process_frame
