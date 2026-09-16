extends RefCounted

static func can_attack(distance: float, damage_cooldown: float, attack_distance: float) -> bool:
    return distance < attack_distance and damage_cooldown <= 0.0
