class_name SquirrelQuery
extends RefCounted

static func should_chase(distance: float) -> bool:
    return distance < 6.0 and distance > 1.8

static func should_attack(distance: float) -> bool:
    return distance < 1.0
