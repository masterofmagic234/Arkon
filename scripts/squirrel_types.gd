extends RefCounted

# Archetype definitions. Single source of truth for squirrel stats.
enum Kind { SCOUT, THROWER, TANK, THIEF, RUNNER }

const TYPES := {
    Kind.SCOUT: {"name":"Разведчик", "hp":2, "speed":3.4, "attack_distance":1.5, "damage":12, "panic_radius":4.0, "flees":false},
    Kind.THROWER: {"name":"Стрелок", "hp":1, "speed":1.2, "attack_distance":5.5, "damage":8, "panic_radius":2.5, "flees":false},
    Kind.TANK: {"name":"Танк", "hp":4, "speed":1.8, "attack_distance":1.6, "damage":18, "panic_radius":0.0, "flees":false},
    Kind.THIEF: {"name":"Вор", "hp":1, "speed":5.0, "attack_distance":0.0, "damage":0, "panic_radius":3.0, "flees":false},
    Kind.RUNNER: {"name":"Гонец", "hp":1, "speed":6.5, "attack_distance":0.0, "damage":0, "panic_radius":5.0, "flees":true},
}

static func get_data(kind: int) -> Dictionary:
    return TYPES.get(kind, TYPES[Kind.SCOUT])
static func display_name(kind: int) -> String: return str(get_data(kind).get("name", "Белка"))
static func hp_of(kind: int) -> int: return int(get_data(kind).get("hp", 2))
static func speed_of(kind: int) -> float: return float(get_data(kind).get("speed", 3.4))
static func attack_distance_of(kind: int) -> float: return float(get_data(kind).get("attack_distance", 1.0))
static func damage_of(kind: int) -> int: return int(get_data(kind).get("damage", 12))
static func panic_radius_of(kind: int) -> float: return float(get_data(kind).get("panic_radius", 3.0))
static func is_melee(kind: int) -> bool: return kind == Kind.SCOUT or kind == Kind.TANK
