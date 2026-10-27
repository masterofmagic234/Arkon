extends RefCounted
## Footprints are in world X/Z. Decoration stays off stairs and circulation.
const BENCHES=[
    [Vector2(-9,56.5),0.0],[Vector2(9,56.5),0.0],
    [Vector2(-45,22),PI*.5],[Vector2(45,22),-PI*.5],
    [Vector2(-46,-24),0.0],[Vector2(46,-24),0.0],
    [Vector2(-44,-89),PI],
]
static func plant_point(point: Vector2) -> Vector2:
    var p=point;var side=-1.0 if p.x<0 else 1.0
    if p.y>24 and p.y<46 and absf(p.x)>17 and absf(p.x)<31:p.x=side*33.5
    if p.y> -15 and p.y<13 and absf(p.x)>49 and absf(p.x)<60:p.x=side*63
    if p.y> -73 and p.y< -51 and absf(p.x)>38 and absf(p.x)<59:p.x=side*63
    if p.y> -21.5 and p.y< -14.5 and absf(p.x)<50:p.y=-25.5
    for z in [52,40,6,-5,-48,-82]:
        var x=17 if z>30 else (29 if z> -14 else 23)
        if absf(absf(p.x)-x)<5.5 and absf(p.y-z)<3:p.y=z+3.6
    for bench in BENCHES:
        if p.distance_to(bench[0])<2.4:p.x+=side*3
    return p
