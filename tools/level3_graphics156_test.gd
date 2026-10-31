extends SceneTree
## Staged production-scene quality/lifecycle regression. No phone FPS claim.
const Teardown = preload("res://tools/level3_test_teardown.gd")
const Navigation = preload("res://scripts/level3_navigation.gd")
const Visual = preload("res://scripts/level3_asset_visual.gd")
const Skins = preload("res://scripts/level3_squirrel_skins.gd")
const Hero = preload("res://scripts/level3_hero_visual.gd")
const Portraits = preload("res://scripts/level3_dialogue_portraits.gd")
const Policy = preload("res://scripts/graphics_policy156.gd")
const Lines = preload("res://scripts/level3_dialogue_lines.gd")
const PROFILES := [
    {"profile":"low","l3_real_lights":4,"rain_enabled":false,"rain_quality":0,"hit_particle_limit":48,"hit_drops":6,"stain_limit":120,"minimap_interval":0.2},
    {"profile":"balanced","l3_real_lights":8,"rain_enabled":true,"rain_quality":1,"hit_particle_limit":72,"hit_drops":10,"stain_limit":240,"minimap_interval":0.15},
    {"profile":"high","l3_real_lights":14,"rain_enabled":true,"rain_quality":2,"hit_particle_limit":96,"hit_drops":15,"stain_limit":360,"minimap_interval":0.1},
]
var game: Level3Store
var failures: Array[String] = []
var checks := 0
var visual := false
var output := "user://graphics156-level3"

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument=="--visual": visual=true
        elif argument.begins_with("--output="): output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)
        push_error("LEVEL3 GRAPHICS156: "+message)

func ticks(count: int = 1) -> void:
    for index in range(count): await physics_frame

func _viewport_contract() -> Array:
    return [root.size,root.content_scale_mode,root.content_scale_size,root.scaling_3d_scale,root.msaa_2d,root.msaa_3d]

func run() -> void:
    root.size = Vector2i(1280,720)
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=true
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    for frame in range(120):
        if game.ready_for_play: break
        await ticks()
    check(game.ready_for_play,"initial navigation and playable diner did not become ready")
    game.set_process(false)
    var graphics := root.get_node_or_null("GraphicsSettings")
    check(graphics!=null,"shared graphics autoload is absent")
    if graphics!=null:
        var initial: Dictionary=graphics.get_level_settings(&"level3")
        check(game.environment.light_count==int(initial.get("l3_real_lights",14)),"initial hardware profile did not reach the real environment")
        check(game.effects.particle_limit==int(initial.get("hit_particle_limit",96)),"initial hardware profile did not reach combat effects")
    var viewport_before := _viewport_contract()
    var zoom_before := game.camera.zoom
    var marker_before := [game.environment.order_marker,game.environment.exit_marker,game.interaction_arrow]
    var body_radius: float=game.player.get_node("CollisionShape2D").shape.radius
    var minimap=game.hud._map
    for profile: Dictionary in PROFILES:
        game.apply_graphics_settings(profile)
        _check_profile(profile)
        check(_viewport_contract()==viewport_before,"quality altered the native canvas or root viewport")
        check(game.camera.zoom==zoom_before,"quality altered the authored camera scale")
        check(game.player.get_node("CollisionShape2D").shape.radius==body_radius,"quality altered player collisions")
        check(game._enemies.is_empty() and not game.player.combat_enabled,"quality changed the peaceful entry")
        check([game.environment.order_marker,game.environment.exit_marker,game.interaction_arrow]==marker_before,"quality replaced a gameplay interaction marker")
    for step in [1,2]:
        var dynamic: Dictionary=Policy.level_settings("low",&"level3",step)
        game.apply_graphics_settings(dynamic)
        _check_profile(dynamic)
    if graphics!=null:
        graphics.settings_changed.emit()
        var restored: Dictionary=graphics.get_level_settings(&"level3")
        check(game.environment.light_count==int(restored.get("l3_real_lights",14)),"settings_changed did not reapply the central profile")
    game.apply_graphics_settings(PROFILES[0])
    check(game.graphics_observation_active(),"unlocked street gameplay excluded from calibration")
    game.dialogue.start_dialogue(Lines.KITCHEN)
    check(not game.graphics_observation_active(),"dialogue enters runtime calibration")
    game.dialogue.cancel_dialogue()
    root.get_node("PauseManager").set_paused(true)
    check(not game.graphics_observation_active(),"pause enters runtime calibration")
    root.get_node("PauseManager").resume()
    # Burst feedback remains readable while cosmetic drops recycle their slots.
    game.effects.trace(Vector2(10,10),Vector2(20,10),Color.WHITE)
    game.effects.muzzle(Vector2(20,10),0)
    game.effects.cone_muzzle(Vector2(20,10),0)
    game.effects.glass(Vector2(20,10))
    for hit in range(40): game.effects.blood(Vector2(20,10),Vector2.RIGHT,false,1)
    var cue_kinds: Array[StringName]=[]
    for slot: Dictionary in game.effects._slots:
        if float(slot.life)>0 and slot.kind!=&"drop": cue_kinds.append(slot.kind)
    for kind: StringName in [&"trace",&"muzzle",&"cone_muzzle",&"glass"]:
        check(cue_kinds.has(kind),"blood evicted essential feedback: "+String(kind))
    check(game.effects.active_count()<=48,"low effect pool exceeded its active budget")
    var stains: Level3BloodStainLayer=game.get_node("BloodStainLayer")
    game.apply_graphics_settings(PROFILES[2])
    for index in range(365):
        stains.add_stain(game.effects._splat,Rect2(0,0,16,16),Vector2(index,0),1,0,Color.WHITE)
    check(stains._textures.size()==360,"high stain budget was not bounded")
    game.apply_graphics_settings(PROFILES[0])
    check(stains._textures.size()==120 and stains._positions.back()==Vector2(364,0),"downgrade lost recent stains or retained the full history")
    check(stains._textures.size()==stains._regions.size() and stains._textures.size()==stains._positions.size() and stains._textures.size()==stains._scales.size() and stains._textures.size()==stains._rotations.size() and stains._textures.size()==stains._modulates.size(),"stain downgrade desynchronized draw data")
    # Skip uses the actual broken-window rebuild, with control locked until the
    # exact collider grid is complete rather than trusting a fixed frame count.
    game.mission.begin_raid()
    game.mission.skip_raid()
    for enemy in game._enemies: enemy.set_physics_process(false)
    check(not game.navigation.ready and game.mission.controls_locked(),"skip unlocked a partially rebuilt collision grid")
    check(not game.graphics_observation_active(),"locked raid shot enters runtime calibration")
    var partial_frames := 0
    for frame in range(180):
        if game.navigation.ready and game.mission.phase==&"assault": break
        if not game.navigation.ready:
            partial_frames += 1
            check(game.mission.controls_locked(),"return shot unlocked during the sliced rebuild")
        await ticks()
    check(partial_frames>=3,"navigation still rebuilt in one burst")
    check(game.navigation.ready and game.mission.phase==&"assault","sliced rebuild never returned to assault")
    check(game._enemies.size()==10 and game._enemies_alive==10,"low profile changed the assault roster")
    check(game.player.combat_enabled and game.player.controls_enabled,"sliced rebuild did not restore combat controls")
    var reference=Navigation.new()
    reference.build(game,Vector2(game.StoreData.map_size())*game.StoreData.TILE_SIZE*game.LAYOUT_SCALE,game._doors)
    check(reference.samples==game.navigation.samples and reference.walkable==game.navigation.walkable,"sliced collision grid differs from synchronous collision authority")
    var matching := true
    for y in range(reference.grid.region.position.y,reference.grid.region.end.y):
        for x in range(reference.grid.region.position.x,reference.grid.region.end.x):
            if reference.grid.is_point_solid(Vector2i(x,y))!=game.navigation.grid.is_point_solid(Vector2i(x,y)): matching=false
    check(matching,"sliced navigation changed walkable cells")
    var actor_contract: Array=[]
    for enemy in game._enemies: actor_contract.append([enemy,enemy.move_speed,enemy.vision_range,enemy.attack_range,enemy.preferred_distance,enemy.collision_mask])
    for profile: Dictionary in PROFILES:
        game.apply_graphics_settings(profile)
        _check_profile(profile)
        check(game._enemies.size()==10 and game._enemies_alive==10,"profile round trip reduced enemies")
        for contract: Array in actor_contract:
            var enemy: Level3Enemy=contract[0]
            check([enemy,enemy.move_speed,enemy.vision_range,enemy.attack_range,enemy.preferred_distance,enemy.collision_mask]==contract,"profile altered AI, attack distance or collision")
    check(Engine.physics_ticks_per_second==60,"graphics altered the fixed simulation rate")
    if visual:
        check(DisplayServer.get_name()!="headless","visual checks require a native framebuffer")
        game.set_physics_process(false)
        game.mission.set_process(false)
        game.player.set_physics_process(false)
        game.player.global_position=Vector2(624,270)
        game.camera.position_smoothing_enabled=false
        game.camera.global_position=game.player.global_position
        game.camera.reset_smoothing()
        game.mission.phase=&"assault"
        game.hud.set_cinematic_mode(false,false)
        game.hud.mobile_active=true
        game.hud._layout()
        # Moving the staged camera also moves the player to a newly explored
        # kitchen. Commit that legitimate background change before testing
        # repeated icon refreshes within the same room.
        minimap._process(0.5)
        DirAccess.make_dir_recursive_absolute(output)
        for index in [2,0]:
            game.apply_graphics_settings(PROFILES[index])
            await process_frame
            RenderingServer.force_draw(true)
            root.get_texture().get_image().save_png(output.path_join("level3-"+String(PROFILES[index].profile)+".png"))
        await process_frame
        RenderingServer.force_draw(true)
        var background_draws: int=minimap.background_draws
        check(background_draws>0 and minimap.visible,"native minimap background was never recorded or displayed")
        for frame in range(5):
            minimap._process(0.21)
            await process_frame
            RenderingServer.force_draw(true)
        check(minimap.background_draws==background_draws,"moving minimap icons rebuilt the static cell background")
    var retained_frames: SpriteFrames=game._enemies[0]._visual.sprite_frames
    var navigation_samples: int=game.navigation.samples
    game.queue_free()
    current_scene=null
    await ticks(4)
    check(Visual._textures.is_empty() and Visual._frames.is_empty() and Skins._cache.is_empty() and Hero._textures.is_empty() and Portraits._cache.is_empty(),"diner atlases remain pinned by optional static caches after exit")
    check(retained_frames.get_animation_names().size()==6,"cache release invalidated externally retained animation frames")
    await Teardown.drain_audio(self)
    DirAccess.make_dir_recursive_absolute(output)
    var report := FileAccess.open(output.path_join("level3-graphics156-report.json"),FileAccess.WRITE)
    if report!=null:
        report.store_string(JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"profiles":PROFILES,"navigation_rows_per_rendered_frame":{"low":2,"balanced":4,"high":8},"navigation_query_samples":navigation_samples,"native_capture":visual,"captures":["level3-high.png","level3-low.png"] if visual else [],"scope":"Staged actual diner, real quality budgets and preserved combat/collision lifecycle. Native images show the same camera/UI scale and cached minimap. No physical phone FPS measurement."},"  ")+"\n")
    print("LEVEL3 GRAPHICS156: "+("PASS" if failures.is_empty() else "FAIL")+" — "+str(checks)+" checks; profiles, preserved feedback/combat, exact sliced navigation and cache lifecycle; not a phone FPS measurement")
    quit(0 if failures.is_empty() else 1)

func _check_profile(profile: Dictionary) -> void:
    var enabled := 0
    var glows := 0
    for light: PointLight2D in game.environment._lights:
        if light.enabled: enabled+=1
    for glow: Sprite2D in game.environment._light_glows:
        if glow.visible: glows+=1
    check(enabled==int(profile.l3_real_lights) and glows==14-enabled,"actual lamps/glow replacements ignore profile "+String(profile.profile))
    for panel: Polygon2D in game.environment._rain_panels:
        check(panel.visible==bool(profile.rain_enabled),"rain panel ignores profile")
    check(game.effects.particle_limit==int(profile.hit_particle_limit) and game.effects.hit_drops==int(profile.hit_drops),"hit feedback budget ignores profile")
    check(game.get_node("BloodStainLayer").stain_limit==int(profile.stain_limit),"permanent stain budget ignores profile")
    check(is_equal_approx(game.hud._map.refresh_interval,float(profile.minimap_interval)),"minimap interval ignores profile")
    check(game._navigation_rows_per_frame==(2 if str(profile.profile)=="low" else (4 if str(profile.profile)=="balanced" else 8)),"breach rebuild ignores hardware batching budget")
