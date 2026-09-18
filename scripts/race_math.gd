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

    # Treat curve_of() as a change in heading, not as a direct lateral
    # displacement. The old implementation integrated curvature straight into
    # X, which made a long corner look like a sequence of parallel straight
    # chords. A real sweeping road first changes its heading and then moves
    # sideways according to that heading.
    const HEADING_STEP := 0.06
    const LATERAL_STEP := 0.45

    var heading := 0.0
    var x := 0.0
    for i in n:
        heading += curve_of(pattern[i]) * HEADING_STEP
        x += sin(heading) * LATERAL_STEP
        out[i] = x

    # Close the centreline without destroying the shape of the bends.
    var end_x: float = out[n - 1]
    if absf(end_x) > 0.000001:
        for i in n:
            out[i] -= end_x * (float(i) / float(n - 1))

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
