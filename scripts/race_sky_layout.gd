extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")

static func city_rect(size: Vector2, horizon: float, texture_size: Vector2, zoom: float) -> Rect2:
    # Pitch moves the horizon; it must never resize the buildings.
    var height := size.y*(496.0/720.0)*.38*zoom
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
