extends RefCounted
## Street-space staging and close editorial coverage of the physical raid.
## Framing is specified in world units so a wide phone never reveals the map.
const ARRIVAL_DURATION := 2.6
const VAN_START := Vector2(1218, 876)
const VAN_STOP := Vector2(352, 864)
const VAN_STOP_ROTATION := PI - .10
const VAN_SIZE := Vector2(122, 52)
const CURB_Y := 792.0
const STREET_BOTTOM := 988.0

static func arrival_transform(progress: float) -> Transform2D:
    var t := clampf(progress, 0, 1)
    var braking := 1.0 - pow(1.0 - t, 2.2)
    # Drift away from the pavement. The former negative arc cut the rear
    # corner through the diner even though the centre appeared on the road.
    var at := VAN_START.lerp(VAN_STOP, braking) + Vector2(0, 38 * sin(PI*t))
    return Transform2D(PI + .58*sin(PI*t) - .10*t, at)

static func arrival_shot(clock: float) -> Dictionary:
    var blend := smoothstep(0, 1, clampf(clock / ARRIVAL_DURATION, 0, 1))
    return {"id": &"street_arrival", "focus": Vector2(700,786).lerp(Vector2(420,810),blend), "extent": Vector2(840,450).lerp(Vector2(650,360),blend)}

static func deployment_shot(clock: float) -> Dictionary:
    # The squads continue moving during every cut. Reaction and doorway
    # inserts cover the long outside route instead of exposing a distant parade.
    if clock < 2.4:
        return {"id": &"sliding_door", "focus": Vector2(350,852), "extent": Vector2(480,300)}
    if clock < 4.1:
        return {"id": &"front_door_team", "focus": Vector2(210,758), "extent": Vector2(440,290)}
    if clock < 5.6:
        return {"id": &"kitchen_reaction", "focus": Vector2(680,140), "extent": Vector2(520,340)}
    if clock < 7.2:
        return {"id": &"service_door_team", "focus": Vector2(1015,856), "extent": Vector2(540,330)}
    if clock < 9.5:
        return {"id": &"west_window_team", "focus": Vector2(105,432), "extent": Vector2(480,300)}
    if clock < 11.0:
        return {"id": &"north_window_team", "focus": Vector2(270,10), "extent": Vector2(480,330)}
    return breach_shot(&"breach_ready")

static func breach_shot(id: StringName = &"window_breach") -> Dictionary:
    return {"id": id, "focus": Vector2(105,432), "extent": Vector2(480,300)}

static func zoom_for(viewport: Vector2, extent: Vector2) -> float:
    return maxf(viewport.x / extent.x, viewport.y / extent.y)

static func footprint(pose: Transform2D, scale_: Vector2 = Vector2.ONE) -> PackedVector2Array:
    var half := VAN_SIZE * scale_ * .5
    var points := PackedVector2Array()
    for point in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
        points.append(pose * point)
    return points
