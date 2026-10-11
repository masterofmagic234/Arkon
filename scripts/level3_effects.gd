extends Node2D
class_name Level3Effects
const Visual = preload("res://scripts/level3_asset_visual.gd")
const CAPACITY := 96
var _slots: Array[Dictionary] = []
var _cursor := 0
var _muzzle: SpriteFrames
var _glass: SpriteFrames
var _splat: Texture2D
var _pool_texture: Texture2D
var _random := RandomNumberGenerator.new()

func _ready() -> void:
    z_index = 30
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var mat := CanvasItemMaterial.new()
    mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    material = mat
    _muzzle = Visual.sprite_frames_from_strip("res://assets/level3/source/Combat/sprBulletHit_strip11.png",28,false)
    _glass = Visual.sprite_frames_from_strip("res://assets/level3/source/Weapons/sprBreakingBottle_strip4.png",18,false)
    _splat = load("res://assets/level3/source/Gore/sprBloodSplat_strip8.png")
    _pool_texture = load("res://assets/level3/source/Gore/sprBloodPool_strip66.png")
    _random.seed = 3137
    for i in range(CAPACITY): _slots.append({"life":0.0,"time":0.0,"kind":&"none","start":Vector2.ZERO,"end":Vector2.ZERO,"color":Color.WHITE,"angle":0.0})

func _take(kind: StringName, life: float, start: Vector2, end: Vector2, color: Color, angle: float = 0.0) -> void:
    var index := _cursor
    for offset in range(CAPACITY):
        var candidate := (_cursor+offset)%CAPACITY
        if _slots[candidate]["life"]<=0.0:
            index = candidate
            break
    _slots[index].merge({"kind":kind,"life":life,"time":0.0,"start":start,"end":end,"color":color,"angle":angle},true)
    _cursor = (index+1)%CAPACITY

func trace(start: Vector2, end: Vector2, color: Color) -> void: _take(&"trace",0.055,start,end,color)
func muzzle(at: Vector2, angle: float) -> void: _take(&"muzzle",0.15,at,Vector2.ZERO,Color(1,0.89,0.61),angle)
func glass(at: Vector2) -> void: _take(&"glass",0.23,at,Vector2.ZERO,Color(0.74,0.91,0.94))
func blood(at: Vector2, direction: Vector2, permanent: bool, strength: float) -> void:
    for i in range(15):
        var velocity := direction.rotated(_random.randf_range(-0.85,0.85))*_random.randf_range(22.0,94.0)*strength
        _take(&"drop",0.34,at,velocity,Color(0.69,0.075,0.095,0.95))
    if not permanent: return
    var texture_: Texture2D = _splat if _random.randf()<0.55 else _pool_texture
    var count := 8 if texture_==_splat else 66
    var frame := _random.randi_range(4,7) if count==8 else _random.randi_range(42,65)
    var width := float(texture_.get_width())/count
    get_parent().get_node("BloodStainLayer").add_stain(texture_,Rect2(frame*width,0,width,texture_.get_height()),at,_random.randf_range(0.6,0.88)*strength,_random.randf_range(0,TAU),Color(0.65,0.12,0.14,0.8))

func _process(delta: float) -> void:
    var active := false
    for slot in _slots:
        if slot["life"]<=0.0: continue
        slot["time"] += delta
        slot["life"] -= delta
        active = true
    if active: queue_redraw()

func _draw() -> void:
    for slot in _slots:
        if slot["life"]<=0.0: continue
        var color: Color = slot["color"]
        if slot["kind"]==&"trace":
            color.a *= float(slot["life"])/0.055
            draw_line(slot["start"],slot["end"],color,1.2,true)
        elif slot["kind"]==&"drop":
            var t: float = slot["time"]
            color.a *= minf(1.0,float(slot["life"])*8.0)
            draw_circle(slot["start"]+slot["end"]*t/(1.0+t*4.0),1.2,color)
        else:
            var frames := _muzzle if slot["kind"]==&"muzzle" else _glass
            var index := mini(frames.get_frame_count(&"default")-1,int(float(slot["time"])*28.0))
            var tex := frames.get_frame_texture(&"default",index)
            var size_ := Vector2(tex.get_size())*(0.48 if slot["kind"]==&"muzzle" else 0.73)
            draw_set_transform(slot["start"],slot["angle"])
            draw_texture_rect(tex,Rect2(-size_*0.5,size_),false,color)
    draw_set_transform(Vector2.ZERO)

func active_count() -> int:
    var result := 0
    for slot in _slots:
        if slot["life"]>0.0: result += 1
    return result
