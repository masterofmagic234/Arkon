extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Batch=preload("res://scripts/race_canvas_batch.gd")
const Clip=preload("res://scripts/race_projection.gd")
const Frame=preload("res://scripts/race_projection_frame.gd")
var batch=Batch.new()
var exit_batch=Batch.new()
var cutting=Batch.new()
var material := ShaderMaterial.new()
var models: Array=[]
var transformed_vertices := 0
var triangles := 0

func setup(host: Node2D) -> void:
    batch.setup(host,"RockyMountain",host._tex("res://assets/level2/mountain_rock.jpg"),-3)
    material.shader=preload("res://shaders/race_mountain.gdshader")
    material.set_shader_parameter("bank_grass",host.grass_texture)
    batch.node.material=material
    exit_batch.setup(host,"ExitMountain",batch.node.texture,-3)
    exit_batch.node.material=material
    cutting.setup(host,"MountainCutting",batch.node.texture,-1)
    cutting.node.material=material

func bind(host: Node2D) -> void:
    models=[_build(host,Data.TUNNEL_START,1),_build(host,Data.TUNNEL_END,-1)]

func _point(model: Dictionary,p: Vector3) -> int:
    p.y+=Data.road_height(p.z)
    if model.lookup.has(p): return model.lookup[p]
    var id: int=model.points.size()
    model.points.append(p);model.lookup[p]=id
    return id

func _face(model: Dictionary,source: Array[Vector3],tint: Color) -> void:
    var ids := PackedInt32Array()
    for p in source: ids.append(_point(model,p))
    for i in range(1,ids.size()-1):
        var normal := (source[i]-source[0]).cross(source[i+1]-source[0]).normalized()
        var light := .74+.24*absf(normal.dot(Vector3(-.4,.8,-.5).normalized()))
        model.faces.append(PackedInt32Array([ids[0],ids[i],ids[i+1]]))
        model.kinds.append(1 if model.bank else 0)
        model.colors.append(Color(tint.r*light,tint.g*light,tint.b*light,1))

func _build(host: Node2D,z: float,inward: float) -> Dictionary:
    var model := {"z":z,"points":PackedVector3Array(),"faces":[],"colors":PackedColorArray(),"kinds":PackedInt32Array(),"bank":false,"lookup":{}}
    var center: float=host._smooth_track_x(z/40)
    var widths := [Data.TUNNEL_RADIUS,7.4,18.0,58.0,150.0,300.0,490.0]
    var heights := [Data.TUNNEL_RADIUS,7.4,19.0,55.0,135.0,180.0,2.0]
    var depths := [0.0,.6,5.0,30.0,95.0,230.0,650.0]
    var rings: Array=[]
    for ring in range(widths.size()):
        var points: Array[Vector3]=[]
        for i in range(25):
            var a := float(i)*PI/24
            var rough := .22*sin(a*3.1+.6)+.11*sin(a*7.3-ring*.3)+.07*sin(a*13-ring*.9)
            var profile := 1.0 if ring<2 else 1.0+rough*sin(a)
            var x: float=-cos(a)*widths[ring]+(0 if ring<2 else sin(a)*sin(ring*.9)*widths[ring]*.10)
            var y: float=sin(a)*heights[ring]*profile
            var depth: float=depths[ring]+(0 if ring<2 else sin(a)*sin(a*4+ring)*depths[ring]*.10)
            points.append(Vector3(center+x,y,z+inward*depth))
        rings.append(points)
    # Curved irregular contours, many short facets and real depth replace the
    # eight flat triangles meeting at a single giant peak.
    for ring in range(1,rings.size()):
        var tint := Color("a9ada5") if ring==1 else (Color("747d80") if ring<5 else Color("5c6872"))
        for i in range(24):
            _face(model,[rings[ring-1][i],rings[ring][i],rings[ring][i+1],rings[ring-1][i+1]],tint)
    # Small terrain-following strips frame the cutting without covering road.
    model.bank=true
    for step in range(10):
        var t := float(step)/10;var nt := float(step+1)/10
        var az := z-260*(1-t)*inward;var bz := z-260*(1-nt)*inward
        var ac: float=host._smooth_track_x(az/40);var bc: float=host._smooth_track_x(bz/40)
        for side: float in [-1,1]:
            var a := Vector3(ac+side*lerpf(10,Data.TUNNEL_RADIUS,t),0,az)
            var b := Vector3(bc+side*lerpf(10,Data.TUNNEL_RADIUS,nt),0,bz)
            var ridge_a := Vector3(ac+side*(23+sin(t*13+side)*3),t*(7+sin(t*17+side)*2),az)
            var ridge_b := Vector3(bc+side*(23+sin(nt*13+side)*3),nt*(7+sin(nt*17+side)*2),bz)
            _face(model,[a,b,ridge_b,ridge_a],Color("686e6d"))
            _face(model,[ridge_a,ridge_b,Vector3(bc+side*95,0,bz),Vector3(ac+side*95,0,az)],Color("35462f"))
            # Layered retaining stone under the exposed cutting, outside the
            # driveable opening. These short faces follow the real road grade.
            var edge_a := a+Vector3(side*.45,0,0)
            var edge_b := b+Vector3(side*.45,0,0)
            var wall_a := edge_a+Vector3.UP*(.5+t*1.8)
            var wall_b := edge_b+Vector3.UP*(.5+nt*1.8)
            _face(model,[edge_a,edge_b,wall_b,wall_a],Color("7b807d"))
            # Irregular low outcrops break up the grassy base of the massif.
            var foot := Vector3(ac+side*(17+t*13),t*2,az+7*inward)
            var size_ := 1.2+t*2.0
            var peak := foot+Vector3(side*.5,size_,2*inward)
            _face(model,[foot+Vector3(-size_,0,0),foot+Vector3(size_,0,0),peak],Color("717b7a"))
            _face(model,[foot+Vector3(size_,0,0),foot+Vector3(0,0,size_*2*inward),peak],Color("657172"))
    model.erase("lookup")
    var order: Array=range(model.faces.size())
    order.sort_custom(func(a,b):
        var ia: PackedInt32Array=model.faces[a];var ib: PackedInt32Array=model.faces[b]
        return model.points[ia[0]].z+model.points[ia[1]].z+model.points[ia[2]].z>model.points[ib[0]].z+model.points[ib[1]].z+model.points[ib[2]].z)
    var faces: Array=[];var colors := PackedColorArray();var kinds := PackedInt32Array()
    for id in order: faces.append(model.faces[id]);colors.append(model.colors[id]);kinds.append(model.kinds[id])
    model.faces=faces;model.colors=colors;model.kinds=kinds
    return model

func visibility(z: float,portal_z: float) -> float:
    return 1.0-smoothstep(1050,2600,portal_z-z)

func draw(host: Node2D,frame: Frame,vp: Vector2) -> void:
    batch.begin();exit_batch.begin();cutting.begin();transformed_vertices=0;triangles=0
    var origin: float=host.player_car.world_z
    var inside := origin>=Data.TUNNEL_START and origin<Data.TUNNEL_END
    material.set_shader_parameter("logical_size",vp)
    material.set_shader_parameter("pivot",frame.pivot)
    material.set_shader_parameter("focal",frame.focal)
    material.set_shader_parameter("camera_yaw",host.camera_state.yaw_offset)
    material.set_shader_parameter("camera_roll",host.camera_state.roll)
    material.set_shader_parameter("camera_x",host._camera_world_x(host.player_car.track_phase()))
    material.set_shader_parameter("camera_z",origin-host._behind())
    for model in models:
        if model.z==Data.TUNNEL_START and (inside or origin>=Data.TUNNEL_START): continue
        if model.z==Data.TUNNEL_END and (not inside or origin<Data.TUNNEL_END-224): continue
        var fade := visibility(origin,model.z)
        if fade<=0: continue
        var target=batch if model.z==Data.TUNNEL_START else exit_batch
        var world: PackedVector3Array=model.points
        var camera := PackedVector3Array();camera.resize(world.size())
        var screen := PackedVector2Array();screen.resize(world.size())
        var uv := PackedVector2Array();uv.resize(world.size())
        for i in range(world.size()):
            camera[i]=frame.transform*world[i]
            if camera[i].z>=Frame.NEAR:
                screen[i]=frame.project(camera[i]);uv[i]=Vector2(world[i].y,1)/camera[i].z
        transformed_vertices+=world.size()
        for f in range(model.faces.size()):
            var ids: PackedInt32Array=model.faces[f]
            var a := camera[ids[0]];var b := camera[ids[1]];var c := camera[ids[2]]
            if maxf(a.z,maxf(b.z,c.z))<Frame.NEAR: continue
            var points := PackedVector2Array();var coords := PackedVector2Array()
            if minf(a.z,minf(b.z,c.z))>=Frame.NEAR:
                points=PackedVector2Array([screen[ids[0]],screen[ids[1]],screen[ids[2]]])
                coords=PackedVector2Array([uv[ids[0]],uv[ids[1]],uv[ids[2]]])
            else:
                for p in frame.clip([a,b,c]):
                    points.append(frame.project(p));coords.append(Vector2((frame.inverse*p).y,1)/p.z)
            if points.size()<3: continue
            var min_: Vector2=points[0];var max_: Vector2=points[0];var contained := true
            for p in points:
                min_=min_.min(p);max_=max_.max(p)
                if not frame.viewport.has_point(p): contained=false
            if not Rect2(min_,max_-min_).intersects(frame.viewport): continue
            if not contained:
                var clipped := Clip.clip_textured_screen(points,coords,frame.viewport)
                points=clipped.points;coords=clipped.uv
            var color: Color=model.colors[f];color.a=fade
            triangles+=maxi(0,points.size()-2)
            var face_target=cutting if model.kinds[f]==1 else target
            face_target.polygon(points,color,coords)
    batch.commit()
    exit_batch.commit()
    cutting.commit()
