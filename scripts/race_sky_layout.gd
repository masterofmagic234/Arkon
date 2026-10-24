extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const CITY_HALO_UV := Vector2(.737,.158)

static func city_rect(size: Vector2, horizon: float, texture_size: Vector2, zoom: float) -> Rect2:
    # Pitch moves the horizon; it must never resize the buildings.
    # Restore the former 1.35 × nominal horizon scale, preserving source
    # aspect and a stable lens size. Its own sky covers the top of the screen.
    var height := size.y*(496.0/720.0)*.675*zoom
    var width := height*texture_size.x/texture_size.y
    return Rect2((size.x-width)*.5,horizon-height,width,height)

static func city_opacity(z: float) -> float:
    return smoothstep(Data.TUNNEL_END-480,Data.TUNNEL_END-200,z)

static func outside_visible(z: float) -> bool:
    return z<Data.TUNNEL_START or z>=Data.TUNNEL_END-200

static func moon_rect(size: Vector2, x: float) -> Rect2:
    var play := size.y*(496.0/720.0)
    var diameter := minf(play*.085,size.x*.06)
    return Rect2(x,play*.022,diameter,diameter)

static func city_moon_rect(city: Rect2, u_start: float, u_span: float, view_width: float) -> Rect2:
    # The halo is painted into city_night.png. Use its exact panorama UV,
    # including texture repetition, instead of an unrelated sky parallax.
    var repeat_ := roundf(u_start+u_span*.73-CITY_HALO_UV.x)
    var center := Vector2((CITY_HALO_UV.x+repeat_-u_start)/u_span*view_width,city.position.y+city.size.y*CITY_HALO_UV.y)
    var diameter := city.size.y*.145
    return Rect2(center-Vector2.ONE*diameter*.5,Vector2.ONE*diameter)
