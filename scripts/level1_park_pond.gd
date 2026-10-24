extends Node3D
const Data = preload("res://scripts/level_data.gd")
const Props = preload("res://scripts/level1_park_props.gd")
const SEGMENTS := 96
var radii := PackedFloat32Array()
var outline := PackedVector2Array()
var shore := PackedVector2Array()

static func center() -> Vector3:
    return Data.cell_center_world(Data.MOON_CENTER)+Vector3.UP*.035

func build(host) -> void:
    position=center()
    shore=_collision_outline()
    outline=Geometry2D.offset_polygon(shore,-0.42,Geometry2D.JOIN_ROUND)[0]
    # Clip a gentle oval to the exact safe shore: smooth water without the
    # one-cell rectangular fingers of the collision grid.
    var oval := PackedVector2Array()
    for i in range(64):
        var angle := float(i)*TAU/64.0
        oval.append(Vector2(cos(angle)*6.05,sin(angle)*5.05).rotated(PI*0.25))
    outline=Geometry2D.intersect_polygons(outline,oval)[0]
    for i in range(SEGMENTS):
        var angle := float(i)*TAU/SEGMENTS
        var direction := Vector2(cos(angle),sin(angle))
        var radius := 0.0
        for j in range(outline.size()):
            var hit: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO,direction*9.0,outline[j],outline[(j+1)%outline.size()])
            if hit!=null: radius=maxf(radius,hit.length())
        radii.append(radius)
    var water := MeshInstance3D.new()
    water.name="WaterSurface"
    water.mesh=_surface_mesh(false)
    var material := ShaderMaterial.new()
    material.shader=preload("res://shaders/level1_park_water.gdshader")
    material.set_shader_parameter("panorama",preload("res://assets/night_sky_milky_way_4k.png"))
    var lamp_cells := Props.LAMPS.duplicate()
    lamp_cells.sort_custom(func(a,b): return Data.cell_center_world(a).distance_squared_to(position)<Data.cell_center_world(b).distance_squared_to(position))
    var reflections := PackedVector3Array()
    for i in range(4): reflections.append(Data.cell_center_world(lamp_cells[i])+Vector3.UP*3.4)
    material.set_shader_parameter("lantern_positions",reflections)
    water.material_override=material
    water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(water)
    var bank := MeshInstance3D.new()
    bank.name="NaturalShore"
    bank.mesh=_surface_mesh(true)
    var bank_material := ShaderMaterial.new()
    bank_material.shader=preload("res://shaders/level1_pond_shore.gdshader")
    bank_material.set_shader_parameter("ground_tex",host.GROUND_TEXTURE)
    bank.material_override=bank_material
    bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bank)
    var rng := RandomNumberGenerator.new()
    rng.seed=31102026
    host.meshes["reed_blade"]=_reed_mesh()
    var reed_material := ShaderMaterial.new()
    reed_material.shader=preload("res://shaders/level1_reed.gdshader")
    host.materials["reed"]=reed_material
    host.meshes["lily"]=_lily_mesh()
    host.materials["lily"]=host._material(Color(0.15,0.31,0.19))
    for i in range(SEGMENTS):
        var angle := float(i)*TAU/SEGMENTS
        var direction := Vector3(cos(angle),0,sin(angle))
        var p := position+direction*(radii[i]+0.32)
        if i%2==0:
            host._batch("ball","stone_dark",p+Vector3.UP*rng.randf_range(0.10,0.17),Vector3(rng.randf_range(0.48,0.88),rng.randf_range(0.27,0.43),rng.randf_range(0.45,0.80)),Basis(Vector3.UP,angle))
        if i%3!=0 or (direction.x>0.05 and direction.z>0.25 and i%4!=0): continue
        for j in range(3):
            var reed := p+Vector3(rng.randf_range(-0.2,0.2),0,rng.randf_range(-0.2,0.2))
            var h := rng.randf_range(0.8,1.45)
            host._batch("cylinder","leaf",reed+Vector3.UP*h*0.5,Vector3(0.018,h,0.018))
            host._batch("trunk","bark",reed+Vector3.UP*(h-0.06),Vector3(0.065,0.24,0.065))
            for side: float in [-1.0,1.0]:
                host._batch("reed_blade","reed",reed,Vector3(side,h*0.78,1),Basis(Vector3.UP,rng.randf()*TAU))
    for i in range(17):
        var angle := rng.randf()*TAU
        var radius := rng.randf_range(1.8,3.8)
        var p := position+Vector3(cos(angle)*radius,0.015,sin(angle)*radius)
        var scale_ := rng.randf_range(0.23,0.43)
        host._batch("lily","lily",p,Vector3(scale_,1,scale_),Basis(Vector3.UP,angle))
        if i%4==0: host._batch("ball","moon",p+Vector3.UP*0.04,Vector3(0.075,0.04,0.075))

func _surface_mesh(bank: bool) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    if bank:
        for i in range(outline.size()):
            var a := outline[i]
            var b := outline[(i+1)%outline.size()]
            var oa := _closest_edge(a,shore)
            var ob := _closest_edge(b,shore)
            for vertex in [[a,0.0],[oa,1.0],[b,0.0],[b,0.0],[oa,1.0],[ob,1.0]]:
                _add_water_vertex(st,vertex[0],vertex[1],true)
    else:
        var triangles := Geometry2D.triangulate_polygon(outline)
        for i in range(0,triangles.size(),3):
            var a := outline[triangles[i]]
            var b := outline[triangles[i+1]]
            var c := outline[triangles[i+2]]
            _add_water_triangle(st,a,b,c,2)
    return st.commit()

func _add_water_triangle(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, depth: int) -> void:
    if depth>0:
        var ab := (a+b)*0.5
        var bc := (b+c)*0.5
        var ca := (c+a)*0.5
        _add_water_triangle(st,a,ab,ca,depth-1)
        _add_water_triangle(st,ab,b,bc,depth-1)
        _add_water_triangle(st,ca,bc,c,depth-1)
        _add_water_triangle(st,ab,bc,ca,depth-1)
        return
    for vertex in [a,b,c]:
        _add_water_vertex(st,vertex,clampf(vertex.distance_to(_closest_edge(vertex,outline))/1.2,0.0,1.0),false)

func _add_water_vertex(st: SurfaceTool, p: Vector2, color_: float, bank: bool) -> void:
    st.set_normal(Vector3.UP)
    st.set_uv(p*0.2)
    st.set_color(Color(color_,0,0,1))
    st.add_vertex(Vector3(p.x,lerpf(0.025,-position.y+0.003,color_) if bank else 0.0,p.y))

func _closest_edge(p: Vector2, polygon: PackedVector2Array) -> Vector2:
    var closest := polygon[0]
    var distance_ := INF
    for i in range(polygon.size()):
        var q := Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])
        var d := p.distance_squared_to(q)
        if d<distance_:
            distance_=d
            closest=q
    return closest

func _collision_outline() -> PackedVector2Array:
    var edges: Dictionary = {}
    var sides := [[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.UP],[Vector2i.RIGHT,Vector2i.ONE,Vector2i.RIGHT],[Vector2i.ONE,Vector2i.DOWN,Vector2i.DOWN],[Vector2i.DOWN,Vector2i.ZERO,Vector2i.LEFT]]
    for z in range(Data.MAP_HEIGHT):
        for x in range(Data.MAP_WIDTH):
            var cell := Vector2i(x,z)
            if not Data.is_pond(cell): continue
            for side in sides:
                if not Data.is_pond(cell+side[2]): edges[cell+side[0]]=cell+side[1]
    var points := PackedVector2Array()
    var first: Vector2i = edges.keys()[0]
    var current := first
    for i in range(edges.size()):
        points.append(Data.MAP_WORLD_ORIGIN+(Vector2(current)-Vector2.ONE*0.5)*Data.CELL_SIZE-Vector2(position.x,position.z))
        current=edges[current]
        if current==first: break
    if Geometry2D.is_polygon_clockwise(points): points.reverse()
    return points

func _reed_mesh() -> ArrayMesh:
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-0.025,0,0),Vector3(0.025,0,0),Vector3(0.15,0.55,0),Vector3(0.35,0.93,0)])
    arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD])
    arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,0.55),Vector2(0.5,1)])
    arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return mesh

func _lily_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(26):
        var a := 0.17+float(i)*(TAU-0.34)/26.0
        var b := 0.17+float(i+1)*(TAU-0.34)/26.0
        for p in [Vector3.ZERO,Vector3(cos(a),0,sin(a)),Vector3(cos(b),0,sin(b))]:
            st.set_normal(Vector3.UP)
            st.add_vertex(p)
    return st.commit()
