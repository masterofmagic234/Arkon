extends SceneTree
## Actual heroine rig and production player movement; visual mode captures the
## same actor in the real diner/street. This is asset QA, not a mission replay.
const Hero = preload("res://scripts/level3_hero_visual.gd")
const Teardown = preload("res://tools/level3_test_teardown.gd")
var failed := false
var visual := false
var output := "user://hero-147"
var captures: Array[String] = []
var game: Node
var player: Level3Player
func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--visual": visual=true
        elif arg.begins_with("--output="): output=arg.trim_prefix("--output=")
    call_deferred("run")
func check(ok: bool, why: String) -> void:
    if not ok: failed=true;push_error("LEVEL3 HERO: "+why)
func ticks(count: int) -> void:
    for index in range(count): await physics_frame
func run() -> void:
    root.size=Vector2i(1280,720)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    if visual:
        check(DisplayServer.get_name()!="headless","native visual mode requires a framebuffer")
        game=load("res://scenes/level3_store.tscn").instantiate()
        root.add_child(game);current_scene=game
        await ticks(5)
        game.set_process(false);game.set_physics_process(false)
        player=game.player
    else:
        player=load("res://scenes/level3_player.tscn").instantiate()
        root.add_child(player);current_scene=player
    await ticks(3)
    var rig=player._visual
    check(rig is Hero and not rig is AnimatedSprite2D,"old human strip is still the actual actor")
    check(rig.part_count()==9,"the painted head/torso/limbs/weapon rig is incomplete")
    check(player.get_node_or_null("WeaponOverlay")==null,"unrelated legacy weapon overlay remains")
    check(rig.muzzle_socket.position==Vector2(18,0),"painted weapon diverges from the safe muzzle ray")
    for part in rig.parts.values():
        check(part is Sprite2D and part.texture!=null and part.visible,"painted rig part is missing")
        check(part.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"pixel part is blurred")
    var start: Vector2=player.global_position
    player.set_input(Vector2.RIGHT,Vector2.RIGHT,false,false,false,false)
    await ticks(60)
    check(player.global_position.distance_to(start)>100,"actual production movement did not travel")
    check(rig.state==&"walk" and rig.gait_weight>.99,"actual movement does not drive the feet")
    var phase_before: float=rig.gait_distance
    var point_before: Vector2=player.global_position
    await ticks(24)
    var travelled: float=player.global_position.distance_to(point_before)
    var expected: float=wrapf(phase_before+travelled,0,Hero.STRIDE)
    check(absf(rig.gait_distance-expected)<.2,"gait is a timer instead of travelled distance")
    var left: Transform2D=rig.parts.leg_left.transform
    var right: Transform2D=rig.parts.leg_right.transform
    rig.update_motion(0,Vector2(120,0))
    check(rig.parts.leg_left.transform==left and rig.parts.leg_right.transform==right,"zero-delta frame advances feet")
    # Equal travel at two timesteps produces the same planted-leg pose. Retreat
    # reverses the cycle rather than substituting an unrelated walking strip.
    rig.gait_distance=0;rig.gait_weight=1
    rig.update_motion(.2,Vector2(70,0));left=rig.parts.leg_left.transform;right=rig.parts.leg_right.transform
    rig.gait_distance=0;rig.gait_weight=1
    for index in range(4):rig.update_motion(.1,Vector2(35,0))
    check(rig.parts.leg_left.transform.is_equal_approx(left) and rig.parts.leg_right.transform.is_equal_approx(right),"gait changes with timestep/speed")
    rig.gait_distance=0;rig.gait_weight=1
    rig.update_motion(.1,Vector2(30,0));rig.update_motion(.1,Vector2(-30,0))
    check(absf(rig.gait_distance)<.001,"backpedalling cannot reverse the gait")
    rig.gait_distance=12;rig.gait_weight=1
    rig.update_motion(.00001,Vector2(0,120))
    check(is_equal_approx(rig.parts.leg_left.position.x,rig.parts.leg_right.position.x) and absf(rig.parts.leg_left.position.y)>6,"strafing feet run along the aim axis")
    player.clear_controls();await ticks(12)
    check(rig.state==&"idle" and rig.gait_weight<.01,"stopped heroine keeps walking")
    for weapon: StringName in [&"pistol",&"shotgun",&"bat"]:
        player.equip_weapon(weapon,12)
        check(rig.weapon_id==weapon,"painted weapon did not follow equipment")
        check(rig.left_wrist.distance_to(rig.left_grip)<.02 and rig.right_wrist.distance_to(rig.right_grip)<.02,"hand detached from its weapon grip")
        var maximum := 17 if weapon in [&"shotgun",&"bat"] else 13
        check(rig.weapon_sprite.texture.get_width()==maximum,"weapon is not proportionate to the actor")
        player._play_fire_animation();rig.update_motion(.055,Vector2.ZERO)
        check(rig.state in [&"recoil",&"swing"] and rig.attack_remaining>0,"attack has no real rig animation")
        check(rig.left_wrist.distance_to(rig.left_grip)<.02 and rig.right_wrist.distance_to(rig.right_grip)<.02,"recoil detached a supporting hand")
        rig.update_motion(.5,Vector2.ZERO)
        check(rig.state==&"idle" and rig.attack_remaining==0,"attack never recovers")
    player.equip_weapon(&"pistol",12)
    check(player.get_weapon_data().display_name=="ШИШКОЛЁТ","ordinary pistol label remains")
    check(player.get_weapon_data().projectile_texture.ends_with("cone_projectile.png"),"ordinary bullet remains")
    player.equip_weapon(&"shotgun",6)
    check(player.get_weapon_data().display_name=="ШИШКОВИК","ordinary shotgun label remains")
    var sling=player.get_node("PineConeLauncherSling/CarriedCedarCarbine")
    check(sling.texture.get_width()==17,"carried cone launcher is oversized")
    if visual:
        DirAccess.make_dir_recursive_absolute(output)
        game.hud.mobile_active=true;game.hud._layout()
        player.equip_weapon(&"pistol",12)
        await capture("street-normal",1.7)
        for weapon: StringName in [&"pistol",&"shotgun"]:
            player.equip_weapon(weapon,12)
            player.set_input(Vector2.RIGHT,Vector2.RIGHT,false,false,false,false)
            for frame in range(4):
                await ticks(5)
                await capture(String(weapon)+"-walk-%d"%frame,4.0)
            player.clear_controls();await ticks(8)
            await capture(String(weapon)+"-idle",4.0)
            player._play_fire_animation();await ticks(3)
            await capture(String(weapon)+"-recoil",4.0)
        var report={"captures":captures,"rig_parts":rig.part_count(),"painted_weapon_tip":18.5,"physical_muzzle":18,"source":"actual production player/diner, real movement and rig; staged camera, not full mission replay","failures":[] if not failed else ["see strict log"]}
        FileAccess.open(output.path_join("hero-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
    current_scene.queue_free();current_scene=null
    await ticks(4);await Teardown.drain_audio(self)
    if not failed: print("LEVEL3 HERO: PASS — original pixel heroine, real travel-driven gait, hand grips/recoil, proportionate cone weapons, safe muzzle and preserved controls")
    quit(1 if failed else 0)
func capture(label: String, zoom: float) -> void:
    game.camera.position_smoothing_enabled=false
    game.camera.global_position=player.global_position+Vector2(12,0)
    game.camera.zoom=Vector2.ONE*zoom
    game.camera.reset_smoothing()
    await process_frame
    RenderingServer.force_draw(true)
    root.get_texture().get_image().save_png(output.path_join(label+".png"))
    captures.append(label+".png")
