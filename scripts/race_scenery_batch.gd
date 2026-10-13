extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Batch=preload("res://scripts/race_canvas_batch.gd")
const Frame=preload("res://scripts/race_projection_frame.gd")
const Clip=preload("res://scripts/race_projection.gd")
const Signs=preload("res://scripts/race_location_signs.gd")
var frame := Frame.new()
var mountain=preload("res://scripts/race_mountain.gd").new()
var boards := Batch.new()
var opaque := Batch.new()
var distant_opaque := Batch.new()
var distant_boards := Batch.new()
var _target := opaque
var textures: Dictionary={}
var foreground: Dictionary={}
var groups: Dictionary={}
var wheat: Texture2D
var _building := false
var _group: Dictionary={}
var _point_ids: Dictionary={}
var triangles := 0
var transformed_vertices := 0
var viewport := Rect2()

func setup(host: Node2D) -> void:
    mountain.setup(host)
    wheat=host._tex("res://assets/level2/wheat_tuft.png")
    for texture in [host.pine_texture,host.oak_texture,wheat,host.lamp_texture]:
        if texture==null or textures.has(texture): continue
        var batch := Batch.new()
        batch.setup(host,"ScenicSprites_%d"%textures.size(),texture,-4)
        textures[texture]=batch
    opaque.setup(host,"ScenicArchitecture",null,-1)
    distant_opaque.setup(host,"DistantArchitecture",null,-4)
    distant_boards.setup(host,"DistantBoards",host._tex("res://assets/level2/location_signs.png"),-4)
    distant_boards.node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
    boards.setup(host,"LocationBoards",host._tex("res://assets/level2/location_signs.png"),-1)
    boards.node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
    # Trees in front of the entrance must cover the mountain behind them,
    # rather than having their crowns sliced off by a later opaque batch.
    for texture in textures:
        var batch := Batch.new()
        batch.setup(host,"ScenicForeground_%d"%foreground.size(),texture,-1)
        foreground[texture]=batch

func bind(host: Node2D) -> void:
    groups.clear();_building=true
    for index in range(ceili(Data.route_length()/16.0)):
        var z := float(index)*16.0
        _group={"z":z,"points":PackedVector3Array(),"faces":[],"lines":[],"sprites":[],"boards":[]}
        _point_ids.clear()
        groups[index]=_group
        var c: float=host._smooth_track_x(z/40.0)
        var nc: float=host._smooth_track_x((z+16)/40.0)
        var sector := Data.sector_at(z)
        if sector==1:
            for side: float in [-1,1]:
                for row in range(4):
                    _sprite(Vector3(c+side*(8.8+row*6),0,z),wheat,6.4,1.35,Color("aa9f6c"))
                var x := c+side*Data.FIELD_FENCE_X;var nx := nc+side*Data.FIELD_FENCE_X
                line(host,Vector3(x,0,z),Vector3(x,1.15,z),Color("968375"),.12,Vector2.ZERO)
                for h: float in [.43,.88]: line(host,Vector3(x,h,z),Vector3(nx,h,z+16),Color("968375"),.09,Vector2.ZERO)
        elif sector in [0,3] and z<Data.TUNNEL_START-145:
            for side: float in [-1,1]:
                for row in range(2):
                    var x := c+side*(12+row*12+sin(index*1.74+row)*2)
                    var texture: Texture2D=host.pine_texture if (index+row)%3!=0 else host.oak_texture
                    _sprite(Vector3(x,0,z),texture,8,10+sin(index*.75+row)*2,Color("80998c"))
                if index%2==0: _sprite(Vector3(c+side*7.2,0,z),wheat,2.5,.75,Color("607b6b"))
        elif sector==5 and index%3==0:
            for side: float in [-1,1]:
                _sprite(Vector3(c+side*12,0,z),host.lamp_texture,1.8,8,Color("b5c1c8"))
                if index%6==0: _sprite(Vector3(c+side*16,0,z),host.oak_texture,7.8,10,Color("7b9182"))
        if sector==3 and z>=Data.TUNNEL_START-260 and index%3==0:
            var approach := clampf((z-(Data.TUNNEL_START-260))/260,0,1)
            for side: float in [-1,1]:
                _sprite(Vector3(c+side*(31+sin(index*1.7)*3),approach*4,z),host.pine_texture,7,8+sin(index)*1.2,Color("677b75"))
        if z>=Data.BRIDGE_START and z<Data.BRIDGE_END: _bridge(host,c,nc,z,index)
        if z>=Data.TUNNEL_START and z<Data.TUNNEL_END: _tunnel(host,c,nc,z,index)
    # Stable roadside markers/curve rails are authored once as well.
    for index in range(ceili(Data.route_length()/20)):
        var z := float(index)*20
        _select_group(z)
        var c: float=host._smooth_track_x(z/40)
        var curve: float=host._render_curve_at(z/40)
        if z>=Data.TUNNEL_START and z<Data.TUNNEL_END: continue
        for side: float in [-1,1]:
            var x := c+side*Data.CURVE_RAIL_X
            line(host,Vector3(x,0,z),Vector3(x,.85,z),Color("6e8388"),.085,Vector2.ZERO)
            line(host,Vector3(x,.56,z),Vector3(x,.76,z),Color("edbd77"),.12,Vector2.ZERO)
            if absf(curve)>.4 and side==-signf(curve):
                var nx: float=host._smooth_track_x((z+20)/40)+side*Data.CURVE_RAIL_X
                line(host,Vector3(x,.56,z),Vector3(nx,.56,z+20),Color("586f7c"),.13,Vector2.ZERO)
                if index%2==0:
                    surface(host,[Vector3(x-.34,1.09,z),Vector3(x+.34,1.09,z),Vector3(x+.34,1.61,z),Vector3(x-.34,1.61,z)],Color("172731"),Vector2.ZERO)
                    var d := signf(curve)
                    line(host,Vector3(x-d*.16,1.51,z),Vector3(x+d*.10,1.35,z),Color("e6bc76"),.07,Vector2.ZERO)
                    line(host,Vector3(x+d*.10,1.35,z),Vector3(x-d*.16,1.19,z),Color("e6bc76"),.07,Vector2.ZERO)
    for sector in range(1,Data.SECTOR_STARTS.size()):
        var z: float=Signs.board_z(sector)
        _select_group(z)
        var bridge := z>=Data.BRIDGE_START and z<Data.BRIDGE_END
        var width := 4.0 if bridge else 6.0
        var x: float=host._smooth_track_x(z/40)+(6.2 if bridge else 10.8)
        var height := width*.25
        line(host,Vector3(x,.48 if bridge else 0,z),Vector3(x,3.2,z),Color("8a9c9c"),.14,Vector2.ZERO)
        var ids := PackedInt32Array()
        for p in [Vector3(x-width*.5,3.2,z),Vector3(x+width*.5,3.2,z),Vector3(x+width*.5,3.2+height,z),Vector3(x-width*.5,3.2+height,z)]: ids.append(_point(p))
        _group.boards.append({"ids":ids,"left":x-width*.5,"top":Data.road_height(z)+3.2+height,"width":width,"height":height,"row":sector-1})
    mountain.bind(host)
    _building=false

func _select_group(z: float) -> void:
    var key := floori(z/16)
    if not groups.has(key): groups[key]={"z":z,"points":PackedVector3Array(),"faces":[],"lines":[],"sprites":[],"boards":[]}
    _group=groups[key]
    _point_ids.clear()
    for i in range(_group.points.size()): _point_ids[_group.points[i]]=i

func _absolute(p: Vector3) -> Vector3:
    return p+Vector3.UP*Data.road_height(p.z)
func _point(p: Vector3) -> int:
    p=_absolute(p)
    if _point_ids.has(p): return _point_ids[p]
    var index: int=_group.points.size()
    _group.points.append(p);_point_ids[p]=index
    return index
func _sprite(p: Vector3,texture: Texture2D,width: float,height: float,tint: Color) -> void:
    if texture!=null: _group.sprites.append({"point":_point(p),"texture":texture,"width":width,"height":height,"tint":tint})
func line(_host: Node2D,a: Vector3,b: Vector3,color: Color,thickness: float,_vp: Vector2) -> void:
    if _building: _group.lines.append({"a":_point(a),"b":_point(b),"color":color,"width":thickness})
func surface(_host: Node2D,points: Array[Vector3],color: Color,_vp: Vector2) -> void:
    if not _building: return
    var ids := PackedInt32Array()
    for p in points: ids.append(_point(p))
    for i in range(1,ids.size()-1): _group.faces.append({"indices":PackedInt32Array([ids[0],ids[i],ids[i+1]]),"color":color})

func begin(host: Node2D,vp: Vector2) -> void:
    frame.configure(host,vp);viewport=frame.viewport
    opaque.begin();triangles=0;transformed_vertices=0
    distant_opaque.begin();boards.begin();distant_boards.begin()
    for batch in textures.values(): batch.begin()
    for batch in foreground.values(): batch.begin()

func draw(host: Node2D,vp: Vector2) -> void:
    var origin: float=host.player_car.world_z
    var inside := origin>=Data.TUNNEL_START and origin<Data.TUNNEL_END
    var cut := Data.TUNNEL_START if origin<Data.TUNNEL_START else (Data.TUNNEL_END if origin<Data.TUNNEL_END else INF)
    var distance := 224.0 if inside else 480.0
    mountain.draw(host,frame,vp)
    triangles=mountain.triangles;transformed_vertices=mountain.transformed_vertices
    var first := maxi(0,floori((origin-80)/16))
    var last := mini(ceili(Data.route_length()/16),ceili((origin+distance)/16))
    for index in range(last,first-1,-1):
        if not groups.has(index): continue
        var group: Dictionary=groups[index]
        _target=opaque if float(group.z)<cut else distant_opaque
        var world: PackedVector3Array=group.points
        var camera := PackedVector3Array();camera.resize(world.size())
        var screen := PackedVector2Array();screen.resize(world.size())
        var any_front := false
        for i in range(world.size()):
            camera[i]=frame.transform*world[i]
            if camera[i].z>=Frame.NEAR: screen[i]=frame.project(camera[i]);any_front=true
        transformed_vertices+=world.size()
        if not any_front: continue
        var fog := smoothstep(80,distance,float(group.z)-origin)
        var fog_color := Color("070c10") if inside else Color("293e4c")
        for sprite in group.sprites:
            var index_: int=sprite.point
            var p := camera[index_]
            if p.z<Frame.NEAR: continue
            var scale_ := frame.focal/p.z
            var size_ := Vector2(float(sprite.width),float(sprite.height))*scale_
            var rect := Rect2(screen[index_]-Vector2(size_.x*.5,size_.y),size_)
            if not rect.intersects(viewport): continue
            var tint: Color=sprite.tint
            var front := world[index_].z<cut
            var batch=foreground[sprite.texture] if front else textures[sprite.texture]
            batch.rectangle(rect,tint.lerp(fog_color,fog*.85),viewport)
        for face in group.faces:
            var ids: PackedInt32Array=face.indices
            var a := camera[ids[0]];var b := camera[ids[1]];var c := camera[ids[2]]
            if maxf(a.z,maxf(b.z,c.z))<Frame.NEAR: continue
            var points := PackedVector2Array()
            if minf(a.z,minf(b.z,c.z))>=Frame.NEAR:
                points=PackedVector2Array([screen[ids[0]],screen[ids[1]],screen[ids[2]]])
            else:
                for point in frame.clip([a,b,c]): points.append(frame.project(point))
            var color: Color=face.color
            _emit(points,color.lerp(fog_color,fog*.8))
        for board in group.boards:
            var source: Array[Vector3]=[]
            for id in board.ids: source.append(camera[id])
            var points := PackedVector2Array();var uv := PackedVector2Array()
            for p in frame.clip(source,true):
                points.append(frame.project(p))
                var world_: Vector3=frame.inverse*p
                uv.append(Vector2(clampf((world_.x-board.left)/board.width,0,1),(board.row+clampf((board.top-world_.y)/board.height,0,1))/5.0))
            var target_boards=boards if float(group.z)<cut else distant_boards
            target_boards.polygon(points,Color.WHITE.lerp(fog_color,fog*.55),uv)
        for beam in group.lines:
            var a := camera[beam.a];var b := camera[beam.b]
            if a.z<Frame.NEAR and b.z<Frame.NEAR: continue
            if a.z<Frame.NEAR: a=a.lerp(b,(Frame.NEAR-a.z)/(b.z-a.z))
            elif b.z<Frame.NEAR: b=b.lerp(a,(Frame.NEAR-b.z)/(a.z-b.z))
            var p := frame.project(a);var q := frame.project(b)
            if p.distance_squared_to(q)<.001: continue
            var side := (q-p).normalized().orthogonal()
            var w: float=frame.focal*float(beam.width)*.5
            var left := side*maxf(.35,w/a.z);var right := side*maxf(.35,w/b.z)
            var color: Color=beam.color
            _emit(PackedVector2Array([p+left,q+right,q-right,p-left]),color.lerp(fog_color,fog*.8))
    opaque.commit()
    distant_opaque.commit();distant_boards.commit()
    boards.commit()
    for batch in textures.values(): batch.commit()
    for batch in foreground.values(): batch.commit()


func _emit(points: PackedVector2Array,color: Color) -> void:
    if points.size()<3: return
    var min_: Vector2=points[0];var max_: Vector2=points[0]
    var contained := true
    for p in points:
        min_=min_.min(p);max_=max_.max(p)
        if not viewport.has_point(p): contained=false
    if not Rect2(min_,max_-min_).intersects(viewport): return
    if not contained: points=Clip.clip_screen(points,viewport)
    triangles+=maxi(0,points.size()-2)
    _target.polygon(points,color)

func _bridge(host: Node2D,c: float,nc: float,z: float,index: int) -> void:
    for side: float in [-1,1]:
        var x := c+side*Data.BRIDGE_RAIL_X;var nx := nc+side*Data.BRIDGE_RAIL_X
        surface(host,[Vector3(x,0,z),Vector3(nx,0,z+16),Vector3(nx,.48,z+16),Vector3(x,.48,z)],Color("526a7c"),Vector2.ZERO)
        for h: float in [.72,1.15]: line(host,Vector3(x,h,z),Vector3(nx,h,z+16),Color("728b9a"),.065,Vector2.ZERO)
        line(host,Vector3(x,.45,z),Vector3(x,1.22,z),Color("728b9a"),.085,Vector2.ZERO)
        if index%2==0: line(host,Vector3(x,1.15,z),Vector3(x,1.15,z+1.1),Color("eed8a3"),.12,Vector2.ZERO)
        if index%4==2:
            line(host,Vector3(c+side*6,0,z),Vector3(c+side*6,6.8,z),Color("728b9a"),.27,Vector2.ZERO)
            line(host,Vector3(c+side*6,6.8,z),Vector3(c+side*3.6,9.2,z),Color("728b9a"),.27,Vector2.ZERO)
            line(host,Vector3(c+side*3.6,9.2,z),Vector3(c,9.8,z),Color("728b9a"),.27,Vector2.ZERO)
            if z+64<Data.BRIDGE_END:
                var far: float=host._smooth_track_x((z+64)/40)
                line(host,Vector3(c+side*6,6.8,z),Vector3(far+side*6,6.8,z+64),Color("728b9a"),.18,Vector2.ZERO)
                line(host,Vector3(c+side*6,1,z),Vector3(far+side*6,6.8,z+64),Color("728b9a"),.1,Vector2.ZERO)

func _tunnel(host: Node2D,c: float,nc: float,z: float,index: int) -> void:
    for arc in range(8):
        var a := arc*PI/8;var b := (arc+1)*PI/8
        var x1 := cos(a)*Data.TUNNEL_RADIUS;var y1 := sin(a)*Data.TUNNEL_RADIUS
        var x2 := cos(b)*Data.TUNNEL_RADIUS;var y2 := sin(b)*Data.TUNNEL_RADIUS
        var color := Color("192730") if arc in [2,3,4,5] else Color("37454d")
        if index%2==0: color=color.lightened(.025)
        surface(host,[Vector3(c+x1,y1,z),Vector3(nc+x1,y1,z+16),Vector3(nc+x2,y2,z+16),Vector3(c+x2,y2,z)],color,Vector2.ZERO)
        line(host,Vector3(c+x1,y1,z),Vector3(c+x2,y2,z),Color("586267"),.065,Vector2.ZERO)
    for side: float in [-1,1]:
        for h: float in [.18,.70,1.05]: line(host,Vector3(c+side*6,h,z),Vector3(nc+side*6,h,z+16),Color("627074") if h>.5 else Color("ccb681"),.065,Vector2.ZERO)
        line(host,Vector3(c+side*4.5-.22,4,z),Vector3(c+side*4.5+.22,4,z),Color("ffe2ad"),.06,Vector2.ZERO)
