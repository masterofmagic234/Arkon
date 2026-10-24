extends RefCounted
# Trace every physical water component (including both sides of the return
# bridge), then inset it. No visual water can spill onto a walkable shortcut.
const Data=preload("res://scripts/level_data.gd")
const Props=preload("res://scripts/level1_park_props.gd")
var outline:=PackedVector2Array()

func build(host) -> void:
    var edges: Dictionary={}
    var sides: Array=[[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.UP],[Vector2i.RIGHT,Vector2i.ONE,Vector2i.RIGHT],[Vector2i.ONE,Vector2i.DOWN,Vector2i.DOWN],[Vector2i.DOWN,Vector2i.ZERO,Vector2i.LEFT]]
    for y in range(Data.MAP_HEIGHT):
        for x in range(Data.MAP_WIDTH):
            var cell:=Vector2i(x,y)
            if not Data.is_pond(cell): continue
            for side in sides:
                if not Data.is_pond(cell+side[2]):
                    var a: Vector2i=cell+side[0]
                    if not edges.has(a): edges[a]=[]
                    edges[a].append(cell+side[1])
    var index:=0
    while not edges.is_empty():
        var raw:=PackedVector2Array()
        var first: Vector2i=edges.keys()[0];var current:=first
        for step in range(2000):
            raw.append(Data.MAP_WORLD_ORIGIN+(Vector2(current)-Vector2.ONE*.5)*Data.CELL_SIZE)
            if not edges.has(current): break
            var next: Vector2i=edges[current].pop_back()
            if edges[current].is_empty(): edges.erase(current)
            current=next
            if current==first: break
        if raw.size()<4 or Geometry2D.is_polygon_clockwise(raw): continue
        var offset:=Geometry2D.offset_polygon(raw,-.32,Geometry2D.JOIN_ROUND)
        if offset.is_empty(): continue
        outline=offset[0]
        var center:=Vector2.ZERO
        for p in outline: center+=p
        center/=outline.size()
        var moon: bool=center.distance_to(Vector2(Data.park_position("Acorn03").x,Data.park_position("Acorn03").z))<35
        var root_:=Node3D.new();root_.name="MoonGardenPond" if moon else "EstateLake%d"%index
        host.scenery_root.add_child(root_);index+=1
        var bank:=SurfaceTool.new();bank.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(outline.size()):
            var a:=outline[i];var b:=outline[(i+1)%outline.size()]
            var c:=_closest(a,raw);var d:=_closest(b,raw)
            for pair: Vector3 in [Vector3(a.x,.036,a.y),Vector3(c.x,.002,c.y),Vector3(b.x,.036,b.y),Vector3(b.x,.036,b.y),Vector3(c.x,.002,c.y),Vector3(d.x,.002,d.y)]:
                bank.set_color(Color(1 if pair.y<.01 else 0,0,0,1));bank.set_normal(Vector3.UP);bank.set_uv(Vector2(pair.x,pair.z)*.2);bank.add_vertex(pair)
        bank.index()
        var shore:=MeshInstance3D.new();shore.name="NaturalShore";shore.mesh=bank.commit()
        var shore_mat:=ShaderMaterial.new();shore_mat.shader=preload("res://shaders/level1_pond_shore.gdshader")
        shore.material_override=shore_mat;shore.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root_.add_child(shore)
        # Sparse reeds on the bank; the large lake remains open negative space.
        for i in range(0,outline.size(),5):
            var p:=outline[i]
            for j in range(3):
                var h:=.7+float(posmod(i+j,5))*.14
                host._batch("cylinder","leaf",Vector3(p.x+j*.12,h*.5,p.y),Vector3(.022,h,.022))

    _build_surfaces(host)

func _build_surfaces(host) -> void:
    for moon in [true,false]:
        var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var count:=0
        for y in range(Data.MAP_HEIGHT):
            for x in range(Data.MAP_WIDTH):
                var cell:=Vector2i(x,y)
                if not Data.is_pond(cell): continue
                var in_moon: bool=(Vector2(cell)-Vector2(Data.MOON_CENTER)).length()<12
                if in_moon!=moon: continue
                var center:=Data.cell_center_world(cell)
                var corners: Array[Vector3]=[];var edge: Array[bool]=[]
                for side: Vector2i in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
                    var dry_x:=not Data.is_pond(cell+Vector2i(side.x,0))
                    var dry_y:=not Data.is_pond(cell+Vector2i(0,side.y))
                    var diagonal:=not Data.is_pond(cell+side)
                    # Bevel shoreline corners inside their own physical cell.
                    var inset_x:=.28 if dry_x else (.04 if dry_y or diagonal else 0.0)
                    var inset_y:=.28 if dry_y else (.04 if dry_x or diagonal else 0.0)
                    corners.append(center+Vector3(side.x*(.9-inset_x),.035,side.y*(.9-inset_y)))
                    edge.append(dry_x or dry_y or diagonal)
                for i in [0,2,1,0,3,2]:
                    var p: Vector3=corners[i]
                    st.set_normal(Vector3.UP);st.set_uv(Vector2(p.x,p.z)*.2);st.set_color(Color(.1 if edge[i] else 1.0,0,0,1));st.add_vertex(p)
                count+=1
        if count==0: continue
        st.index()
        var water:=MeshInstance3D.new();water.name="ObservatoryWater" if moon else "EstateLakeWater";water.mesh=st.commit()
        var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/level1_park_water.gdshader")
        mat.set_shader_parameter("panorama",preload("res://assets/level1/cozy/sky.svg"))
        var center:=Data.cell_center_world(Data.MOON_CENTER if moon else Data.LAKE_CENTER)
        var lamps:=Props.LAMPS.duplicate()
        lamps.sort_custom(func(a,b):return Data.cell_center_world(a).distance_squared_to(center)<Data.cell_center_world(b).distance_squared_to(center))
        var lights:=PackedVector3Array()
        for i in range(4): lights.append(Data.cell_center_world(lamps[i])+Vector3.UP*3.4)
        mat.set_shader_parameter("lantern_positions",lights);water.material_override=mat
        water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        water.add_to_group("estate_water");host.scenery_root.add_child(water)
        water.set_meta("physical_water_cells",count)

func _triangle(st: SurfaceTool,a: Vector2,b: Vector2,c: Vector2,depth: int) -> void:
    if depth>0:
        var ab:=(a+b)*.5;var bc:=(b+c)*.5;var ca:=(c+a)*.5
        _triangle(st,a,ab,ca,depth-1);_triangle(st,ab,b,bc,depth-1);_triangle(st,ca,bc,c,depth-1);_triangle(st,ab,bc,ca,depth-1)
        return
    for p in [a,c,b]:
        st.set_normal(Vector3.UP);st.set_uv(p*.2)
        st.set_color(Color(clampf(p.distance_to(_closest(p,outline))/1.8,0,1),0,0,1))
        st.add_vertex(Vector3(p.x,.035,p.y))

func _closest(p: Vector2,polygon: PackedVector2Array) -> Vector2:
    var best:=polygon[0];var distance_:=INF
    for i in range(polygon.size()):
        var q:=Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])
        var d:=p.distance_squared_to(q)
        if d<distance_: best=q;distance_=d
    return best
