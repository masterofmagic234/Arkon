extends SceneTree
const Data = preload("res://scripts/level3_store_data.gd")
const Visual = preload("res://scripts/level3_asset_visual.gd")

func _init() -> void: call_deferred("_run")
func _own(node: Node, parent: Node, scene: Node) -> void:
    parent.add_child(node)
    node.owner = scene
func _body(id: String, rect: Rect2, parent: Node, scene: Node) -> void:
    var body := StaticBody2D.new()
    body.name = id
    body.position = rect.get_center()
    body.collision_layer = 1
    body.collision_mask = 0
    _own(body,parent,scene)
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    var collision := CollisionShape2D.new()
    collision.shape = shape
    _own(collision,body,scene)

func _stable_ids(path: String) -> void:
    # PackedScene assigns random suffixes to newly authored resources. Keep
    # generated diffs reproducible without changing references or geometry.
    var text := FileAccess.get_file_as_string(path)
    var pattern := RegEx.new()
    pattern.compile('\\[(ext_resource|sub_resource)[^\\n]* id="([^"]+)"')
    var index := 0
    for match_ in pattern.search_all(text):
        index+=1
        var previous := match_.get_string(2)
        var replacement := "Authored%03d"%index
        text=text.replace('id="'+previous+'"','id="'+replacement+'"')
        var kind := "ExtResource" if match_.get_string(1)=="ext_resource" else "SubResource"
        text=text.replace(kind+'("'+previous+'")',kind+'("'+replacement+'")')
    pattern.compile(" unique_id=[0-9]+")
    text=pattern.sub(text,"",true)
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(text)
    file.close()

func _run() -> void:
    var scene := Node2D.new()
    scene.name = "Level3Layout"
    scene.set_script(load("res://scripts/level3_layout_editor.gd"))
    var floor_ := Node2D.new()
    floor_.name = "Floor"
    floor_.set_script(load("res://scripts/level3_layout_floor.gd"))
    floor_.z_index = -20
    _own(floor_,scene,scene)
    var walls := Node2D.new()
    walls.name = "Walls"
    _own(walls,scene,scene)
    var index := 0
    for y in range(Data.map_size().y):
        var x := 0
        while x < Data.map_size().x:
            if Data.tile_at(Vector2i(x,y)) != "#":
                x += 1
                continue
            var start := x
            while x < Data.map_size().x and Data.tile_at(Vector2i(x,y)) == "#": x += 1
            _body("Wall_%03d"%index,Rect2(start*16,y*16,(x-start)*16,16),walls,scene)
            index += 1
    var furniture := Node2D.new()
    furniture.name = "Furniture"
    _own(furniture,scene,scene)
    for prop in Data.get_furniture_layout():
        var tex := Visual.frame_texture(prop["texture"],prop["frame"])
        if tex == null:
            push_error("Missing Level 3 prop: "+prop["texture"])
            quit(1)
            return
        var node := Node2D.new()
        node.name = prop["id"]
        node.position = prop["position"]
        node.rotation = prop["rotation"]
        _own(node,furniture,scene)
        # The drawn shadow and collision derive from the same visible rectangle.
        var sprite := Sprite2D.new()
        sprite.name = "Visual"
        sprite.texture = tex
        sprite.scale = Vector2.ONE * float(prop["scale"])
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.modulate = Color(0.92,0.92,0.91)
        _own(sprite,node,scene)
        if prop["solid"]:
            var size_ := Vector2(tex.get_size())*float(prop["scale"])*0.80
            _body("Body",Rect2(-size_*0.5,size_),node,scene)
            node.set_meta("footprint",Rect2(-size_*0.5,size_))
            var shadow := Polygon2D.new()
            shadow.name = "ContactShadow"
            var half := size_*0.5+Vector2(2,2)
            shadow.polygon = PackedVector2Array([-half,Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)])
            shadow.position = Vector2(2.0,3.0)
            shadow.color = Color(0.015,0.012,0.025,0.5)
            shadow.z_index = -1
            _own(shadow,node,scene)
    var doors := Node2D.new()
    doors.name = "Doors"
    _own(doors,scene,scene)
    var door_scene := load("res://scenes/level3_door.tscn") as PackedScene
    for cell in Data.get_door_cells():
        var door := door_scene.instantiate() as Node2D
        door.name = "Door_%02d_%02d"%[cell.x,cell.y]
        door.position = Data.door_center(cell)
        door.rotation = Data.door_rotation(cell)
        _own(door,doors,scene)
    var packed := PackedScene.new()
    if packed.pack(scene) != OK or ResourceSaver.save(packed,"res://scenes/level3_layout.tscn") != OK:
        push_error("Could not save Level 3 layout")
        quit(1)
        return
    _stable_ids("res://scenes/level3_layout.tscn")
    print("LEVEL 3 LAYOUT: ",index," wall runs, ",furniture.get_child_count()," supplied props, ",doors.get_child_count()," doors")
    scene.free()
    quit(0)
