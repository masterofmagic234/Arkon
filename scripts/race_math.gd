extends RefCounted

# Level 2 — pure race mathematics.
# No scene, UI, or global-state ownership lives here.

const CURVE_TABLE := {
    0: 0.0,
    1: -0.9,
    2: 0.9,
    3: -1.8,
    4: 1.8,
    5: 0.9,
}

const TURN_SHIFT := {
    1: -18.0,
    2: 18.0,
    3: -14.0,
    4: 14.0,
}

static func curve_of(seg: int) -> float:
    return float(CURVE_TABLE.get(seg, 0.0))

static func accumulate_track_x(pattern: Array) -> PackedFloat32Array:
    var n := pattern.size()
    var out := PackedFloat32Array()
    out.resize(n)

    if n == 0:
        return out

    var i := 0
    var current_x := 0.0

    while i < n:
        var seg_type: int = int(pattern[i])
        var j := i + 1
        while j < n and int(pattern[j]) == seg_type:
            j += 1

        if TURN_SHIFT.has(seg_type):
            var delta_x: float = float(TURN_SHIFT[seg_type])
            var block_len: int = j - i
            for k in block_len:
                var t: float = float(k + 1) / float(block_len)
                var eased := (1.0 - cos(t * PI)) * 0.5
                out[i + k] = current_x + delta_x * eased
            current_x += delta_x
        else:
            for k in j - i:
                out[i + k] = current_x

        i = j

    # A closed track is an authoring invariant. Do not silently bend the
    # centerline to compensate for an invalid sum of turn shifts.
    return out

static func track_closure_error(pattern: Array) -> float:
    var total := 0.0
    var i := 0

    while i < pattern.size():
        var seg_type: int = int(pattern[i])
        var j := i + 1
        while j < pattern.size() and int(pattern[j]) == seg_type:
            j += 1

        if TURN_SHIFT.has(seg_type):
            total += float(TURN_SHIFT[seg_type])

        i = j

    return total

static func track_center_x(
        track_position: float,
        track_x: PackedFloat32Array
) -> float:
    var n := track_x.size()
    if n == 0:
        return 0.0
    if n == 1:
        return track_x[0]

    var base := int(floor(track_position))
    var t := track_position - floor(track_position)

    var p1: float = track_x[posmod(base, n)]
    var p2: float = track_x[posmod(base + 1, n)]

    if n < 4:
        return lerpf(p1, p2, t)

    var p0: float = track_x[posmod(base - 1, n)]
    var p3: float = track_x[posmod(base + 2, n)]

    var t2 := t * t
    var t3 := t2 * t

    return 0.5 * (
        2.0 * p1
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )

static func track_center_slope(
        track_position: float,
        track_x: PackedFloat32Array
) -> float:
    var n := track_x.size()
    if n < 2:
        return 0.0

    var base := int(floor(track_position))
    var t := track_position - floor(track_position)

    var p1: float = track_x[posmod(base, n)]
    var p2: float = track_x[posmod(base + 1, n)]

    if n < 4:
        return p2 - p1

    var p0: float = track_x[posmod(base - 1, n)]
    var p3: float = track_x[posmod(base + 2, n)]
    var t2 := t * t

    return 0.5 * (
        (-p0 + p2)
        + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t
        + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2
    )

static func track_heading(
        track_position: float,
        track_x: PackedFloat32Array,
        segment_height: float
) -> float:
    return -atan2(
        track_center_slope(track_position, track_x),
        maxf(absf(segment_height), 0.001)
    )

static func curve_at(
        track_position: float,
        pattern: Array
) -> float:
    var n := pattern.size()
    if n == 0:
        return 0.0

    var base := int(floor(track_position))
    var t := track_position - floor(track_position)

    const RADIUS := 2
    var c0 := 0.0
    var c1 := 0.0
    var w0 := 0.0
    var w1 := 0.0

    for k in range(-RADIUS, RADIUS + 1):
        var weight := float(RADIUS + 1 - abs(k))
        c0 += curve_of(int(pattern[posmod(base + k, n)])) * weight
        c1 += curve_of(int(pattern[posmod(base + 1 + k, n)])) * weight
        w0 += weight
        w1 += weight

    c0 /= maxf(w0, 0.001)
    c1 /= maxf(w1, 0.001)

    var eased_t := t * t * (3.0 - 2.0 * t)
    return lerpf(c0, c1, eased_t)

static func step_speed(
        speed: float,
        throttle: float,
        brake: float,
        dt: float,
        max_speed: float,
        accel: float,
        brake_force: float,
        drag: float
) -> float:
    var target := max_speed * clampf(throttle, 0.0, 1.0)

    if brake > 0.01:
        speed = maxf(
            speed - brake_force * brake * dt,
            0.0
        )

    if speed < target:
        speed = minf(
            speed + accel * dt,
            target
        )
    elif speed > target:
        speed = maxf(
            speed - accel * 0.5 * dt,
            target
        )

    # The simulation uses a fixed step; exponential damping keeps drag
    # mathematically stable rather than accumulating an Euler dt error.
    speed *= exp(-drag * dt * 0.001)
    return maxf(speed, 0.0)

static func steering_delta(
        steer_in: float,
        speed: float,
        dt: float,
        rate: float,
        max_speed: float
) -> float:
    var safe_max_speed := maxf(max_speed, 0.001)
    var factor := clampf(
        1.0 - (speed / safe_max_speed) * 0.55,
        0.45,
        1.0
    )
    return clampf(
        steer_in,
        -1.0,
        1.0
    ) * rate * factor * dt

static func road_offset(
        lateral_x: float,
        center_x: float,
        half_width: float
) -> float:
    if half_width <= 0.0:
        return 0.0
    return (lateral_x - center_x) / half_width

static func ai_brake_for(seg: int, distance_ahead: int) -> float:
    var c := absf(curve_of(seg))
    if c < 0.5:
        return 0.0

    var urgency := clampf(
        1.0 - float(distance_ahead) / 12.0,
        0.0,
        1.0
    )

    return clampf(
        c / 14.0 * urgency,
        0.0,
        1.0
    )

static func format_time(seconds: float) -> String:
    if seconds < 0.0:
        return "--:--.--"

    var m := int(seconds) / 60
    var s := int(seconds) % 60
    var cs := int(fmod(seconds, 1.0) * 100.0)

    return "%d:%02d.%02d" % [m, s, cs]
