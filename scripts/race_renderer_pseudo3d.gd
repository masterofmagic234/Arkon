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
var camera_state = null
# Normalized (-1..1) curve amount a few segments ahead, consumed by the car's visual camera.
var current_curve: float = 0.0

var ssx := PackedFloat32Array()
var ssy := PackedFloat32Array()
var shw := PackedFloat32Array()
var scz := PackedFloat32Array()
var sidx := PackedInt32Array()
var _curve_table := PackedFloat32Array()
var road_left := PackedVector2Array()
var road_right := PackedVector2Array()
var road_lane_left := PackedVector2Array()
var road_lane_right := PackedVector2Array()

# Reused submission buffers keep the road renderer from allocating packed arrays
# for every quad on every frame. Godot's draw_primitive treats four vertices as a quad.
var _quad_points := PackedVector2Array()
var _quad_colors := PackedColorArray()
var _quad_uvs := PackedVector2Array()

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
var headlight_texture: Texture2D
var car_shadow_texture: Texture2D

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
    road_left.resize(FAR_SEGMENTS)
    road_right.resize(FAR_SEGMENTS)
    road_lane_left.resize(FAR_SEGMENTS)
    road_lane_right.resize(FAR_SEGMENTS)
    ssx.resize(FAR_SEGMENTS)
    ssy.resize(FAR_SEGMENTS)
    shw.resize(FAR_SEGMENTS)
    scz.resize(FAR_SEGMENTS)
    sidx.resize(FAR_SEGMENTS)
    _quad_points.resize(4)
    _quad_colors.resize(4)
    _quad_uvs.resize(4)
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
    _build_headlight_texture()
    queue_redraw()

func _build_headlight_texture() -> void:
    var light_image := Image.create(64, 128, false, Image.FORMAT_RGBA8)
    for y in range(128):
        var v := float(y) / 127.0
        for x in range(64):
            var u := float(x) / 63.0
            var opacity := pow(sin(u * PI), 2.0) * pow(1.0 - v, 1.5) * 0.28
            light_image.set_pixel(x, y, Color(1.0, 0.94, 0.78, opacity))
    headlight_texture = ImageTexture.create_from_image(light_image)
    var shadow_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var radius := Vector2(float(x) / 63.0 * 2.0 - 1.0, float(y) / 63.0 * 2.0 - 1.0).length_squared()
            shadow_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, pow(maxf(1.0 - radius, 0.0), 1.4) * 0.65))
    car_shadow_texture = ImageTexture.create_from_image(shadow_image)

func bind(
        state,
        player_ref,
        ais_ref: Array,
        pattern: Array,
        tx: PackedFloat32Array,
        shared_camera_state = null
) -> void:
    race_state = state
    player_car = player_ref
    ai_cars = ais_ref
    track_pattern = pattern
    track_x = tx
    track_size = pattern.size()
    camera_state = shared_camera_state
    _rebuild_curve_table()
    sky_reference_track_x = _smooth_track_x(
        float(player_ref.segment_index % maxi(track_size, 1))
        + clampf(player_ref.segment_progress, 0.0, 0.9999)
    ) if track_size > 0 else 0.0
    queue_redraw()

func _camera_world_x(track_position: float) -> float:
    var shared_lateral := 0.0
    if camera_state != null:
        shared_lateral = float(camera_state.lateral_offset)
    return _smooth_track_x(track_position) + shared_lateral

func _behind() -> float:
    return float(camera_state.behind_distance) if camera_state != null else CAMERA_BEHIND

func _horizon(h: float) -> float:
    return h * (HORIZON_FRACTION + (float(camera_state.horizon_offset) if camera_state != null else 0.0))

func _project_relative(relative_x: float, forward_z: float, w: float, h: float, horizon_y: float) -> Vector2:
    var point := _world_to_camera(relative_x, forward_z)
    var depth := maxf(point.y, 0.5)
    var scale := _camera_projection_scale(depth)
    var screen := Vector2(w * 0.5 + scale * point.x * w * ROAD_SCREEN_SCALE, horizon_y + (h - horizon_y) * CAMERA_BEHIND / depth * (float(camera_state.zoom) if camera_state != null else 1.0))
    var pivot := Vector2(w * 0.5, horizon_y)
    return pivot + (screen - pivot).rotated(-float(camera_state.roll) if camera_state != null else 0.0)

# Road, car contact point, props, AI and headlight beams share this projection.
func project_ground(world_x: float, distance_ahead: float, viewport_size: Vector2) -> Vector2:
    var h := viewport_size.y * PLAYFIELD_FRACTION
    var track_position := float(player_car.segment_index) + float(player_car.segment_progress)
    return _project_relative(world_x - _camera_world_x(track_position), distance_ahead + _behind(), viewport_size.x, h, _horizon(h))

func get_player_ground_anchor(viewport_size: Vector2) -> Vector2:
    return project_ground(float(player_car.world_x) + sin(float(player_car.heading_yaw)) * 0.45, cos(float(player_car.heading_yaw)) * 0.45, viewport_size)

func _camera_projection_scale(dz: float) -> float:
    var camera_zoom := 1.0
    if camera_state != null:
        camera_zoom = float(camera_state.zoom)
    return CAMERA_DEPTH / maxf(dz, 0.001) * camera_zoom

func _world_to_camera(relative_x: float, forward_z: float) -> Vector2:
    # Virtual main camera for Level2's pseudo-3D renderer. Rotate world-space
    # points into the camera's basis using the exact yaw of the car nose.
    # A camera yaw changes both horizontal position AND forward depth; shifting
    # every object by one screen-space constant is not a camera rotation.
    var yaw := 0.0
    if camera_state != null:
        yaw = float(camera_state.yaw_offset)
    var c := cos(yaw)
    var s := sin(yaw)
    return Vector2(
        relative_x * c - forward_z * s,
        forward_z * c + relative_x * s
    )

func _camera_yaw_screen_offset(w: float) -> float:
    # Used only by distant sky sprites. Track geometry is transformed in
    # camera space through _world_to_camera().
    if camera_state == null:
        return 0.0
    return -tan(float(camera_state.yaw_offset)) * CAMERA_DEPTH * float(camera_state.zoom) * w * ROAD_SCREEN_SCALE

func _camera_roll_offset(screen_y: float, horizon_y: float) -> float:
    if camera_state == null:
        return 0.0
    return (screen_y - horizon_y) * tan(float(camera_state.roll))

func _smooth_track_x(track_position: float) -> float:
    # Single source of truth shared with race physics and 240SX presentation.
    if track_size <= 0 or track_x.is_empty():
        return 0.0
    return RaceMath.track_center_x(track_position, track_x)

func _rebuild_curve_table() -> void:
    _curve_table.resize(track_size)
    if track_size <= 0:
        return

    # Keep the exact previous five-sample smoothing, but calculate it once per
    # bound track instead of once for every road/prop/AI sample in every frame.
    for seg in range(track_size):
        var total: float = 0.0
        var weight_total: float = 0.0
        for k in range(-CURVE_SMOOTH_RADIUS, CURVE_SMOOTH_RADIUS + 1):
            var weight: float = float(CURVE_SMOOTH_RADIUS + 1 - abs(k))
            var idx: int = posmod(seg + k, track_size)
            total += RaceMath.curve_of(track_pattern[idx]) * weight
            weight_total += weight
        _curve_table[seg] = total / weight_total

func _render_curve_for_segment(seg: int) -> float:
    if track_size <= 0:
        return 0.0
    if _curve_table.size() != track_size:
        _rebuild_curve_table()
    return _curve_table[posmod(seg, track_size)]

func _render_curve_at(track_position: float) -> float:
    var base: int = int(floor(track_position))
    var t: float = track_position - floor(track_position)
    var c0: float = _render_curve_for_segment(base)
    var c1: float = _render_curve_for_segment(base + 1)
    var eased_t: float = t * t * (3.0 - 2.0 * t)
    return lerpf(c0, c1, eased_t)

func get_current_curve() -> float:
    return current_curve

func _draw() -> void:
    if race_state == null or player_car == null or track_size == 0 or track_x.is_empty():
        return

    var vp: Vector2 = get_viewport_rect().size
    var w: float = vp.x
    var player_track_position := (
        float(player_car.segment_index % track_size)
        + clampf(player_car.segment_progress, 0.0, 0.9999)
    )
    # Look a little way ahead so the car presentation can anticipate a bend.
    current_curve = clampf(
        _render_curve_at(player_track_position + 3.0) / 3.2,
        -1.0,
        1.0
    )
    # The playfield is derived from the real viewport. The HUD uses the same
    # normalized design boundary, so other aspect ratios no longer inherit 496px.
    var draw_h: float = maxf(1.0, vp.y * PLAYFIELD_FRACTION)
    var horizon_y: float = _horizon(draw_h)

    _draw_sky(w, horizon_y)
    _draw_road(w, draw_h, horizon_y)
    _draw_vehicle_shadow(vp)
    _draw_headlights(vp)
    _draw_props(w, draw_h, horizon_y)
    _draw_ai_cars(w, draw_h, horizon_y)
    _draw_player_car(w, draw_h)

func _draw_sky(w: float, horizon_y: float) -> void:
    # Dark base behind the distant skyline.
    draw_rect(Rect2(0.0, 0.0, w, horizon_y), Color(0.035, 0.07, 0.13), true)

    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var camera_track_x: float = _camera_world_x(float(cam_seg) + cam_progress)
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
        var yaw_u := 0.0
        if camera_state != null:
            yaw_u = (
                tan(float(camera_state.yaw_offset))
                * CAMERA_DEPTH
                * float(camera_state.zoom)
                * ROAD_SCREEN_SCALE
                * u_span
            )
        var u_start: float = parallax_u + yaw_u
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
        ) - w * 0.5 + _camera_yaw_screen_offset(w)
        draw_texture_rect(
            moon_texture,
            Rect2(moon_x, horizon_y * 0.10, moon_size, moon_size),
            false,
            Color(1.0, 1.0, 1.0, 0.96)
        )

func _draw_road(w: float, h: float, horizon_y: float) -> void:
    var cam_seg: int = player_car.segment_index % track_size
    var cam_progress: float = clampf(player_car.segment_progress, 0.0, 0.9999)
    var camera_track_x: float = _camera_world_x(float(cam_seg) + cam_progress)

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
        var forward_z := dz - CAMERA_BEHIND + _behind()
        var center_point := _project_relative(road_center_x, forward_z, w, h, horizon_y)
        var edge := RaceLevelData.ROAD_WIDTH * 0.5
        road_left[i] = _project_relative(road_center_x - edge, forward_z, w, h, horizon_y)
        road_right[i] = _project_relative(road_center_x + edge, forward_z, w, h, horizon_y)
        road_lane_left[i] = _project_relative(road_center_x - 0.08, forward_z, w, h, horizon_y)
        road_lane_right[i] = _project_relative(road_center_x + 0.08, forward_z, w, h, horizon_y)
        ssx[i] = center_point.x
        ssy[i] = center_point.y
        shw[i] = absf(road_right[i].x - road_left[i].x) * 0.5
        scz[i] = maxf(_world_to_camera(road_center_x, forward_z).y, 0.5)
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
    draw_rect(Rect2(0.0, horizon_y, w, h - horizon_y), COL_GRASS_DARK)

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
            var scale0: float = _camera_projection_scale(maxf(scz[idx0], 0.5))
            var scale1: float = _camera_projection_scale(maxf(scz[idx1], 0.5))

            var off0: float = float(wall_offsets[tier]) * scale0
            var off1: float = float(wall_offsets[tier]) * scale1
            var base0: float = float(wall_bases[tier]) * scale0
            var base1: float = float(wall_bases[tier]) * scale1
            var height0: float = float(wall_heights[tier]) * scale0
            var height1: float = float(wall_heights[tier]) * scale1

            var left0 := Vector2(
                ssx[idx0] - shw[idx0] - off0,
                ssy[idx0] - base0
            )
            var left1 := Vector2(
                ssx[idx1] - shw[idx1] - off1,
                ssy[idx1] - base1
            )
            var left2 := Vector2(
                ssx[idx1] - shw[idx1] - off1,
                ssy[idx1] - base1 - height1
            )
            var left3 := Vector2(
                ssx[idx0] - shw[idx0] - off0,
                ssy[idx0] - base0 - height0
            )
            var right0 := Vector2(
                ssx[idx0] + shw[idx0] + off0,
                ssy[idx0] - base0
            )
            var right1 := Vector2(
                ssx[idx0] + shw[idx0] + off0,
                ssy[idx0] - base0 - height0
            )
            var right2 := Vector2(
                ssx[idx1] + shw[idx1] + off1,
                ssy[idx1] - base1 - height1
            )
            var right3 := Vector2(
                ssx[idx1] + shw[idx1] + off1,
                ssy[idx1] - base1
            )

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

                _draw_quad_with_colors(
                    left0, left1, left2, left3,
                    furrow_bottom, furrow_bottom,
                    furrow_top, furrow_top,
                    Vector2(-0.48, v0), Vector2(-0.48, v1),
                    Vector2(0.48, v1), Vector2(0.48, v0),
                    grass_texture
                )
                _draw_quad_with_colors(
                    right0, right1, right2, right3,
                    furrow_bottom, furrow_top,
                    furrow_top, furrow_bottom,
                    Vector2(0.48, v0), Vector2(0.48, v1),
                    Vector2(-0.48, v1), Vector2(-0.48, v0),
                    grass_texture
                )
            else:
                _draw_colored_quad(left0, left1, left2, left3, tier_tint)
                _draw_colored_quad(right0, right1, right2, right3, tier_tint)

    # Asphalt: continuous world-space V coordinates with a deliberately
    # denser repeat so the texture reads as actual road surface detail.
    var i: int = FAR_SEGMENTS - 2
    while i >= 0:
        var j: int = min(i + ROAD_STEP, FAR_SEGMENTS - 1)
        if ssy[i] > ssy[j]:
            var l0 := road_left[i]
            var r0 := road_right[i]
            var l1 := road_left[j]
            var r1 := road_right[j]

            var t_i: float = float(i) / float(FAR_SEGMENTS - 1)
            var t_j: float = float(j) / float(FAR_SEGMENTS - 1)
            var dz_i: float = CAMERA_BEHIND / lerpf(max_w, min_w, t_i)
            var dz_j: float = CAMERA_BEHIND / lerpf(max_w, min_w, t_j)
            var absolute_seg_i: float = float(cam_seg) + cam_progress + (dz_i - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT
            var absolute_seg_j: float = float(cam_seg) + cam_progress + (dz_j - CAMERA_BEHIND) / RaceLevelData.SEGMENT_HEIGHT

            var road_band: int = int(floor(absolute_seg_i * 10.0))
            var road_dark: bool = posmod(road_band, 2) == 0
            var road_col: Color = COL_ROAD_DARK if road_dark else COL_ROAD_LIGHT

            if asphalt_texture != null:
                var asphalt_uv_repeat: float = 10.0
                var uv_v0: float = absolute_seg_i * asphalt_uv_repeat
                var uv_v1: float = absolute_seg_j * asphalt_uv_repeat
                _draw_quad_with_colors(
                    l0, r0, r1, l1,
                    Color(0.48, 0.52, 0.60), Color(0.48, 0.52, 0.60), Color(0.48, 0.52, 0.60), Color(0.48, 0.52, 0.60),
                    Vector2(0.0, uv_v0), Vector2(1.0, uv_v0),
                    Vector2(1.0, uv_v1), Vector2(0.0, uv_v1),
                    asphalt_texture
                )
            else:
                _draw_colored_quad(l0, r0, r1, l1, road_col)

            var inner_l0 := l0.lerp(r0, 0.075)
            var inner_l1 := l1.lerp(r1, 0.075)
            var inner_r0 := r0.lerp(l0, 0.075)
            var inner_r1 := r1.lerp(l1, 0.075)

            if rumble_texture != null:
                _draw_quad_with_colors(
                    l0, inner_l0,
                    inner_l1, l1,
                    Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
                    Vector2(0.0, 1.0), Vector2(1.0, 1.0),
                    Vector2(1.0, 0.0), Vector2(0.0, 0.0),
                    rumble_texture
                )
                _draw_quad_with_colors(
                    inner_r0, r0,
                    r1, inner_r1,
                    Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
                    Vector2(0.0, 1.0), Vector2(1.0, 1.0),
                    Vector2(1.0, 0.0), Vector2(0.0, 0.0),
                    rumble_texture
                )
            else:
                var rumble_band: int = int(floor(absolute_seg_i * 20.0))
                var rumb_col: Color = COL_RUMBLE_LIGHT if posmod(rumble_band, 2) == 0 else Color.BLACK
                _draw_colored_quad(
                    l0, inner_l0,
                    inner_l1, l1, rumb_col
                )
                _draw_colored_quad(
                    inner_r0, r0,
                    r1, inner_r1, rumb_col
                )

            if road_dark:
                _draw_colored_quad(road_lane_left[i], road_lane_right[i], road_lane_right[j], road_lane_left[j], COL_LANE)

            # Start/finish marker: do NOT paint an entire road
            # segment as a checkerboard. At the near end a single 40-unit
            # segment occupies most of the screen vertically, which was why
            # the Android screenshot showed a huge white/black road split.
            # Keep the road surface continuous; the finish stripe will be
            # added as a narrow world-space marker once the segment projection
            # is stable.
        i -= ROAD_STEP

func _draw_quad_with_colors(
        p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
        c0: Color, c1: Color, c2: Color, c3: Color,
        u0: Vector2 = Vector2.ZERO, u1: Vector2 = Vector2.ZERO,
        u2: Vector2 = Vector2.ZERO, u3: Vector2 = Vector2.ZERO,
        texture: Texture2D = null
) -> void:
    _quad_points[0] = p0
    _quad_points[1] = p1
    _quad_points[2] = p2
    _quad_points[3] = p3
    _quad_colors[0] = c0
    _quad_colors[1] = c1
    _quad_colors[2] = c2
    _quad_colors[3] = c3
    _quad_uvs[0] = u0
    _quad_uvs[1] = u1
    _quad_uvs[2] = u2
    _quad_uvs[3] = u3
    draw_primitive(_quad_points, _quad_colors, _quad_uvs, texture)

func _draw_colored_quad(
        p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color: Color
) -> void:
    _draw_quad_with_colors(p0, p1, p2, p3, color, color, color, color)

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
    var cam_position := float(player_car.segment_index) + float(player_car.segment_progress)
    var camera_x := _camera_world_x(cam_position)
    var max_visible_segments := int(ceil(float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS))) - 1
    for ahead in range(max_visible_segments, -1, -1):
        var absolute_seg := float(player_car.segment_index + ahead)
        var world_seg := posmod(int(absolute_seg), track_size)
        if posmod(world_seg, 2) != 0:
            continue
        var distance_segments := absolute_seg - cam_position
        if distance_segments <= 0.01:
            continue
        var side := -1.0 if posmod(world_seg / 2, 2) == 0 else 1.0
        var relative_x := _smooth_track_x(absolute_seg) - camera_x + side * (RaceLevelData.ROAD_WIDTH * 0.5 + 2.5)
        var dz := distance_segments * RaceLevelData.SEGMENT_HEIGHT + _behind()
        var depth := _world_to_camera(relative_x, dz).y
        if depth < 0.5:
            continue
        var point := _project_relative(relative_x, dz, w, h, horizon_y)
        var pixels_per_meter := _camera_projection_scale(depth) * w * ROAD_SCREEN_SCALE
        if point.y <= horizon_y or point.y > h + 150.0:
            continue
        if posmod(world_seg, 12) == 0 and lamp_texture != null:
            var lamp_height := minf(8.0 * pixels_per_meter, 800.0)
            _draw_billboard(lamp_texture, point.x, point.y + lamp_height * 0.05, minf(2.0 * pixels_per_meter, 300.0), lamp_height)
        else:
            var tree_tex := pine_texture if posmod(world_seg / 4, 2) == 0 and pine_texture != null else oak_texture
            if tree_tex != null:
                var tree_height := minf(18.0 * pixels_per_meter, 1100.0)
                _draw_billboard(tree_tex, point.x, point.y + tree_height * 0.09, minf(14.0 * pixels_per_meter, 900.0), tree_height)

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    var cam_position := float(player_car.segment_index) + float(player_car.segment_progress)
    var camera_x := _camera_world_x(cam_position)
    var max_dist := float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS)
    # Far cars first so an overtaking car cannot be painted under a distant one.
    var visible_cars: Array = []
    for ai_controller in ai_cars:
        if ai_controller == null or ai_controller.car == null:
            continue
        var car = ai_controller.car
        var ahead := fposmod(float(car.progress(track_size) - player_car.progress(track_size)), float(track_size))
        if ahead < 0.01 or ahead >= max_dist:
            continue
        visible_cars.append({"car": car, "distance": ahead})
    visible_cars.sort_custom(func(a, b): return float(a.distance) > float(b.distance))
    for entry in visible_cars:
        var car = entry.car
        var dz := float(entry.distance) * RaceLevelData.SEGMENT_HEIGHT + _behind()
        var relative_x := float(car.world_x) - camera_x
        var depth := _world_to_camera(relative_x, dz).y
        if depth < 0.5:
            continue
        var point := _project_relative(relative_x, dz, w, h, horizon_y)
        var car_w := clampf(_camera_projection_scale(depth) * w * ROAD_SCREEN_SCALE * 2.0, 8.0, 190.0)
        if point.y > horizon_y and point.y < h + 80.0:
            if squirrel_mobile_texture != null:
                _draw_billboard(squirrel_mobile_texture, point.x, point.y, car_w * 1.25, car_w * 0.87)
            else:
                draw_rect(Rect2(point.x - car_w * 0.5, point.y - car_w * 0.56, car_w, car_w * 0.56), Color(0.75, 0.15, 0.15))

func _draw_vehicle_shadow(viewport_size: Vector2) -> void:
    var yaw := float(player_car.heading_yaw)
    var points := PackedVector2Array()
    for corner in [Vector2(-0.70, 0.15), Vector2(0.70, 0.15), Vector2(0.70, 3.2), Vector2(-0.70, 3.2)]:
        var x: float = float(player_car.world_x) + sin(yaw) * corner.y + cos(yaw) * corner.x
        var z: float = cos(yaw) * corner.y - sin(yaw) * corner.x
        points.append(project_ground(x, z, viewport_size))
    _draw_quad_with_colors(points[0], points[1], points[2], points[3], Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), car_shadow_texture)

func _draw_headlights(viewport_size: Vector2) -> void:
    # Soft world-space light pools: attached to the nose, projected by the main
    # camera. Lights in the isolated 3D viewport cannot illuminate 2D asphalt.
    for lamp_side in [-1.0, 1.0]:
        for band in range(14, 0, -1):
            var near_distance := 2.0 + float(band - 1) * 1.5
            var far_distance := near_distance + 1.5
            var near_width := 0.55 + near_distance * 0.12
            var far_width := 0.55 + far_distance * 0.12
            var shift := float(lamp_side) * 0.50
            var yaw := float(player_car.heading_yaw)
            var shift_x := cos(yaw) * shift
            var shift_z := -sin(yaw) * shift
            var points := PackedVector2Array()
            for corner in [Vector2(-near_width, near_distance), Vector2(near_width, near_distance), Vector2(far_width, far_distance), Vector2(-far_width, far_distance)]:
                var x: float = float(player_car.world_x) + sin(yaw) * corner.y + cos(yaw) * corner.x + shift_x
                var z: float = cos(yaw) * corner.y - sin(yaw) * corner.x + shift_z
                points.append(project_ground(x, z, viewport_size))
            var v0 := (near_distance - 2.0) / 21.0
            var v1 := (far_distance - 2.0) / 21.0
            _draw_quad_with_colors(points[0], points[1], points[2], points[3], Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1), headlight_texture)

func _draw_player_car(_w: float, _h: float) -> void:
    # Player 240SX is rendered by the dedicated 3D overlay viewport.
    pass
