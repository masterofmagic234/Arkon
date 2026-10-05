extends RefCounted
class_name RaceAuthoredTrackData

const TRACK_SCALE := 6.80
const RAW_ROUTE_CENTER := Vector2(23.569, -7.0675)
const RAW_ROAD_Y := 1.026
const SAMPLES_PER_SEGMENT := 5

# Extracted from the connected London Short road units in the supplied GLB.
# The authored GLB is modeled at a toy-scale relative to the gameplay car,
# so both the visual track and gameplay centerline use the same 4x correction:
# unit_000..015 followed by unit_020..031.
static var CONTROL_POINTS := PackedVector2Array([
    Vector2(29.495, -2.831),
    Vector2(28.502, -3.819),
    Vector2(27.370, -3.278),
    Vector2(25.826, -3.923),
    Vector2(23.901, -5.102),
    Vector2(22.008, -5.371),
    Vector2(20.325, -5.688),
    Vector2(18.756, -5.997),
    Vector2(16.602, -5.744),
    Vector2(15.320, -6.817),
    Vector2(16.267, -8.403),
    Vector2(15.613, -9.956),
    Vector2(15.750, -10.691),
    Vector2(16.796, -11.304),
    Vector2(17.961, -10.632),
    Vector2(18.708, -10.480),
    Vector2(19.969, -10.370),
    Vector2(21.645, -10.137),
    Vector2(23.707, -9.820),
    Vector2(25.581, -9.696),
    Vector2(26.760, -8.751),
    Vector2(28.920, -8.081),
    Vector2(29.854, -8.747),
    Vector2(31.159, -10.175),
    Vector2(31.818, -8.055),
    Vector2(30.948, -6.125),
    Vector2(31.575, -3.335),
    Vector2(30.400, -3.036)
])

static func build_centerline() -> PackedVector3Array:
    var result := PackedVector3Array()
    var count := CONTROL_POINTS.size()

    for i in range(count):
        var p0: Vector2 = CONTROL_POINTS[(i - 1 + count) % count]
        var p1: Vector2 = CONTROL_POINTS[i]
        var p2: Vector2 = CONTROL_POINTS[(i + 1) % count]
        var p3: Vector2 = CONTROL_POINTS[(i + 2) % count]

        for sample in range(SAMPLES_PER_SEGMENT):
            var t := float(sample) / float(SAMPLES_PER_SEGMENT)
            var t2 := t * t
            var t3 := t2 * t

            var point := 0.5 * (
                2.0 * p1
                + (-p0 + p2) * t
                + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
            )

            point = (
                point - RAW_ROUTE_CENTER
            ) * TRACK_SCALE

            result.append(
                Vector3(point.x, 0.0, point.y)
            )

    return result

static func get_track_transform() -> Transform3D:
    return Transform3D(
        Basis.IDENTITY.scaled(
            Vector3.ONE * TRACK_SCALE
        ),
        Vector3(
            -RAW_ROUTE_CENTER.x * TRACK_SCALE,
            -RAW_ROAD_Y * TRACK_SCALE,
            -RAW_ROUTE_CENTER.y * TRACK_SCALE
        )
    )
