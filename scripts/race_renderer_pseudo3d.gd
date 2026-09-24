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
const PLAYFIELD_FRACTION: float = 496.0 / 720.0
const GRASS_WALL_STEP: int = 4

# Textured furrow tinting for the nearest roadside grass wall.
# The texture remains the base detail; these tints add broad field-row
# variation without extra draw calls for shadows/highlights.
const FURROW_SAMPLE_SPEED: float = 0.6
const FURROW_SHADOW_TINT: Color = Color(0.42, 0.62, 0.36, 1.0)
const FURROW_LIGHT_TINT: Color = Color(1.0, 1.0, 0.72, 1.0)
const FURROW_NEUTRAL_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)


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

func _smooth_track_x(track_position: float) -> float:
    # The raw track_x values are control points. Linear interpolation makes
    # every physical segment a straight chord, which is exactly the visual
    # problem we are avoiding: straight -> small step -> straight.
    # Catmull-Rom interpolation keeps the tangent continuous between points,
    # producing one actual sweeping arc.
    if track_size < 4:
        return track_x[posmod(int(floor(track_position)), track_size)]

    var base: int = int(floor(track_position))
    var t: float = track_position - floor(track_position)
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

func _render_curve_at(track_position: float) -> float:
    var base: int = int(floor(track_position))
    var t: float = track_position - floor(track_position)
    var c0: float = _render_curve_for_segment(base)
    var c1: float = _render_curve_for_segment(base + 1)
    var eased_t: float = t * t * (3.0 - 2.0 * t)
    return lerpf(c0, c1, eased_t)

func _draw() -> void:
    if race_state == null or player_car == null or track_size == 0 or track_x.is_empty():
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    # The playfield is derived from the real viewport. The HUD uses the same
    # normalized design boundary, so other aspect ratios no longer inherit 496px.
    var draw_h: float = maxf(1.0, vp.y * PLAYFIELD_FRACTION)
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
        var moon_x: float = fposmod(
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
        var projection_scale: float = CAMERA_DEPTH / dz

        ssx[i] = half_w + projection_scale * road_center_x * half_w
        ssy[i] = horizon_y + (h - horizon_y) * current_w
        shw[i] = projection_scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        sidx[i] = posmod(int(floor(absolute_seg)), track_size)

    # Grass: continuous layered roadside walls.
    # Keep the broad field as two cheap polygons, then build the roadside
    # terraces with progressively fewer samples as they move into the distance.
    # This preserves the curved-wall silhouette while cutting Canvas commands
    # heavily versus the old 48-sample-per-tier implementation.
    const WALL_TIERS: int = 5
    const WALL_SAMPLES_NEAR: int = 32
    const WALL_SAMPLES_MID: int = 12
    const WALL_SAMPLES_FAR: int = 8
    var wall_offsets := [7.0, 70.0, 155.0, 260.0, 390.0]
    var wall_bases := [0.0, 18.0, 38.0, 60.0, 84.0]
    var wall_heights := [300.0, 190.0, 130.0, 90.0, 62.0]

    # Broad solid field first. It stays untextured so the old radial UV
    # artifact cannot return.
    var field_left := PackedVector2Array()
    var field_right := PackedVector2Array()
    const FIELD_SAMPLES: int = 32
    for sample in range(FIELD_SAMPLES):
        var u: float = float(sample) / float(FIELD_SAMPLES - 1)
        var idx_f: float = lerpf(float(FAR_SEGMENTS - 2), 0.0, u)
        var idx: int = clampi(int(round(idx_f)), 0, FAR_SEGMENTS - 2)
        var fy: float = lerpf(horizon_y, ssy[idx], 0.88)
        field_left.append(Vector2(0.0, fy))
        field_right.append(Vector2(w, fy))
    for sample in range(FIELD_SAMPLES - 1, -1, -1):
        var u: float = float(sample) / float(FIELD_SAMPLES - 1)
        var idx_f: float = lerpf(float(FAR_SEGMENTS - 2), 0.0, u)
        var idx: int = clampi(int(round(idx_f)), 0, FAR_SEGMENTS - 2)
        var fy: float = lerpf(horizon_y, ssy[idx], 0.88)
        field_left.append(Vector2(ssx[idx] - shw[idx], ssy[idx]))
        field_right.append(Vector2(ssx[idx] + shw[idx], ssy[idx]))
    draw_colored_polygon(field_left, COL_GRASS_DARK)
    draw_colored_polygon(field_right, COL_GRASS_DARK)

    # Nearest wall: textured grass with vertex tinting. The dark/light
    # furrow treatment is encoded in the same textured draw, so there are
    # no additional shadow/highlight draw calls.
    #
    # Distant tiers use only flat polygons. At that distance the texture
    # detail would be mostly sub-pixel anyway.
    for tier in range(WALL_TIERS - 1, -1, -1):
        var sample_count: int = WALL_SAMPLES_FAR
        if tier == 0:
            sample_count = WALL_SAMPLES_NEAR
        elif tier == 1:
            sample_count = WALL_SAMPLES_MID

        var tier_tint: Color = COL_GRASS_LIGHT
        if tier == 1:
            tier_tint = COL_GRASS_LIGHT.darkened(0.08)
        elif tier == 2:
            tier_tint = COL_GRASS_LIGHT.darkened(0.16)
        elif tier == 3:
            tier_tint = COL_GRASS_LIGHT.darkened(0.24)
        elif tier == 4:
            tier_tint = COL_GRASS_LIGHT.darkened(0.32)

        for sample in range(sample_count - 1):
            var u0: float = float(sample) / float(sample_count - 1)
            var u1: float = float(sample + 1) / float(sample_count - 1)
            var idx0: int = clampi(
                int(round(lerpf(float(FAR_SEGMENTS - 2), 0.0, u0))),
                0, FAR_SEGMENTS - 2)
            var idx1: int = clampi(
                int(round(lerpf(float(FAR_SEGMENTS - 2), 0.0, u1))),
                0, FAR_SEGMENTS - 2)

            var t0: float = float(idx0) / float(FAR_SEGMENTS - 1)
            var t1: float = float(idx1) / float(FAR_SEGMENTS - 1)
            var dz0: float = CAMERA_BEHIND / maxf(
                0.0001, lerpf(max_w, min_w, t0))
            var dz1: float = CAMERA_BEHIND / maxf(
                0.0001, lerpf(max_w, min_w, t1))
            var scale0: float = CAMERA_DEPTH / dz0
            var scale1: float = CAMERA_DEPTH / dz1

            var off0: float = float(wall_offsets[tier]) * scale0
            var off1: float = float(wall_offsets[tier]) * scale1
            var base0: float = float(wall_bases[tier]) * scale0
            var base1: float = float(wall_bases[tier]) * scale1
            var height0: float = float(wall_heights[tier]) * scale0
            var height1: float = float(wall_heights[tier]) * scale1

            var left_quad := PackedVector2Array([
                Vector2(ssx[idx0] - shw[idx0] - off0, ssy[idx0] - base0),
                Vector2(ssx[idx1] - shw[idx1] - off1, ssy[idx1] - base1),
                Vector2(ssx[idx1] - shw[idx1] - off1, ssy[idx1] - base1 - height1),
                Vector2(ssx[idx0] - shw[idx0] - off0, ssy[idx0] - base0 - height0)
            ])
            var right_quad := PackedVector2Array([
                Vector2(ssx[idx0] + shw[idx0] + off0, ssy[idx0] - base0),
                Vector2(ssx[idx0] + shw[idx0] + off0, ssy[idx0] - base0 - height0),
                Vector2(ssx[idx1] + shw[idx1] + off1, ssy[idx1] - base1 - height1),
                Vector2(ssx[idx1] + shw[idx1] + off1, ssy[idx1] - base1)
            ])

            if tier == 0 and grass_texture != null:
                # World-space V keeps the texture moving with the track.
                var absolute_seg0: float = float(cam_seg) + cam_progress + (
                    dz0 - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT
                var absolute_seg1: float = float(cam_seg) + cam_progress + (
                    dz1 - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT
                var v0: float = -absolute_seg0 * GRASS_WORLD_UV_SCALE * 10.0
                var v1: float = -absolute_seg1 * GRASS_WORLD_UV_SCALE * 10.0

                # Broad row variation is driven by world position, not screen
                # position, so the furrows cannot swim while the camera moves.
                var furrow_band: int = int(floor(
                    absolute_seg0 * FURROW_SAMPLE_SPEED))
                var furrow_phase: int = posmod(furrow_band, 4)
                var furrow_bottom := FURROW_NEUTRAL_TINT
                var furrow_top := FURROW_NEUTRAL_TINT
                if furrow_phase == 0:
                    furrow_bottom = FURROW_SHADOW_TINT
                elif furrow_phase == 2:
                    furrow_top = FURROW_LIGHT_TINT

                var left_uvs := PackedVector2Array([
                    Vector2(-0.48, v0), Vector2(-0.48, v1),
                    Vector2(0.48, v1), Vector2(0.48, v0)
                ])
                var right_uvs := PackedVector2Array([
                    Vector2(0.48, v0), Vector2(0.48, v1),
                    Vector2(-0.48, v1), Vector2(-0.48, v0)
                ])
                # Vertex colors provide the furrow tint without another draw.
                var left_cols := PackedColorArray([
                    furrow_bottom, furrow_bottom,
                    furrow_top, furrow_top
                ])
                var right_cols := PackedColorArray([
                    furrow_bottom, furrow_top,
                    furrow_top, furrow_bottom
                ])
                draw_primitive(left_quad, left_cols, left_uvs, grass_texture)
                draw_primitive(right_quad, right_cols, right_uvs, grass_texture)
            else:
                draw_colored_polygon(left_quad, tier_tint)
                draw_colored_polygon(right_quad, tier_tint)

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

            # Start/finish marker: do NOT paint an entire road
            # segment as a checkerboard. At the near end a single 40-unit
            # segment occupies most of the screen vertically, which was why
            # the Android screenshot showed a huge white/black road split.
            # Keep the road surface continuous; the finish stripe will be
            # added as a narrow world-space marker once the segment projection
            # is stable.
        i -= ROAD_STEP

func _draw_billboard(texture: Texture2D, center_x: float, bottom_y: float, width: float, height: float, tint := Color.WHITE) -> void:
    if texture == null or width <= 1.0 or height <= 1.0:
        return
    draw_texture_rect(
        texture,
        Rect2(center_x - width * 0.5, bottom_y - height, width, height),
        false,
        tint
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
        var projection_scale: float = CAMERA_DEPTH / dz

        var screen_y: float = horizon_y + (h - horizon_y) * CAMERA_BEHIND / dz
        if screen_y <= horizon_y or screen_y > h + 400.0:
            continue

        var road_cx: float = half_w + projection_scale * road_center_x * half_w
        var road_half: float = projection_scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE

        var px_per_meter: float = projection_scale * w * ROAD_SCREEN_SCALE
        var gap_world: float = 2.5
        var gap_screen: float = gap_world * px_per_meter

        var side: float = -1.0 if posmod(floori(float(world_seg) / 2.0), 2) == 0 else 1.0
        var sx: float = road_cx + side * (road_half + gap_screen)

        if posmod(world_seg, 12) == 0 and lamp_texture != null:
            var prop_w: float = clampf(2.0 * px_per_meter, 4.0, 300.0)
            var prop_h: float = clampf(8.0 * px_per_meter, 16.0, 800.0)
            # Фонарный столб утапливаем слегка (2% высоты).
            _draw_billboard(lamp_texture, sx, screen_y + prop_h * 0.05, prop_w, prop_h)
        else:
            var tree_tex: Texture2D = pine_texture if (posmod(floori(float(world_seg) / 4.0), 2) == 0 and pine_texture != null) else oak_texture
            if tree_tex != null:
                var prop_w: float = clampf(14.0 * px_per_meter, 8.0, 900.0)
                var prop_h: float = clampf(18.0 * px_per_meter, 10.0, 1100.0)
                # Деревья утапливаем глубже (5% высоты), чтобы скрыть срез ствола в траве.
                _draw_billboard(tree_tex, sx, screen_y + prop_h * 0.09, prop_w, prop_h)

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

        # Keep opponents visible when they are alongside the player. 0.01
        # segment is only about 0.4 m, while 0.1 was hiding them for roughly 4 m.
        if delta_segments < 0.01 or delta_segments >= max_dist:
            continue

        # Use the same perspective equation as _draw_road and _draw_props.
        var dz: float = delta_segments * RaceLevelData.SEGMENT_HEIGHT + CAMERA_BEHIND
        dz = maxf(1.0, dz)
        var projection_scale: float = CAMERA_DEPTH / dz
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

        var road_cx: float = half_w + projection_scale * ai_relative_center * half_w
        var current_shw: float = projection_scale * ROAD_WORLD_WIDTH * 0.5 * w * ROAD_SCREEN_SCALE
        var sx: float = road_cx + norm_offset * current_shw

        var car_w: float = clampf(projection_scale * ROAD_WORLD_WIDTH * w * 0.35, 8.0, 190.0)
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