extends Node2D

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")

const CAMERA_DEPTH: float = 0.84
const CAMERA_BEHIND: float = 6.0
const FAR_SEGMENTS: int = 240
const VISUAL_SUBDIVISIONS: int = 4
const HORIZON_FRACTION: float = 0.50
const ROAD_SCREEN_SCALE: float = 0.75
const ROAD_WORLD_WIDTH: float = 9.0
const RENDER_CURVE_SCALE: float = 0.16
const ROAD_CURVE_VISUAL_SCALE: float = 7.0
const CURVE_SMOOTH_RADIUS: int = 2
const PLAYER_LATERAL_SCREEN_SCALE: float = 0.42
const SEGMENT_WORLD_LEN: float = 50.0 / float(VISUAL_SUBDIVISIONS)
const ASPHALT_UV_PER_SEGMENT: float = 0.32
const GRASS_WORLD_UV_SCALE: float = 0.04
const ROAD_STEP: int = 2

const COL_SKY_TOP := Color(0.35, 0.55, 1.00)
const COL_SKY_BOTTOM := Color(0.60, 0.78, 1.00)
const COL_CITY := Color(0.28, 0.28, 0.48)
const COL_GRASS_LIGHT := Color(0.35, 0.85, 0.20)
const COL_GRASS_DARK := Color(0.20, 0.60, 0.10)
const COL_ROAD_LIGHT := Color(0.60, 0.60, 0.65)
const COL_ROAD_DARK := Color(0.45, 0.45, 0.50)
const COL_RUMBLE_LIGHT := Color(1.00, 1.00, 1.00)
const COL_RUMBLE_DARK := Color(0.90, 0.15, 0.15)
const COL_LANE := Color(0.95, 0.95, 0.95)

var race_state = null
var player_car = null
var ai_cars: Array = []
var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()
var track_size: int = 0
var sky_reference_track_x: float = 0.0

var ssx := PackedFloat32Array()
var ssy := PackedFloat32Array()
var shw := PackedFloat32Array()
var sidx := PackedInt32Array()

var _tex_cache: Dictionary = {}

var city_texture: Texture2D
var moon_texture: Texture2D
var grass_texture: Texture2D
var grass_far_texture: Texture2D
var asphalt_texture: Texture2D
var rumble_texture: Texture2D
var oak_texture: Texture2D
var pine_texture: Texture2D
var lamp_texture: Texture2D
var squirrel_mobile_texture: Texture2D
var oka_texture: Texture2D

func _tex(path: String) -> Texture2D:
    if _tex_cache.has(path):
        return _tex_cache[path] as Texture2D
    var tex: Texture2D = load(path) as Texture2D
    _tex_cache[path] = tex
    return tex

func _find_tex(paths: Array) -> Texture2D:
    for path in paths:
        var p: String = str(path)
        var tex: Texture2D = _tex(p)
        if tex != null:
            return tex
    return null

func _ready() -> void:
    # Grass/asphalt use UVs outside 0..1. Explicit repeat prevents Godot's
    # default edge-clamping from stretching the texture into horizontal bands.
    texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    # The asphalt and roadside billboards are viewed at steep angles and at
    # very different scales. Mipmaps + anisotropic filtering reduce the
    # smeared/aliased look without changing the road width or curve math.
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    ssx.resize(FAR_SEGMENTS)
    ssy.resize(FAR_SEGMENTS)
    shw.resize(FAR_SEGMENTS)
    sidx.resize(FAR_SEGMENTS)
    city_texture = _find_tex(["res://assets/city_night.png", "res://city_night.png"])
    moon_texture = _find_tex(["res://assets/moon.png", "res://moon.png"])
    grass_texture = _find_tex(["res://assets/grass_tile.png", "res://assets/grass.png"])
    grass_far_texture = _find_tex(["res://assets/grass.png", "res://assets/grass_tile.png"])
    asphalt_texture = _find_tex(["res://assets/asphalt.png", "res://asphalt.png"])
    rumble_texture = _find_tex(["res://assets/rumble.png", "res://rumble.png"])
    oak_texture = _find_tex(["res://assets/oak_tree.png", "res://oak_tree.png"])
    pine_texture = _find_tex(["res://assets/pine_tree.png", "res://pine_tree.png"])
    lamp_texture = _find_tex(["res://assets/street_lamp.png", "res://street_lamp.png"])
    squirrel_mobile_texture = _find_tex(["res://assets/squirrel_mobile.png", "res://squirrel_mobile.png"])
    oka_texture = _find_tex(["res://assets/oka.png", "res://oka.png"])
    queue_redraw()

func bind(state, player_ref, ais_ref: Array, pattern: Array, tx: PackedFloat32Array) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    track_x = tx
    track_size = pattern.size()
    sky_reference_track_x = _smooth_track_x(float(player_ref.segment_index % maxi(track_size, 1)) + clampf(player_ref.segment_progress, 0.0, 0.9999)) if track_size > 0 else 0.0
    queue_redraw()

func _process(_delta: float) -> void:
    # Forward motion is already represented by the player's segment_progress.
    # A second scrolling clock would double-count motion and introduce jumps.
    queue_redraw()

func _smooth_track_x(position: float) -> float:
    # The raw track_x values are control points. Linear interpolation makes
    # every physical segment a straight chord, which is exactly the visual
    # problem we are avoiding: straight -> small step -> straight.
    # Catmull-Rom interpolation keeps the tangent continuous between points,
    # producing one actual sweeping arc.
    if track_size < 4:
        return track_x[posmod(int(floor(position)), track_size)]

    var base: int = int(floor(position))
    var t: float = position - floor(position)
    var p0: float = track_x[posmod(base - 1, track_size)]
    var p1: float = track_x[posmod(base, track_size)]
    var p2: float = track_x[posmod(base + 1, track_size)]
    var p3: float = track_x[posmod(base + 2, track_size)]

    var t2: float = t * t
    var t3: float = t2 * t
    return 0.5 * (
        (2.0 * p1)
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )

func _render_curve_for_segment(seg: int) -> float:
    # Classic NES/OutRun-style curve profile: the road is controlled by a
    # per-segment curve value, not by a world-space centerline alone.
    # A small weighted neighborhood smooths the entry/exit of a corner.
    var total := 0.0
    var weight_total := 0.0
    for k in range(-CURVE_SMOOTH_RADIUS, CURVE_SMOOTH_RADIUS + 1):
        var weight: float = float(CURVE_SMOOTH_RADIUS + 1 - abs(k))
        var idx: int = posmod(seg + k, track_size)
        total += RaceMath.curve_of(track_pattern[idx]) * weight
        weight_total += weight
    return total / weight_total

func _render_curve_at(position: float) -> float:
    var base: int = int(floor(position))
    var t: float = position - floor(position)
    var c0: float = _render_curve_for_segment(base)
    var c1: float = _render_curve_for_segment(base + 1)
    var eased_t: float = t * t * (3.0 - 2.0 * t)
    return lerpf(c0, c1, eased_t)

func _draw() -> void:
    if race_state == null or player_car == null or track_size == 0 or track_x.is_empty():
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    # Keep the existing Level 2 drawing boundary. HUD/layout owns the rest.
    var draw_h: float = 496.0
    var horizon_y: float = draw_h * HORIZON_FRACTION

    _draw_sky(w, horizon_y)
    _draw_road(w, draw_h, horizon_y)
    _draw_props(w, draw_h, horizon_y)
    _draw_ai_cars(w, draw_h, horizon_y)
    _draw_player_car(w, draw_h)

func _draw_sky(w: float, horizon_y: float) -> void:
    # Dark base behind the distant skyline.
    draw_rect(Rect2(0.0, 0.0, w, horizon_y), Color(0.035, 0.07, 0.13), true)

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)
    var relative_track_x: float = camera_track_x - sky_reference_track_x

    # CITY: the bottom of the source image is the actual horizon line.
    # We map the complete city image from its top edge down to horizon_y.
    # This is intentionally different from cropping the lower part of the
    # image: the skyline must occupy the space FROM the horizon AND ABOVE.
    if city_texture != null:
        var tex_w: float = float(city_texture.get_width())
        var tex_h: float = float(city_texture.get_height())
        var city_scale: float = 1.18
        var city_h: float = horizon_y * 1.35
        var city_top_y: float = horizon_y - city_h

        # Horizontal enlargement + world-relative parallax. The vertical
        # mapping remains 0..1 so no part of the skyline is lost at the
        # horizon because of an arbitrary v_start crop.
        var parallax_u: float = (relative_track_x * 12.0) / tex_w
        var u_span: float = 1.0 / city_scale
        var u_start: float = parallax_u
        var u_end: float = u_start + u_span

        var pts := PackedVector2Array([
            Vector2(0.0, city_top_y),
            Vector2(w, city_top_y),
            Vector2(w, horizon_y),
            Vector2(0.0, horizon_y)
        ])
        var uvs := PackedVector2Array([
            Vector2(u_start, 0.0),
            Vector2(u_end, 0.0),
            Vector2(u_end, 1.0),
            Vector2(u_start, 1.0)
        ])
        var cols := PackedColorArray([
            Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE
        ])
        draw_polygon(pts, cols, uvs, city_texture)

    # Moon remains a separate, much more distant layer.
    if moon_texture != null:
        var moon_size: float = minf(horizon_y * 0.46, w * 0.16)
        var moon_x: float = posmod(
            w * 0.72 - relative_track_x * 12.0 * 0.2 + w,
            w * 2.0
        ) - w * 0.5
        draw_texture_rect(
            moon_texture,
            Rect2(moon_x, horizon_y * 0.10, moon_size, moon_size),
            false,
            Color(1.0, 1.0, 1.0, 0.96)
        )

func _draw_road(w: float, h: float, horizon_y: float) -> void:
    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var half_w: float = w * 0.5
    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)

    var max_dist_segments: float = float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS)
    var max_dz: float = max_dist_segments * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
    var min_w: float = CAMERA_BEHIND / max_dz
    var max_w: float = 1.0

    # Screen-linear sample distribution gives an even vertical mesh density.
    # World distance is reconstructed from the same projection, so road,
    # props and AI can all use one consistent camera-space model.
    for i in range(FAR_SEGMENTS):
        var t: float = float(i) / float(FAR_SEGMENTS - 1)
        var current_w: float = lerpf(max_w, min_w, t)

        var dz: float = CAMERA_BEHIND / current_w
        var clamped_dist: float = (dz - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT
        var absolute_seg: float = float(cam_seg) + cam_progress + clamped_dist

        var road_center_x: float = _smooth_track_x(absolute_seg) - camera_track_x
        var scale: float = CAMERA_DEPTH / dz

        ssx[i] = half_w + scale * road_center_x * half_w
        ssy[i] = horizon_y + (h - horizon_y) * current_w
        shw[i] = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        sidx[i] = posmod(int(floor(absolute_seg)), track_size)

    # Grass: world-space UVs derived from the exact same projected samples.
    var gi: int = FAR_SEGMENTS - 2
    while gi >= 0:
        var gj: int = min(gi + ROAD_STEP, FAR_SEGMENTS - 1)
        if ssy[gi] > ssy[gj]:
            var gl0 := Vector2(0.0, ssy[gi])
            var gr0 := Vector2(w, ssy[gi])
            var gl1 := Vector2(0.0, ssy[gj])
            var gr1 := Vector2(w, ssy[gj])

            var road_l0 := Vector2(ssx[gi] - shw[gi], ssy[gi])
            var road_r0 := Vector2(ssx[gi] + shw[gi], ssy[gi])
            var road_l1 := Vector2(ssx[gj] - shw[gj], ssy[gj])
            var road_r1 := Vector2(ssx[gj] + shw[gj], ssy[gj])

            var t_i: float = float(gi) / float(FAR_SEGMENTS - 1)
            var t_j: float = float(gj) / float(FAR_SEGMENTS - 1)
            var dz_i: float = CAMERA_BEHIND / lerpf(max_w, min_w, t_i)
            var dz_j: float = CAMERA_BEHIND / lerpf(max_w, min_w, t_j)
            var dist_i: float = (dz_i - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT
            var dist_j: float = (dz_j - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT

            var absolute_seg_i: float = float(cam_seg) + cam_progress + dist_i
            var absolute_seg_j: float = float(cam_seg) + cam_progress + dist_j

            var grass_band: int = int(floor(absolute_seg_i))
            var grass_tint: Color = COL_GRASS_LIGHT if posmod(grass_band, 2) == 0 else COL_GRASS_DARK

            # The roadside is a perspective field/embankment, not a flat
            # screen fill. Its outer edge rises toward the horizon, which gives
            # the grass the same "surface going uphill into the distance" look
            # as the reference image while leaving the skyline above it visible.
            var embankment_factor: float = 0.28
            var field_top_y_i: float = lerpf(horizon_y, ssy[gi], embankment_factor)
            var field_top_y_j: float = lerpf(horizon_y, ssy[gj], embankment_factor)

            var left_top_i := Vector2(0.0, field_top_y_i)
            var left_top_j := Vector2(0.0, field_top_y_j)
            var right_top_i := Vector2(w, field_top_y_i)
            var right_top_j := Vector2(w, field_top_y_j)

            # Keep the actual road edge untouched. Only the outside boundary
            # of the grass is lifted toward the horizon.
            var left_points := PackedVector2Array([
                left_top_i, road_l0, road_l1, left_top_j
            ])
            var right_points := PackedVector2Array([
                road_r0, right_top_i, right_top_j, road_r1
            ])

            if grass_texture != null:
                var half_road := ROAD_WORLD_WIDTH * 0.5

                var world_dx_per_px_i: float = (half_road * ROAD_SCREEN_SCALE) / maxf(shw[gi], 0.001)
                var world_dx_per_px_j: float = (half_road * ROAD_SCREEN_SCALE) / maxf(shw[gj], 0.001)

                # UV X follows the road-relative lateral offset. This keeps
                # the texture wrapped around the curved road instead of
                # dragging it sideways with the global track center.
                var offset_left_i := (0.0 - ssx[gi]) * world_dx_per_px_i
                var offset_right_i := (w - ssx[gi]) * world_dx_per_px_i
                var offset_left_j := (0.0 - ssx[gj]) * world_dx_per_px_j
                var offset_right_j := (w - ssx[gj]) * world_dx_per_px_j

                # UV Y is tied to actual camera distance. The top of the field
                # gets a small extra upward texture span so grass blades/rows
                # visibly continue up the embankment instead of ending at a
                # flat horizontal strip.
                var uv_y_i := -dz_i * GRASS_WORLD_UV_SCALE
                var uv_y_j := -dz_j * GRASS_WORLD_UV_SCALE
                var uv_top_i := uv_y_i - 0.65
                var uv_top_j := uv_y_j - 0.65

                var left_uvs := PackedVector2Array([
                    Vector2(offset_left_i * GRASS_WORLD_UV_SCALE, uv_top_i),
                    Vector2(-half_road * GRASS_WORLD_UV_SCALE, uv_y_i),
                    Vector2(-half_road * GRASS_WORLD_UV_SCALE, uv_y_j),
                    Vector2(offset_left_j * GRASS_WORLD_UV_SCALE, uv_top_j)
                ])
                var right_uvs := PackedVector2Array([
                    Vector2(half_road * GRASS_WORLD_UV_SCALE, uv_y_i),
                    Vector2(offset_right_i * GRASS_WORLD_UV_SCALE, uv_top_i),
                    Vector2(offset_right_j * GRASS_WORLD_UV_SCALE, uv_top_j),
                    Vector2(half_road * GRASS_WORLD_UV_SCALE, uv_y_j)
                ])

                var grass_cols := PackedColorArray([
                    grass_tint, grass_tint, grass_tint, grass_tint
                ])
                draw_polygon(left_points, grass_cols, left_uvs, grass_texture)
                draw_polygon(right_points, grass_cols, right_uvs, grass_texture)
            else:
                draw_colored_polygon(left_points, grass_tint)
                draw_colored_polygon(right_points, grass_tint)
        gi -= ROAD_STEP

    # Asphalt: continuous world-space V coordinates with a deliberately
    # denser repeat so the texture reads as actual road surface detail.
    var i: int = FAR_SEGMENTS - 2
    while i >= 0:
        var j: int = min(i + ROAD_STEP, FAR_SEGMENTS - 1)
        if ssy[i] > ssy[j]:
            var l0 := Vector2(ssx[i] - shw[i], ssy[i])
            var r0 := Vector2(ssx[i] + shw[i], ssy[i])
            var l1 := Vector2(ssx[j] - shw[j], ssy[j])
            var r1 := Vector2(ssx[j] + shw[j], ssy[j])

            var t_i: float = float(i) / float(FAR_SEGMENTS - 1)
            var t_j: float = float(j) / float(FAR_SEGMENTS - 1)
            var dz_i: float = CAMERA_BEHIND / lerpf(max_w, min_w, t_i)
            var dz_j: float = CAMERA_BEHIND / lerpf(max_w, min_w, t_j)
            var absolute_seg_i: float = float(cam_seg) + cam_progress + (dz_i - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT
            var absolute_seg_j: float = float(cam_seg) + cam_progress + (dz_j - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT

            var road_band: int = int(floor(absolute_seg_i * 10.0))
            var road_dark: bool = posmod(road_band, 2) == 0
            var road_col: Color = COL_ROAD_DARK if road_dark else COL_ROAD_LIGHT

            var road_points := PackedVector2Array([l0, r0, r1, l1])
            var road_uvs := PackedVector2Array([
                Vector2(0.0, 1.0), Vector2(1.0, 1.0),
                Vector2(1.0, 0.0), Vector2(0.0, 0.0)
            ])

            if asphalt_texture != null:
                var asphalt_uv_repeat: float = 10.0
                var uv_v0: float = absolute_seg_i * asphalt_uv_repeat
                var uv_v1: float = absolute_seg_j * asphalt_uv_repeat
                var asphalt_uvs := PackedVector2Array([
                    Vector2(0.0, uv_v0), Vector2(1.0, uv_v0),
                    Vector2(1.0, uv_v1), Vector2(0.0, uv_v1)
                ])
                var asphalt_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
                draw_polygon(road_points, asphalt_cols, asphalt_uvs, asphalt_texture)
            else:
                draw_colored_polygon(road_points, road_col)

            var rw0: float = maxf(2.0, shw[i] * 0.12)
            var rw1: float = maxf(2.0, shw[j] * 0.12)
            var left_rumble := PackedVector2Array([
                l0, Vector2(l0.x + rw0, l0.y),
                Vector2(l1.x + rw1, l1.y), l1
            ])
            var right_rumble := PackedVector2Array([
                Vector2(r0.x - rw0, r0.y), r0,
                r1, Vector2(r1.x - rw1, r1.y)
            ])

            if rumble_texture != null:
                draw_colored_polygon(left_rumble, Color.WHITE, road_uvs, rumble_texture)
                draw_colored_polygon(right_rumble, Color.WHITE, road_uvs, rumble_texture)
            else:
                var rumble_band: int = int(floor(absolute_seg_i * 20.0))
                var rumb_col: Color = COL_RUMBLE_LIGHT if posmod(rumble_band, 2) == 0 else Color.BLACK
                draw_colored_polygon(left_rumble, rumb_col)
                draw_colored_polygon(right_rumble, rumb_col)

            if road_dark:
                var lw0: float = maxf(2.0, shw[i] * 0.035)
                var lw1: float = maxf(2.0, shw[j] * 0.035)
                var cx0: float = ssx[i]
                var cx1: float = ssx[j]
                draw_colored_polygon(PackedVector2Array([
                    Vector2(cx0 - lw0 * 0.5, ssy[i]),
                    Vector2(cx0 + lw0 * 0.5, ssy[i]),
                    Vector2(cx1 + lw1 * 0.5, ssy[j]),
                    Vector2(cx1 - lw1 * 0.5, ssy[j])
                ]), COL_LANE)

            if sidx[i] == 0:
                var m0 = l0.lerp(r0, 0.5)
                var m1 = l1.lerp(r1, 0.5)
                draw_colored_polygon(PackedVector2Array([l0, m0, m1, l1]), Color.WHITE)
                draw_colored_polygon(PackedVector2Array([m0, r0, r1, m1]), Color.BLACK)
        i -= ROAD_STEP

func _draw_billboard(texture: Texture2D, center_x: float, bottom_y: float, width: float, height: float, modulate := Color.WHITE) -> void:
    if texture == null or width <= 1.0 or height <= 1.0:
        return
    draw_texture_rect(
        texture,
        Rect2(center_x - width * 0.5, bottom_y - height, width, height),
        false,
        modulate
    )

func _draw_props(w: float, h: float, horizon_y: float) -> void:
    if oak_texture == null and pine_texture == null and lamp_texture == null:
        return

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var max_visible_segments: int = int(ceil(float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS))) - 1

    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)
    var half_w: float = w * 0.5

    for ahead in range(max_visible_segments, -1, -1):
        var world_seg: int = posmod(cam_seg + ahead, track_size)

        if posmod(world_seg, 2) != 0:
            continue

        var distance_segments: float = float(ahead) - cam_progress
        if distance_segments <= 0.01:
            continue

        var dz: float = distance_segments * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        if dz <= 1.0:
            continue

        # Единая мировая проекция, зеркальная логике _draw_road.
        var absolute_seg: float = float(cam_seg) + float(ahead)
        var road_center_x: float = _smooth_track_x(absolute_seg) - camera_track_x
        var scale: float = CAMERA_DEPTH / dz

        var screen_y: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        if screen_y <= horizon_y or screen_y > h + 400.0:
            continue

        var road_cx: float = half_w + scale * road_center_x * half_w
        var road_half: float = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE

        var px_per_meter: float = scale * w * ROAD_SCREEN_SCALE
        var gap_world: float = 2.5
        var gap_screen: float = gap_world * px_per_meter

        var side: float = -1.0 if posmod(world_seg / 2, 2) == 0 else 1.0
        var sx: float = road_cx + side * (road_half + gap_screen)

        if posmod(world_seg, 12) == 0 and lamp_texture != null:
            var prop_w: float = clampf(2.0 * px_per_meter, 4.0, 300.0)
            var prop_h: float = clampf(8.0 * px_per_meter, 16.0, 800.0)
            # Фонарный столб утапливаем слегка (2% высоты).
            _draw_billboard(lamp_texture, sx, screen_y + prop_h * 0.02, prop_w, prop_h)
        else:
            var tree_tex: Texture2D = pine_texture if (posmod(world_seg / 4, 2) == 0 and pine_texture != null) else oak_texture
            if tree_tex != null:
                var prop_w: float = clampf(14.0 * px_per_meter, 8.0, 900.0)
                var prop_h: float = clampf(18.0 * px_per_meter, 10.0, 1100.0)
                # Деревья утапливаем глубже (5% высоты), чтобы скрыть срез ствола в траве.
                _draw_billboard(tree_tex, sx, screen_y + prop_h * 0.05, prop_w, prop_h)

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    if player_car == null:
        return

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var p_prog: float = player_car.progress(track_size)
    var half_road: float = ROAD_WORLD_WIDTH * 0.5
    var half_w: float = w * 0.5

    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)
    var max_dist: float = float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS)

    for ai_controller in ai_cars:
        if ai_controller == null or ai_controller.car == null:
            continue

        var ai = ai_controller.car
        var ai_prog: float = ai.progress(track_size)

        # The track is cyclic. Always measure the AI forward from the player,
        # including the case where the AI has crossed the start/finish line.
        var delta_segments: float = posmod(ai_prog - p_prog, float(track_size))

        if delta_segments < 0.1 or delta_segments >= max_dist:
            continue

        # Use the same perspective equation as _draw_road and _draw_props.
        var dz: float = delta_segments * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        dz = maxf(1.0, dz)
        var scale: float = CAMERA_DEPTH / dz
        var sy: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz

        if sy < horizon_y or sy > h:
            continue

        # The AI's world position is projected through the same smoothed
        # centerline used by the road renderer. Do not use linear track_x
        # interpolation here; that would make cars drift on curved sections.
        var ai_absolute_seg: float = float(ai.segment_index % track_size) + ai.segment_progress
        var ai_track_center: float = _smooth_track_x(ai_absolute_seg)
        var ai_relative_center: float = ai_track_center - camera_track_x

        var norm_offset: float = (ai.world_x - ai_track_center) / half_road
        norm_offset = clampf(norm_offset, -1.25, 1.25)

        var road_cx: float = half_w + scale * ai_relative_center * half_w
        var current_shw: float = scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        var sx: float = road_cx + norm_offset * current_shw

        var car_w: float = clampf(scale * ROAD_WORLD_WIDTH * w * 0.35, 8.0, 190.0)
        var car_h: float = car_w * 0.56

        if squirrel_mobile_texture != null:
            _draw_billboard(squirrel_mobile_texture, sx, sy, car_w * 1.25, car_h * 1.55)
        else:
            draw_rect(Rect2(sx - car_w * 0.5, sy - car_h, car_w, car_h), Color(0.75, 0.15, 0.15), true)
            draw_rect(Rect2(sx - car_w * 0.4, sy - car_h * 0.7, car_w * 0.8, car_h * 0.3), Color(1.0, 1.0, 1.0), true)

const PLAYER_STEER_SHIFT: float = 0.075
const PLAYER_STEER_TILT_DEG: float = 5.0

func _draw_player_car(w: float, h: float) -> void:
    var base_y: float = h * 0.985
    var car_w: float = w * 0.14
    var car_h: float = car_w * 0.55

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var camera_track_x: float = _smooth_track_x(float(cam_seg) + cam_progress)
    var half_road: float = ROAD_WORLD_WIDTH * 0.5
    var lateral: float = 0.0
    if half_road > 0.0:
        lateral = clampf((player_car.world_x - camera_track_x) / half_road, -1.0, 1.0)

    # Keep Oka's real road position and add only a small visual steering
    # response. Steering is input feedback, not a replacement for physics.
    var steer: float = clampf(player_car.steer_in, -1.0, 1.0)
    var steer_shift_x: float = -steer * w * PLAYER_STEER_SHIFT
    var cx: float = w * 0.5 + lateral * w * PLAYER_LATERAL_SCREEN_SCALE + steer_shift_x
    var tilt_rad: float = steer * deg_to_rad(PLAYER_STEER_TILT_DEG)

    if oka_texture != null:
        draw_set_transform(Vector2(cx, base_y), tilt_rad, Vector2.ONE)
        draw_texture_rect(
            oka_texture,
            Rect2(-car_w * 0.775, -car_h * 1.75, car_w * 1.55, car_h * 1.75),
            false
        )
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    else:
        draw_set_transform(Vector2(cx, base_y), tilt_rad, Vector2.ONE)
        draw_rect(Rect2(-car_w * 0.55, car_h * 0.1, car_w * 1.1, car_h * 0.2), Color(0, 0, 0, 0.4), true)
        draw_rect(Rect2(-car_w * 0.5, -car_h, car_w, car_h * 0.7), Color(0.85, 0.1, 0.1), true)
        draw_rect(Rect2(-car_w * 0.5, -car_h * 1.05, car_w, car_h * 0.15), Color(1, 1, 1), true)
        draw_rect(Rect2(-car_w * 0.55, -car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
        draw_rect(Rect2(car_w * 0.39, -car_h * 0.5, car_w * 0.16, car_h * 0.4), Color(0.05, 0.05, 0.05), true)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
