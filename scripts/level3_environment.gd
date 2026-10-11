extends Node2D
class_name Level3Environment
const Data = preload("res://scripts/level3_store_data.gd")
const Visual = preload("res://scripts/level3_asset_visual.gd")
const NEON = preload("res://shaders/level3_neon.gdshader")
const RAIN = preload("res://shaders/level3_rain.gdshader")
var _glow: GradientTexture2D
var order_marker: Node2D
var exit_marker: Node2D
var light_count := 0

func _ready() -> void:
    scale = Vector2.ONE*1.5
    z_index = -8
    var ambient := CanvasModulate.new()
    ambient.color = Color(0.70,0.72,0.82)
    add_child(ambient)
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0,0.18,0.58,1.0])
    gradient.colors = PackedColorArray([Color(1,1,1,0.94),Color(1,1,1,0.61),Color(1,1,1,0.14),Color(1,1,1,0)])
    _glow = GradientTexture2D.new()
    _glow.gradient = gradient
    _glow.width = 256
    _glow.height = 256
    _glow.fill = GradientTexture2D.FILL_RADIAL
    _glow.fill_from = Vector2(0.5,0.5)
    _glow.fill_to = Vector2(1.0,0.5)
    var warm := Color(1.0,0.69,0.42)
    var cyan := Color(0.23,0.78,1.0)
    var pink := Color(1.0,0.25,0.53)
    for y in [4.6,10.2,15.8]:
        _light(Vector2(7.1,y),warm,78,0.74)
        _light(Vector2(12.6,y),warm,70,0.52)
    _light(Vector2(7,27),warm,93,0.64)
    _light(Vector2(25,4),Color(0.65,0.85,0.92),114,0.59)
    _light(Vector2(31.5,10),Color(0.51,0.82,0.91),95,0.43)
    _light(Vector2(43,6.0),cyan,103,0.43)
    _light(Vector2(43,24.5),Color(0.69,0.82,0.67),115,0.38)
    _light(Vector2(32.7,19.3),cyan,108,0.77)
    _light(Vector2(22.0,26.1),pink,111,0.50)
    _light(Vector2(23.3,18.9),warm,82,0.49)
    for y in [4.7,11.2,18.0]:
        _window(Vector2(0.5,y),true)
    for x in [4.0,10.5,15.5]: _window(Vector2(x,0.5),false)
    _sign("ACORN  DINER",Vector2(9.5,-1.4),15,Color(1.0,0.45,0.35),Vector2(175,27))
    _sign("OPEN   ·   02:17",Vector2(8,31.4),9,cyan,Vector2(114,15))
    _sign("ARCADE",Vector2(33.0,15.7),9,cyan,Vector2(74,14))
    _sign("KITCHEN",Vector2(28.0,0.6),8,Color(0.75,0.88,0.90),Vector2(83,12))
    _sign("COLD STORAGE",Vector2(43.0,0.6),7,cyan,Vector2(121,12))
    _sign("TAKE AWAY",Vector2(7.2,24.0),8,warm,Vector2(92,13))
    _sign("STAFF ONLY",Vector2(43.0,15.8),7,Color(0.75,0.83,0.65),Vector2(93,12))
    # Actual animated emissive strips supplied with the pack; furniture variants
    # themselves remain fixed, so tables/freezers cannot animate into other shapes.
    for pos in [Vector2(16.5,20.5),Vector2(16.5,17.5)]:
        var neon := Visual.animated_strip("res://assets/level3/source/Furniture/sprJukeboxGlow_strip8.png",6.0,Vector2.ONE*1.02)
        neon.position = pos*16
        neon.z_index = 1
        neon.material = _neon_material(Color(0.67,0.77,1.0,0.43))
        add_child(neon)
    _sprite("res://assets/level3/source/Furniture/sprNeonSign_strip2.png",Vector2(24,16.5),Vector2.ONE*1.28,0,Color(1,0.66,0.48))
    _sprite("res://assets/level3/source/Furniture/sprPizza_strip5.png",Vector2(27.5,5.1),Vector2.ONE*0.38,0,Color.WHITE)
    _sprite("res://assets/level3/source/Furniture/sprPlant2_strip2.png",Vector2(36,29.4),Vector2.ONE*0.54)
    _sprite("res://assets/level3/source/Furniture/sprWetFloorWarning.png",Vector2(35,10.0),Vector2.ONE*0.86)
    _sprite("res://assets/level3/source/Furniture/sprWaterPuddle_strip5.png",Vector2(34.5,11),Vector2.ONE*0.64,0,Color(0.7,0.92,1,0.29),-5)
    _sprite("res://assets/level3/source/Items/sprChipsBag.png",Vector2(43.6,18.5),Vector2.ONE*0.56)
    var car := _sprite("res://assets/level3/source/Vehicles/sprPlayerCar_strip13.png",Vector2(6.5,36.4),Vector2.ONE*0.82)
    car.rotation = PI*0.5
    _sprite("res://assets/level3/source/Vehicles/sprVan_strip2.png",Vector2(40,35.2),Vector2.ONE*0.67)
    _rain_rect(Rect2(-92,-50,87,720))
    _rain_rect(Rect2(-5,-50,800,44))
    _rain_rect(Rect2(-5,540,865,160))
    _reflection(Vector2(8,34.4),Vector2(0.95,0.20),Color(0.10,0.45,0.64,0.4))
    _reflection(Vector2(9.5,-3.0),Vector2(1.7,0.18),Color(0.75,0.16,0.18,0.28))
    _sprite("res://assets/level3/source/Doors/sprDoorH.png",Vector2(6.5,31.5),Vector2(1.05,0.65),0,Color(0.67,0.89,0.91))
    _sprite("res://assets/level3/source/Furniture/sprFloorMail.png",Vector2(11.1,20.4),Vector2.ONE*0.60,0,Color(0.85,0.85,0.77),-6)
    _sprite("res://assets/level3/source/Furniture/sprShards_strip11.png",Vector2(18,13),Vector2.ONE*0.65,4,Color(0.66,0.83,0.80,0.64),-6)
    for y in [4.6,10.2,15.8]:
        _sprite("res://assets/level3/source/Furniture/sprLamps_strip5.png",Vector2(12.5,y),Vector2.ONE*0.32,3,Color(1,0.85,0.68))
    order_marker = _marker(Data.ORDER_CELL,Color(1.0,0.74,0.30),"ЗАКАЗ")
    var pizza := Sprite2D.new()
    pizza.texture = Visual.first_frame_texture("res://assets/level3/source/Items/sprPizzaFresh.png")
    pizza.scale = Vector2.ONE*0.65
    pizza.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    order_marker.add_child(pizza)
    order_marker.visible = false
    exit_marker = _marker(Data.EXIT_CELL,Color(0.39,0.92,0.79),"ВЫХОД")
    exit_marker.visible = false

func _neon_material(color: Color) -> ShaderMaterial:
    var material_ := ShaderMaterial.new()
    material_.shader = NEON
    material_.set_shader_parameter("neon_color",color)
    material_.set_shader_parameter("phase",color.r*7.0)
    return material_

func _light(at: Vector2, color: Color, radius: float, energy_: float) -> void:
    var light := PointLight2D.new()
    light.name = "DinerLight%02d"%light_count
    light.position = at*16
    light.texture = _glow
    light.texture_scale = radius*2.0/256.0
    light.color = color
    light.energy = energy_
    light.shadow_enabled = false
    add_child(light)
    light_count += 1

func _sprite(path: String, at: Vector2, scale_: Vector2, frame: int = 0, color: Color = Color.WHITE, depth: int = 0) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = Visual.frame_texture(path,frame)
    sprite.position = at*16
    sprite.scale = scale_
    sprite.modulate = color
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.z_index = depth
    add_child(sprite)
    return sprite

func _window(at: Vector2, vertical: bool) -> void:
    var path := "res://assets/level3/source/Walls/sprWindowRight_strip2.png" if vertical else "res://assets/level3/source/Walls/sprWindowDown_strip2.png"
    _sprite(path,at,Vector2(0.88,1.2) if vertical else Vector2(1.2,0.88),0,Color(0.77,0.87,0.98))
    _reflection(at+(Vector2.RIGHT*2.4 if vertical else Vector2.DOWN*2.3),Vector2(0.40,0.58),Color(0.05,0.27,0.40,0.26))

func _reflection(at: Vector2, scale_: Vector2, color: Color) -> void:
    var sprite := Sprite2D.new()
    sprite.texture = _glow
    sprite.position = at*16
    sprite.scale = scale_
    sprite.modulate = color
    sprite.z_index = -5
    var mat := CanvasItemMaterial.new()
    mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    sprite.material = mat
    add_child(sprite)

func _sign(text: String, at: Vector2, font_size: int, color: Color, size_: Vector2) -> Label:
    var sign := Label.new()
    sign.text = text
    sign.position = at*16-size_*0.5
    sign.size = size_
    sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sign.add_theme_font_size_override("font_size",font_size)
    sign.add_theme_color_override("font_color",color)
    sign.add_theme_color_override("font_shadow_color",Color(0.015,0.02,0.04,0.9))
    sign.add_theme_constant_override("shadow_offset_y",1)
    sign.add_theme_constant_override("outline_size",3)
    sign.add_theme_color_override("font_outline_color",Color("141f2d"))
    var sign_material := CanvasItemMaterial.new()
    sign_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    sign.material = sign_material
    sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(sign)
    return sign

func _rain_rect(rect_: Rect2) -> void:
    var quad := Polygon2D.new()
    quad.polygon = PackedVector2Array([rect_.position,rect_.position+Vector2(rect_.size.x,0),rect_.end,rect_.position+Vector2(0,rect_.size.y)])
    quad.uv = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
    var mat := ShaderMaterial.new()
    mat.shader = RAIN
    quad.material = mat
    quad.z_index = 3
    add_child(quad)

func _marker(cell: Vector2i, color: Color, text: String) -> Node2D:
    var marker := Node2D.new()
    marker.position = Data.cell_to_world(cell)
    var glow := Sprite2D.new()
    glow.texture = _glow
    glow.scale = Vector2.ONE*0.22
    glow.modulate = Color(color,0.35)
    glow.material = _neon_material(Color.WHITE)
    marker.add_child(glow)
    var label := Label.new()
    label.position = Vector2(-35,-24)
    label.size = Vector2(70,16)
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",8)
    label.add_theme_color_override("font_color",color)
    label.add_theme_constant_override("outline_size",3)
    label.add_theme_color_override("font_outline_color",Color("162533"))
    var label_material := CanvasItemMaterial.new()
    label_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    label.material = label_material
    marker.add_child(label)
    marker.z_index = 8
    add_child(marker)
    return marker
