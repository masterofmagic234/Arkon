extends RefCounted
# Only the outside of the rendered wall shell enters the renderer. Internal
# shared cube faces are not drawn. World-space masonry keeps a metre scale
# across corners and differently sized chunks; physics still comes from Data.
const Data=preload("res://scripts/level_data.gd")
const CHUNK_METRES := 24.0
var surfaces: Dictionary={}
var cells: Dictionary={}
var face_count := 0
var cell_count := 0

func add_cell(cell: Vector2i) -> void:
    cells[cell]=true;cell_count+=1

func _build_cell(cell: Vector2i) -> void:
    var p:=Data.cell_center_world(cell)
    var key:=Vector2i(floori(p.x/CHUNK_METRES),floori(p.z/CHUNK_METRES))
    if not surfaces.has(key):
        var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[key]=st
    var st: SurfaceTool=surfaces[key]
    for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
        var next: Vector2i=cell+side
        # Close the shell on its forest/water side as well: the player can
        # look at the back of a narrow wall across the lake or a bend.
        if cells.has(next):continue
        var normal:=Vector3(side.x,0,side.y)
        var tangent:=Vector3.UP.cross(normal)*.9
        var edge:=p+normal*.9
        _quad(st,[edge-tangent,edge+tangent,edge+tangent+Vector3.UP*(Data.PARK_WALL_HEIGHT-.14),edge-tangent+Vector3.UP*(Data.PARK_WALL_HEIGHT-.14)],normal,Color(1,1,1,0))
        # Narrow coping has actual geometry, a darker bed and a quiet pale lip.
        _quad(st,[edge-tangent+Vector3.UP*(Data.PARK_WALL_HEIGHT-.14),edge+tangent+Vector3.UP*(Data.PARK_WALL_HEIGHT-.14),edge+tangent+Vector3.UP*Data.PARK_WALL_HEIGHT,edge-tangent+Vector3.UP*Data.PARK_WALL_HEIGHT],normal,Color(.85,.87,.84))
        face_count+=1
    _quad(st,[p+Vector3(-.9,Data.PARK_WALL_HEIGHT,-.9),p+Vector3(-.9,Data.PARK_WALL_HEIGHT,.9),p+Vector3(.9,Data.PARK_WALL_HEIGHT,.9),p+Vector3(.9,Data.PARK_WALL_HEIGHT,-.9)],Vector3.UP,Color(.84,.86,.82))

func _quad(st: SurfaceTool,points: Array,normal: Vector3,color: Color) -> void:
    # Godot's front face is clockwise, opposite the geometric cross product.
    for i in [0,2,1,0,3,2]:
        st.set_normal(normal);st.set_color(color);st.set_uv(Vector2.ZERO);st.add_vertex(points[i])

func finish(parent: Node3D,material: Material) -> void:
    for cell in cells:_build_cell(cell)
    var root:=Node3D.new();root.name="EstateBoundaryWalls";parent.add_child(root)
    for key in surfaces:
        var st: SurfaceTool=surfaces[key];st.index()
        var mesh:=MeshInstance3D.new();mesh.name="Masonry_%s_%s"%[key.x,key.y]
        mesh.mesh=st.commit();mesh.material_override=material
        mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mesh.visibility_range_end=114.0;root.add_child(mesh)
    root.set_meta("wall_cells",cell_count);root.set_meta("exposed_faces",face_count)
    surfaces.clear()
