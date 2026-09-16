extends RefCounted

# Small state-only helper. It advances the timers exactly as the V20 loop did.
func tick(delta: float, timers: Dictionary) -> Dictionary:
    return {
        "fire_cooldown": maxf(0.0, float(timers.get("fire_cooldown", 0.0)) - delta),
        "damage_cooldown": maxf(0.0, float(timers.get("damage_cooldown", 0.0)) - delta),
        "recoil_time": maxf(0.0, float(timers.get("recoil_time", 0.0)) - delta),
        "message_time": maxf(0.0, float(timers.get("message_time", 0.0)) - delta)
    }
