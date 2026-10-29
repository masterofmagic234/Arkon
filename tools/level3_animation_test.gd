extends SceneTree
const AssaultFixture = preload("res://tools/level3_assault_fixture.gd")
const Teardown=preload("res://tools/level3_test_teardown.gd")
var game: Level3Store
var failed := false
func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
    if not ok: failed=true;push_error("SQUIRREL ANIMATION: "+why)
func _run() -> void:
    game=load("res://scenes/level3_store.tscn").instantiate()
    root.add_child(game);current_scene=game
    for i in range(8): await physics_frame
    if not await AssaultFixture.prepare(self, game): quit(1);return
    # The heroine is the actual new painted rig, not a hidden AnimatedSprite
    # proxy. Her arm endpoints stay on the grips during locomotion and recoil.
    var heroine=game.player._visual
    check(not heroine is AnimatedSprite2D and heroine.part_count()==9,"legacy human sprite is still active")
    heroine.gait_weight=1;heroine.gait_distance=0
    heroine.update_motion(.2,Vector2(70,0))
    var heroine_left: Transform2D=heroine.parts.leg_left.transform
    var heroine_right: Transform2D=heroine.parts.leg_right.transform
    heroine.gait_distance=0
    for i in range(4):heroine.update_motion(.1,Vector2(35,0))
    check(heroine.parts.leg_left.transform.is_equal_approx(heroine_left) and heroine.parts.leg_right.transform.is_equal_approx(heroine_right),"heroine stride depends on time rather than travel")
    check(heroine.left_wrist.distance_to(heroine.left_grip)<.02 and heroine.right_wrist.distance_to(heroine.right_grip)<.02,"heroine hands do not support the gun")
    game.player._play_fire_animation();heroine.update_motion(.06,Vector2.ZERO)
    check(heroine.state==&"recoil" and heroine.attack_remaining>0,"heroine fire has no recoil")
    check(heroine.left_wrist.distance_to(heroine.left_grip)<.02,"heroine support hand detaches during recoil")
    game.player.clear_controls()
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    var roles: Dictionary={}
    for actor in game._enemies:
        actor.set_physics_process(false)
        if not roles.has(actor.enemy_kind): roles[actor.enemy_kind]=actor
    for kind: StringName in roles:
        var actor: Level3Enemy=roles[kind]
        var animator=actor._animator
        var sprite:=actor._visual
        var frames:=sprite.sprite_frames
        check(not sprite.is_playing(),"automatic playback can drift from combat")
        check(sprite.position==Vector2.ZERO and is_zero_approx(sprite.rotation),"legacy human origin remains")
        # Equal travel must give equal paw placement despite timestep/speed.
        animator.configure(sprite,kind,0)
        animator.update(.2,Vector2(70,0),0,0,.48,false,false)
        var traveled_frame:=sprite.frame
        animator.configure(sprite,kind,0)
        for i in range(4): animator.update(.1,Vector2(35,0),0,0,.48,false,false)
        check(sprite.frame==traveled_frame,"steps depend on time rather than travel")
        animator.configure(sprite,kind,0)
        animator.update(.1,Vector2(30,0),0,0,.48,false,false)
        animator.update(.1,Vector2(-30,0),0,0,.48,false,false)
        check(sprite.frame==0,"retreat cannot reverse the planted paw cycle")
        animator.update(.2,Vector2.ZERO,0,0,.48,false,false)
        check(sprite.animation==&"idle","stationary actor keeps running")
        var pose:=sprite.frame
        animator.update(0,Vector2.ZERO,0,0,.48,false,false)
        check(sprite.frame==pose,"zero-delta pose advances during pause")
        animator.update(0,Vector2.ZERO,0,.48,.48,false,false)
        check(sprite.animation==&"windup" and sprite.frame==0,"windup starts in a late pose")
        animator.update(0,Vector2.ZERO,0,.001,.48,false,false)
        check(sprite.frame==frames.get_frame_count(&"windup")-1,"windup pose not locked to the damage timer")
        animator.attack()
        animator.update(.05,Vector2.ZERO,0,0,.48,false,false)
        check(sprite.animation==&"attack","attack has no recoil/follow-through")
        animator.interrupt()
        animator.update(.2,Vector2.ZERO,0,0,.48,true,false)
        check(sprite.animation==&"stun","stun does not interrupt recovery")
        animator.fall()
        animator.update(1,Vector2.ZERO,0,0,.48,false,true)
        check(sprite.animation==&"fall" and sprite.frame==5,"fall never settles")
        animator.update(2,Vector2.ZERO,0,0,.48,false,true)
        check(sprite.frame==5 and sprite.sprite_frames==frames,"body loops or allocates new resources")
        animator.configure(sprite,kind,0)
    # Actual attack control still emits once at the original .48s boundary.
    var gunman: Level3Enemy=roles[&"gunman"]
    gunman.global_position=Vector2(200,688)
    game.player.global_position=Vector2(270,688)
    gunman.state=Level3Enemy.State.ALERT
    gunman._sense_timer=0;gunman._attack_cooldown=0
    gunman.velocity=Vector2.ZERO
    var shots: Array[int]=[0]
    gunman.shot_requested.connect(func(_actor,_origin,_direction): shots[0]+=1)
    gunman._physics_process(1.0/60)
    check(gunman._windup>0 and gunman._visual.animation==&"windup","real actor did not prepare")
    for i in range(28): gunman._physics_process(1.0/60)
    check(shots[0]==0,"new animation fires before the combat window")
    for i in range(2): gunman._physics_process(1.0/60)
    check(shots[0]==1 and gunman._visual.animation==&"attack","shot/recoil boundary diverged")
    for i in range(12): gunman._physics_process(1.0/60)
    check(shots[0]==1,"recovery duplicated a shot")
    gunman._windup=.2
    gunman.stun(1)
    for i in range(20): gunman._physics_process(1.0/60)
    check(shots[0]==1 and gunman._windup==0 and gunman._visual.animation==&"stun","interrupted attack fired late")
    gunman.kill()
    gunman._physics_process(.4)
    check(gunman._visual.animation==&"fall" and gunman._visual.frame==5,"dead actor stops before its fall ends")
    for kind: StringName in [&"melee",&"butcher"]:
        var actor: Level3Enemy=roles[kind]
        actor.global_position=Vector2(200,688)
        game.player.global_position=Vector2(234,688)
        game.player._health_component.reset(100)
        actor.state=Level3Enemy.State.ALERT
        actor._sense_timer=0;actor._attack_cooldown=0;actor.velocity=Vector2.ZERO
        actor._physics_process(1.0/60)
        check(actor._windup>0 and actor._visual.animation==&"windup","melee did not prepare: "+str(kind))
        var held_frame:=actor._visual.frame
        var held_windup:=actor._windup
        game._level_complete_started=true
        actor._physics_process(.5)
        check(actor._windup==held_windup and actor._visual.frame==held_frame,"world pause advances an attack: "+str(kind))
        game._level_complete_started=false
        for i in range(19): actor._physics_process(1.0/60)
        check(game.player.health==100,"melee animation deals early damage: "+str(kind))
        for i in range(2): actor._physics_process(1.0/60)
        check(game.player.health==78 and actor._visual.animation==&"attack","melee impact moved from .34s: "+str(kind))
        for i in range(6): actor._physics_process(1.0/60)
        check(game.player.health==78,"follow-through duplicates damage: "+str(kind))
        actor._windup=.2;actor.stun(1)
        for i in range(20): actor._physics_process(1.0/60)
        check(game.player.health==78 and actor._visual.animation==&"stun","stunned melee still attacks: "+str(kind))
        actor.kill()
    game.queue_free()
    await process_frame;await process_frame;await process_frame
    await Teardown.drain_audio(self)
    if failed: quit(1)
    else:
        print("LEVEL3 ANIMATION TEST: PASS — three animal rigs, distance-driven/reverse steps, pause, idle, synchronized windup/recoil, interruption and settled fall")
        quit(0)
