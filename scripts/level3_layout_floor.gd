@tool
extends Node2D
const Data = preload("res://scripts/level3_store_data.gd")
const Visual = preload("res://scripts/level3_asset_visual.gd")
const BAKED_FLOOR := "res://assets/level3/materials/diner_floor.png"
const BAKED_RECT := Rect2(-160,-100,1088,782)
var authoring_bake := false
var _baked: Texture2D
var _grain: Texture2D
var _brick_h: Texture2D
var _brick_v: Texture2D
var _tile_h: Texture2D
var _tile_v: Texture2D

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if not authoring_bake:
        _baked = load(BAKED_FLOOR)
        queue_redraw()
        return
    _grain = load("res://assets/level3/source/Floor tiles/background2.png")
    _brick_h = Visual.first_frame_texture("res://assets/level3/source/Walls/sprWallBrickH.png")
    _brick_v = Visual.first_frame_texture("res://assets/level3/source/Walls/sprWallBrickV.png")
    _tile_h = Visual.first_frame_texture("res://assets/level3/source/Walls/sprWallHospitalH.png")
    _tile_v = Visual.first_frame_texture("res://assets/level3/source/Walls/sprWallHospitalV.png")
    queue_redraw()

func _draw() -> void:
    if not authoring_bake:
        if _baked != null: draw_texture_rect(_baked,BAKED_RECT,false)
        return
    var extent := Vector2(Data.map_size())*16
    draw_rect(Rect2(Vector2(-160,-100),extent+Vector2(320,270)),Color("101d29"))
    # The pavement continues past the facade; camera limits deliberately include it.
    draw_rect(Rect2(Vector2(-120,-60),extent+Vector2(240,120)),Color("233541"))
    draw_rect(Rect2(Vector2(-100,extent.y+33),Vector2(extent.x+200,100)),Color("12232d"))
    for x in range(-60,int(extent.x)+60,82):
        draw_rect(Rect2(x,extent.y+76,42,2),Color("616354"))
    draw_rect(Rect2(0,extent.y+7,extent.x,18),Color("4e5a61"))
    for x in range(0,int(extent.x),16): draw_line(Vector2(x,extent.y+7),Vector2(x,extent.y+25),Color("293b47"),1.0)
    draw_rect(Rect2(Vector2.ZERO,extent),Color("45414a"))
    for region in Data.get_room_floor_regions():
        var rect_: Rect2 = region["rect"]
        rect_ = Rect2(rect_.position*16,rect_.size*16)
        var base: Color = region["color"]
        draw_rect(rect_,base)
        if region["style"] == &"wood":
            for y in range(int(rect_.position.y),int(rect_.end.y),8):
                var tint := base.lightened(0.06) if y%16==0 else base.darkened(0.07)
                draw_rect(Rect2(rect_.position.x,y,rect_.size.x,7),tint)
                var offset := posmod(y*13,45)
                for x in range(int(rect_.position.x)+offset,int(rect_.end.x),60):
                    draw_line(Vector2(x,y),Vector2(x,y+7),base.darkened(0.36),0.6)
                draw_line(Vector2(rect_.position.x,y+6),Vector2(rect_.end.x,y+6),base.lightened(0.025),0.5)
        else:
            for y in range(int(rect_.position.y),int(rect_.end.y),12):
                for x in range(int(rect_.position.x),int(rect_.end.x),12):
                    var cell := Rect2(x,y,minf(11.3,rect_.end.x-x),minf(11.3,rect_.end.y-y))
                    var alternate := (x/12+y/12)%2==0
                    var tint := base.lightened(0.16) if alternate else base.darkened(0.42 if region["style"]==&"checker" else 0.08)
                    draw_rect(cell,tint)
                    draw_line(cell.position,cell.position+Vector2(cell.size.x,0),tint.lightened(0.06),0.5)
        if _grain != null: draw_texture_rect(_grain,rect_,true,Color(0.35,0.32,0.29,0.12))
        draw_rect(rect_.grow(-2),base.darkened(0.4),false,1.0)
    for y in range(Data.map_size().y):
        for x in range(Data.map_size().x):
            if Data.tile_at(Vector2i(x,y)) != "#": continue
            var rect_ := Rect2(x*16,y*16,16,16)
            draw_rect(Rect2(rect_.position+Vector2(2,4),rect_.size+Vector2(2,2)),Color(0.01,0.012,0.025,0.65))
            draw_rect(rect_,Color("272933"))
            var vertical := Data.tile_at(Vector2i(x,y-1))=="#" and Data.tile_at(Vector2i(x,y+1))=="#"
            var kitchen := x>=19 and y<=15
            var tex: Texture2D = (_tile_v if vertical else _tile_h) if kitchen else (_brick_v if vertical else _brick_h)
            if tex != null:
                var face := Rect2(rect_.position+Vector2(5,0),Vector2(6,16)) if vertical else Rect2(rect_.position+Vector2(0,5),Vector2(16,6))
                draw_texture_rect(tex,face,false,Color(0.59,0.65,0.68) if kitchen else Color(0.60,0.44,0.38))
            draw_rect(rect_.grow(-2),Color("5b6265") if kitchen else Color("69464b"),false,1.0)
            draw_line(rect_.position+Vector2(1,2),rect_.position+Vector2(15,2),Color("879090") if kitchen else Color("97716b"),0.7)
