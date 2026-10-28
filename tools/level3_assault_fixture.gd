extends RefCounted
## Staged combat/render fixture, not an end-to-end mission playthrough.
## It runs the actual van/deployment/breach before freezing the live roster.

static func prepare(tree: SceneTree, game: Node) -> bool:
    if game.get("mission") == null:
        push_error("LEVEL3 ASSAULT FIXTURE: mission director is missing")
        return false
    # These callers inspect a staged combat frame, not an arrival replay. Keep
    # every real physics step while avoiding thousands of redundant software-GPU
    # draws. The full input/story playthrough does not use this fixture.
    var render_loop_was_enabled := RenderingServer.is_render_loop_enabled()
    RenderingServer.set_render_loop_enabled(false)
    game.mission.begin_raid()
    for frame in range(3600):
        await tree.physics_frame
        if game.mission.phase != &"assault":
            continue
        if game._enemies.size() != 10 or game._enemies_alive != 10:
            RenderingServer.set_render_loop_enabled(render_loop_was_enabled)
            push_error("LEVEL3 ASSAULT FIXTURE: incomplete physical deployment")
            return false
        for actor in game._enemies:
            actor.set_physics_process(false)
        # Let the real flashbang/recovery finish before input/combat assertions.
        for recovery_frame in range(90):
            await tree.physics_frame
        game.mission.set_process(false)
        game.clear_inputs()
        RenderingServer.set_render_loop_enabled(render_loop_was_enabled)
        return true
    RenderingServer.set_render_loop_enabled(render_loop_was_enabled)
    push_error("LEVEL3 ASSAULT FIXTURE: actual raid did not reach assault; phase=" + str(game.mission.phase))
    return false
