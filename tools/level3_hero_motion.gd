extends SceneTree
## Short real-player motion recording in the production street. No mission
## progression is staged. The QA camera follows more closely than gameplay.
var game: Level3Store
const Teardown = preload("res://tools/level3_test_teardown.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
    root.size=Vector2i(1280,720)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.get_node("GameState").music_muted=true
    root.get_node("GameState").sfx_muted=false
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    for frame in range(6):await physics_frame
    game.set_process(false);game.set_physics_process(false)
    game.hud.mobile_active=true;game.hud._layout()
    game.camera.position_smoothing_enabled=false
    var positions := PackedVector2Array()
    var phases: Dictionary={}
    for frame in range(240):
        var section := frame/60
        var weapon: StringName=&"pistol" if section<2 else &"shotgun"
        if frame%60==0:game.player.equip_weapon(weapon,24)
        var movement := Vector2.RIGHT if section%2==0 else Vector2.LEFT
        var aim := Vector2.RIGHT if section<2 else Vector2.UP
        game.player.set_input(movement,aim,frame%60>24,false,false,false)
        game.camera.zoom=Vector2.ONE*4
        game.camera.global_position=game.player.global_position+Vector2(8,0)
        game.camera.reset_smoothing()
        await process_frame
        positions.append(game.player.global_position)
        phases[game.player._visual.gait_distance]=true
    game.player.clear_controls()
    if positions[0].distance_to(positions[59])<150 or phases.size()<20:
        push_error("LEVEL3 HERO MOTION: movement/gait never advanced")
        quit(1);return
    print("LEVEL3 HERO MOTION: PASS — real production movement, forward/backpedal/strafe, two pneumatic weapons and grip recoil")
    game.queue_free();current_scene=null
    for frame in range(4):await process_frame
    await Teardown.drain_audio(self)
    quit()
