class_name SquirrelMotionMath
extends RefCounted

# Pure squirrel movement calculation. It does not inspect or mutate scene state.
static func proposed_position(home: Vector2, player_position: Vector2, delta: float, speed: float) -> Vector2:
    var away := (home - player_position).normalized()
    return home + away * delta * speed
