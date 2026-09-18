extends RefCounted

# Чистая математика Level 2.

# Physical curvature is deliberately compact so the car can follow the road at speed.
# The renderer amplifies this separately for a much steeper visual sweep.
const CURVE_TABLE := {
    0: 0.0,
    1: -0.9,
    2: 0.9,
    3: -1.8,
    4: 1.8,
    5: 0.9,
}

static func curve_of(seg: int) -> float:
    return CURVE_TABLE.get(seg, 0.0)

static func accumulate_track_x(pattern: Array) -> PackedFloat32Array:
    var n := pattern.size()
    var out := PackedFloat32Array()
    out.resize(n)

    if n == 0:
        return out

    var raw_x := 0.0
    for i in n:
        raw_x += curve_of(pattern[i])

    # The track is designed to have zero net curvature.
    # Keep a tiny correction only as a guard against floating-point drift.
    var correction := 0.0
    if absf(raw_x) > 0.000001:
        correction = raw_x / float(n)

    var x := 0.0
    for i in n:
        x += curve_of(pattern[i]) - correction
        out[i] = x

    return out


static func step_speed(speed: float, throttle: float, brake: float, dt: float,
        max_speed: float, accel: float, brake_force: float, drag: float) -> float:
    var target := max_speed * clampf(throttle, 0.0, 1.0)
    if brake > 0.01:
        speed = maxf(speed - brake_force * brake * dt, 0.0)
    if speed < target:
        speed = minf(speed + accel * dt, target)
    elif speed > target:
        speed = maxf(speed - accel * 0.5 * dt, target)
    # Drag is intentionally mild: PLAYER_MAX_SPEED must be reachable while the\n    # throttle is held. The previous quadratic term made the car settle well\n    # below its configured top speed.\n    speed = maxf(speed - drag * speed * dt * 0.001, 0.0)
    return speed

static func steering_delta(steer_in: float, speed: float, dt: float,
        rate: float, max_speed: float) -> float:
    var factor := clampf(1.0 - (speed / max_speed) * 0.55, 0.45, 1.0)
    return clampf(steer_in, -1.0, 1.0) * rate * factor * dt

static func road_offset(lateral_x: float, center_x: float, half_width: float) -> float:
    if half_width <= 0.0:
        return 0.0
    return (lateral_x - center_x) / half_width

static func ai_brake_for(seg: int, distance_ahead: int) -> float:
    var c := absf(curve_of(seg))
    if c < 0.5:
        return 0.0
    var urgency := clampf(1.0 - float(distance_ahead) / 12.0, 0.0, 1.0)
    return clampf(c / 14.0 * urgency, 0.0, 1.0)

static func format_time(seconds: float) -> String:
    if seconds < 0.0:
        return "--:--.--"
    var m := int(seconds) / 60
    var s := int(seconds) % 60
    var cs := int(fmod(seconds, 1.0) * 100.0)
    return "%d:%02d.%02d" % [m, s, cs]
