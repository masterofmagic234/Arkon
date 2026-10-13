extends Node2D

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")
const SkidMarks = preload("res://scripts/race_skid_marks.gd")
const SkyLayout = preload("res://scripts/race_sky_layout.gd")

const CAMERA_DEPTH: float = 0.84
const CAMERA_BEHIND: float = 6.0
# Draw past the player so a yawed near edge cannot expose grass under the tires.
const NEAR_GROUND_DISTANCE: float = 4.8
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
var skid_marks = SkidMarks.new()
var skid_texture: Texture2D
var road_mesh=preload("res://scripts/race_road_mesh.gd").new()
var scenery=preload("res://scripts/race_scenery_batch.gd").new()
var sky_layer: Node2D
var render_profile: Dictionary = {}

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
    sky_layer=Node2D.new();sky_layer.name="ProjectedSky";sky_layer.z_index=-6
    add_child(sky_layer);sky_layer.draw.connect(_draw_sky)
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
    grass_texture = _tex("res://assets/level1/textures/park_meadow.jpg")
    grass_far_texture = _find_tex(["res://assets/grass.png", "res://assets/grass_tile.png"])
    asphalt_texture = _tex("res://assets/level2/asphalt_aggregate.png")
    rumble_texture = _find_tex(["res://assets/rumble.png", "res://rumble.png"])
    oak_texture = _find_tex(["res://assets/oak_tree.png", "res://oak_tree.png"])
    pine_texture = _find_tex(["res://assets/pine_tree.png", "res://pine_tree.png"])
    lamp_texture = _find_tex(["res://assets/street_lamp.png", "res://street_lamp.png"])
    oka_texture = _find_tex(["res://assets/oka.png", "res://oka.png"])
    road_mesh.setup(self,asphalt_texture,grass_texture)
    scenery.setup(self)
    _build_headlight_texture()
    var skid_image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
    for y in range(32):
        for x in range(16):
            var edge := smoothstep(0.0, 0.18, float(x) / 15.0) * smoothstep(0.0, 0.18, 1.0 - float(x) / 15.0)
            var grain := 0.68 + 0.22 * sin(float(x * 71 + y * 13)) + 0.10 * sin(float(x) * 2.4)
            skid_image.set_pixel(x, y, Color(0.025, 0.023, 0.020, edge * grain))
    skid_texture = ImageTexture.create_from_image(skid_image)
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
    scenery.bind(self)
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

func _project_relative(relative_x: float, forward_z: float, w: float, h: float, horizon_y: float, elevation: float = 0.0) -> Vector2:
    var point := _world_to_camera(relative_x, forward_z)
    var depth := maxf(point.y, 0.5)
    var scale := _camera_projection_scale(depth)
    var screen := Vector2(w * 0.5 + scale * point.x * w * ROAD_SCREEN_SCALE, horizon_y + (h - horizon_y) * CAMERA_BEHIND / depth * (float(camera_state.zoom) if camera_state != null else 1.0))
    screen.y -= elevation*scale*w*ROAD_SCREEN_SCALE
    var pivot := Vector2(w * 0.5, horizon_y)
    return pivot + (screen - pivot).rotated(-float(camera_state.roll) if camera_state != null else 0.0)

# Road, car contact point, props, AI and headlight beams share this projection.
func project_ground(world_x: float, distance_ahead: float, viewport_size: Vector2) -> Vector2:
    var h := viewport_size.y * PLAYFIELD_FRACTION
    var track_position: float = player_car.track_phase()
    var z: float=float(player_car.world_z)+distance_ahead
    return _project_relative(world_x - _camera_world_x(track_position), distance_ahead + _behind(), viewport_size.x, h, _horizon(h),_road_relative_height(z))

func _road_relative_height(world_z: float) -> float:
    var origin: float=player_car.world_z
    var height: float=camera_state.road_height if camera_state!=null else RaceLevelData.road_height(origin)
    var grade: float=camera_state.road_grade if camera_state!=null else RaceLevelData.road_grade(origin)
    return RaceLevelData.road_height(world_z)-height-(world_z-origin)*grade

func _camera_point(world: Vector3) -> Vector3:
    var flat := _world_to_camera(world.x-_camera_world_x(player_car.track_phase()),world.z-float(player_car.world_z)+_behind())
    return Vector3(flat.x,world.y+_road_relative_height(world.z),flat.y)

func _project_camera_point(point: Vector3, vp: Vector2) -> Vector2:
    var h := vp.y*PLAYFIELD_FRACTION
    var horizon := _horizon(h)
    var focal := _camera_projection_scale(1.0)*vp.x*ROAD_SCREEN_SCALE
    var vertical := (h-horizon)*CAMERA_BEHIND*(float(camera_state.zoom) if camera_state!=null else 1.0)
    var projected := Vector2(focal*point.x,vertical-focal*point.y)/point.z
    return Vector2(vp.x*.5,horizon)+projected.rotated(-float(camera_state.roll) if camera_state!=null else 0.0)

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
            var idx: int = clampi(seg+k,0,track_size-1)
            total += RaceMath.curve_of(track_pattern[idx]) * weight
            weight_total += weight
        _curve_table[seg] = total / weight_total

func _render_curve_for_segment(seg: int) -> float:
    if track_size <= 0:
        return 0.0
    if _curve_table.size() != track_size:
        _rebuild_curve_table()
    return _curve_table[clampi(seg,0,track_size-1)]

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
    var profile := Time.get_ticks_usec()
    var w: float = vp.x
    var player_track_position: float=player_car.track_phase()
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

    sky_layer.queue_redraw()
    _draw_road(w, draw_h, horizon_y)
    var road_done := Time.get_ticks_usec()
    _draw_finish_stripe(vp)
    _draw_skid_marks(vp)
    _draw_vehicle_shadow(vp)
    # Headlight pools are part of the shared ground surface material.
    scenery.begin(self,vp)
    scenery.draw(self,vp)
    var scenery_done := Time.get_ticks_usec()
    _draw_ai_cars(w, draw_h, horizon_y)
    _draw_player_car(w, draw_h)
    render_profile={"road_us":road_done-profile,"scenery_us":scenery_done-road_done,"total_us":Time.get_ticks_usec()-profile}

func _draw_sky() -> void:
    if player_car==null: return
    var vp := get_viewport_rect().size
    if not SkyLayout.outside_visible(float(player_car.world_z)):
        sky_layer.draw_rect(Rect2(Vector2.ZERO,vp),Color("070c10"))
        return
    var w := vp.x
    var horizon_y := _horizon(vp.y*PLAYFIELD_FRACTION)
    if camera_state!=null:
        horizon_y += _camera_projection_scale(1.0)*w*ROAD_SCREEN_SCALE*float(camera_state.road_grade)
    horizon_y=maxf(25.0,horizon_y)
    sky_layer.draw_rect(Rect2(Vector2.ZERO,vp),Color("080e21"))
    # Dark base behind the distant skyline.
    for band in range(24):
        var t := float(band)/23.0
        sky_layer.draw_rect(Rect2(0,horizon_y*band/24,w,horizon_y/24+1),Color("080e21").lerp(Color("33475b"),t),true)
    var yaw := _camera_yaw_screen_offset(w)
    for i in range(65):
        var p := Vector2(fposmod(i*137.31+yaw*.25,w),fposmod(i*71.4,horizon_y*.82))
        sky_layer.draw_circle(p,.55+fposmod(i*.71,1.0),Color(.72,.81,.94,.2+fposmod(i*.37,.45)))
    for layer in range(2):
        var ridge := PackedVector2Array([Vector2(-w,horizon_y+2)])
        for i in range(31):
            var x := -w+float(i)*w*.1+yaw*(.13+layer*.1)
            var height := (sin(i*.91+layer)*.5+.5)*horizon_y*(.18+layer*.03)
            ridge.append(Vector2(x,horizon_y-height))
        ridge.append(Vector2(w*3,horizon_y+2))
        sky_layer.draw_colored_polygon(ridge,Color("1d3045") if layer==0 else Color("172c3d"))

    var camera_track_x: float = _camera_world_x(player_car.track_phase())
    var relative_track_x: float = camera_track_x - sky_reference_track_x

    # CITY: the bottom of the source image is the actual horizon line.
    # We map the complete city image from its top edge down to horizon_y.
    # This is intentionally different from cropping the lower part of the
    # image: the skyline must occupy the space FROM the horizon AND ABOVE.
    if city_texture != null:
        var tex_w: float = float(city_texture.get_width())
        var zoom: float=camera_state.zoom if camera_state!=null else 1.0
        var rect := SkyLayout.city_rect(vp,horizon_y,city_texture.get_size(),zoom)
        var city_h := rect.size.y
        var city_top_y := rect.position.y

        # Horizontal enlargement + world-relative parallax. The vertical
        # mapping remains 0..1 so no part of the skyline is lost at the
        # horizon because of an arbitrary v_start crop.
        var parallax_u: float = (relative_track_x * 12.0) / tex_w
        var u_span: float = w/rect.size.x
        var yaw_u := 0.0
        if camera_state != null:
            yaw_u = (
                tan(float(camera_state.yaw_offset))
                * CAMERA_DEPTH
                * float(camera_state.zoom)
                * ROAD_SCREEN_SCALE
                * u_span
            )
        var u_start: float = (1.0-u_span)*.5+parallax_u + yaw_u
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
        var tint := Color(.65,.73,.85,SkyLayout.city_opacity(float(player_car.world_z)))
        var cols := PackedColorArray([tint,tint,tint,tint])
        sky_layer.draw_polygon(pts, cols, uvs, city_texture)

    # Moon remains a separate, much more distant layer.
    if moon_texture != null:
        var moon_x: float = w*.73-relative_track_x*.25+_camera_yaw_screen_offset(w)
        sky_layer.draw_texture_rect(
            moon_texture,
            SkyLayout.moon_rect(vp,moon_x),
            false,
            Color(1.0, 1.0, 1.0, 0.96)
        )

func _draw_road(w: float, _h: float, _horizon_y: float) -> void:
    road_mesh.update(self,Vector2(w,get_viewport_rect().size.y))

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

func _draw_ai_cars(w: float, h: float, horizon_y: float) -> void:
    var max_dist := float(FAR_SEGMENTS) / float(VISUAL_SUBDIVISIONS)
    # Far cars first so an overtaking car cannot be painted under a distant one.
    var visible_cars: Array = []
    for ai_controller in ai_cars:
        if ai_controller == null or ai_controller.car == null:
            continue
        var car = ai_controller.car
        var ahead: float=car.physical_progress(track_size)-player_car.physical_progress(track_size)

        if ahead*RaceLevelData.SEGMENT_HEIGHT < -5.0 or ahead >= max_dist:
            continue
        visible_cars.append({"car": car, "distance": ahead})
    visible_cars.sort_custom(func(a, b): return float(a.distance) > float(b.distance))
    for entry in visible_cars:
        var car = entry.car
        var depth := _camera_point(Vector3(float(car.world_x),0,float(car.world_z))).z
        if depth < 0.5:
            continue
        var point := project_ground(float(car.world_x),float(entry.distance)*RaceLevelData.SEGMENT_HEIGHT,Vector2(w,h/PLAYFIELD_FRACTION))
        # Body/lenses are actual 3D geometry in the shared vehicle viewport.
        # Keep the asphalt contact shadow under the continuously yawed model.
        var shadow := PackedVector2Array()
        for corner: Vector2 in [Vector2(-.83,-2.1),Vector2(.83,-2.1),Vector2(.83,2.4),Vector2(-.83,2.4)]:
            var turned := corner.rotated(-float(car.heading_yaw))
            shadow.append(project_ground(float(car.world_x)+turned.x,float(entry.distance)*40.0+turned.y,Vector2(w,h/PLAYFIELD_FRACTION)))
        _draw_quad_with_colors(shadow[0],shadow[1],shadow[2],shadow[3],Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE,Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0),car_shadow_texture)

func update_skid_marks(delta: float) -> void:
    if player_car != null and track_size > 0:
        skid_marks.update(player_car, track_size, RaceLevelData.SEGMENT_HEIGHT, delta)

func _draw_skid_marks(viewport_size: Vector2) -> void:
    var player_z := float(player_car.progress(track_size)) * RaceLevelData.SEGMENT_HEIGHT - float(player_car.grid_world_z_offset)
    for segment in skid_marks.segments:
        var world: PackedVector2Array = segment.points
        if world[0].y - player_z < -NEAR_GROUND_DISTANCE or world[0].y - player_z > 250.0:
            continue
        var points := PackedVector2Array()
        var visible_ground := true
        for point in world:
            var depth := _world_to_camera(point.x - _camera_world_x(player_car.track_phase()), point.y - player_z + _behind()).y
            if depth < 0.7:
                visible_ground = false
                break
            points.append(project_ground(point.x, point.y - player_z, viewport_size))
        if not visible_ground:
            continue
        var age: float = skid_marks.clock - float(segment.time)
        var alpha := float(segment.strength) * (1.0 - smoothstep(12.0, SkidMarks.LIFETIME, age)) * 0.78
        var color := Color(1.0, 1.0, 1.0, alpha)
        # Near ground continues behind the player; clip rubber at the HUD edge.
        var uv := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
        var clipped := PackedVector2Array()
        var clipped_uv := PackedVector2Array()
        var bottom := viewport_size.y * PLAYFIELD_FRACTION
        for index in range(4):
            var next := (index + 1) % 4
            var inside := points[index].y <= bottom
            var next_inside := points[next].y <= bottom
            if inside:
                clipped.append(points[index])
                clipped_uv.append(uv[index])
            if inside != next_inside:
                var t := (bottom - points[index].y) / (points[next].y - points[index].y)
                clipped.append(points[index].lerp(points[next], t))
                clipped_uv.append(uv[index].lerp(uv[next], t))
        if clipped.size() >= 3:
            var colors := PackedColorArray()
            colors.resize(clipped.size())
            colors.fill(color)
            draw_polygon(clipped, colors, clipped_uv, skid_texture)

func _draw_vehicle_shadow(viewport_size: Vector2) -> void:
    var yaw := float(player_car.heading_yaw)
    var points := PackedVector2Array()
    for corner in [Vector2(-0.70, 0.15), Vector2(0.70, 0.15), Vector2(0.70, 3.2), Vector2(-0.70, 3.2)]:
        var x: float = float(player_car.world_x) + sin(yaw) * corner.y + cos(yaw) * corner.x
        var z: float = cos(yaw) * corner.y - sin(yaw) * corner.x
        points.append(project_ground(x, z, viewport_size))
    _draw_quad_with_colors(points[0], points[1], points[2], points[3], Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), car_shadow_texture)

func _draw_player_car(_w: float, _h: float) -> void:
    # Player 240SX is rendered by the dedicated 3D overlay viewport.
    pass

func _road_tint(distance_: float) -> Color:
    return Color(.48,.54,.62).lerp(Color(.29,.39,.51),smoothstep(25,700,distance_))

func _draw_finish_stripe(vp: Vector2) -> void:
    var at: float = player_car.track_phase()
    var ahead: float=(float(track_size)-at)*RaceLevelData.SEGMENT_HEIGHT
    if ahead>320 or ahead< -4: return
    for row in range(2):
        for column in range(12):
            var points := PackedVector2Array()
            for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
                var z := ahead+(row+corner.y)*.45
                var center := _smooth_track_x(at+z/RaceLevelData.SEGMENT_HEIGHT)
                var x := center-3.8+(column+corner.x)*7.6/12.0
                points.append(project_ground(x,z,vp))
            var color := Color("afbbc0") if (column+row)%2==0 else Color("17232c")
            _draw_colored_quad(points[0],points[1],points[2],points[3],color)
