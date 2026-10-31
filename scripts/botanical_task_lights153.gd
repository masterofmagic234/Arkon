extends RefCounted
## Static, batched wayfinding: two inexpensive meshes, no new Light3D/pass.
const CYAN := Color("59d6cc")
const VIOLET := Color("af8bc9")
const TASKS := [
    [Vector3(28,3,11), "fuse"], [Vector3(23,3,19), "pump"],
    [Vector3(4.1,7,-20.4), "gate"], [Vector3(0,7,-36), "acorns"],
]
static func apply(world: Node3D) -> void:
    var root := Node3D.new();root.name="StaticNeonWayfinding153";world.add_child(root)
    var cores := SurfaceTool.new();cores.begin(Mesh.PRIMITIVE_TRIANGLES)
    var pools := SurfaceTool.new();pools.begin(Mesh.PRIMITIVE_TRIANGLES)
    var layout=preload("res://scripts/botanical_layout.gd")
    var sites: Array=[]
    for p in layout.LAMP_POSTS:sites.append([p,2.86,CYAN])
    for index in range(layout.EVENING_LAMPS.size()):
        sites.append([layout.EVENING_LAMPS[index],3.43,CYAN if index%2==0 else VIOLET])
    for site in sites:
        var p: Vector2=site[0];var y: float=world.surface_height_at(p.x,p.y)
        var center:=Vector3(p.x,y+float(site[1]),p.y)
        # Narrow inset panels on four faces: a dark housing, not a solid
        # glowing yellow/cyan box. All strips share this single mesh.
        for side in [-1,1]:
            _cube(cores,center+Vector3(side*.234,0,0),Vector3(.014,.36,.13),site[2])
            _cube(cores,center+Vector3(0,0,side*.234),Vector3(.13,.36,.014),site[2])
        _cube(cores,center+Vector3(0,.31,0),Vector3(.52,.06,.52),Color("26343e"))
        _pool(pools,world,p,3.8,Color(site[2],.23))
    for task in TASKS:
        var point: Vector3=task[0];var color:=CYAN
        # Three slender fins are a visible beacon, not a collision obstacle.
        for side in [-1,0,1]:
            _cube(cores,point+Vector3(.62+side*.09,1.25,0),Vector3(.035,.45-abs(side)*.12,.035),color)
        _pool(pools,world,Vector2(point.x,point.z),2.3,Color(color,.31))
    # Low road bollards guide the calm approach without adding headlights.
    for point in [Vector2(-6.5,92),Vector2(6,79)]:
        var y: float=world.surface_height_at(point.x,point.y)
        _cube(cores,Vector3(point.x,y+.45,point.y),Vector3(.12,.9,.12),Color("263c43"))
        _cube(cores,Vector3(point.x,y+.92,point.y),Vector3(.19,.18,.19),CYAN)
        _pool(pools,world,point,4.6,Color(CYAN,.25))
    var emissive:=StandardMaterial3D.new();emissive.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;emissive.vertex_color_use_as_albedo=true
    var glow:=ShaderMaterial.new();glow.shader=preload("res://shaders/woodland/task_light153.gdshader")
    for spec in [[cores,emissive,"NeonCores"],[pools,glow,"StaticLightPools"]]:
        var node:=MeshInstance3D.new();node.name=spec[2];node.mesh=spec[0].commit();node.material_override=spec[1];node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.set_meta("cosmetic_task_light153",true);root.add_child(node)
    root.set_meta("realtime_lights",0);root.set_meta("shadow_maps",0);root.set_meta("task_beacons",TASKS.size());root.set_meta("lamp_cores",sites.size());root.set_meta("road_bollards",2)

static func _pool(st: SurfaceTool,world: Node3D,center: Vector2,radius: float,color: Color) -> void:
    # Sample the authoritative physical support, avoiding a flat sheet cutting
    # through stairs. Tiny separation prevents a second coplanar floor surface.
    const STEPS=12
    for x in range(STEPS):
        for z in range(STEPS):
            var points: Array[Vector2]=[]
            for q in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z+1)]:
                points.append(center+(q/float(STEPS)*2.0-Vector2.ONE)*radius)
            var heights: Array[float]=[]
            var crosses_stairs:=false
            for p in points:
                for flight in preload("res://scripts/botanical_layout.gd").STAIR_FLIGHTS:
                    if preload("res://scripts/botanical_layout.gd").stair_footprint(flight).has_point(p):crosses_stairs=true
                heights.append(_visible_floor(world,p)+.012)
            if crosses_stairs:continue
            # Never bridge a vertical stair riser, canal or retaining edge.
            if heights.max()-heights.min()>.24:continue
            for i in [0,1,2,1,3,2]:
                st.set_color(color);st.set_uv((points[i]-center)/radius*.5+Vector2(.5,.5));st.add_vertex(Vector3(points[i].x,heights[i],points[i].y))

static func _visible_floor(world: Node3D,p: Vector2) -> float:
    var terrain: float=world.surface_height_at(p.x,p.y)
    # The greenhouse disc, actual cut paving polygons and road sit above the
    # soil. Light must lie on the visible receiver, not underneath its texture.
    if p.distance_to(Vector2(0,-35))<12.5:return maxf(terrain,7.26)
    if absf(p.x)<98 and p.y>=90 and p.y<=98:return maxf(terrain,.035)
    if absf(p.x)<5 and p.y>=82 and p.y<=90:return maxf(terrain,.035)
    if preload("res://scripts/botanical_layout.gd").VEHICLE_COURT.has_point(p):return maxf(terrain,.035)
    for polygon in world.paving_coverage152:
        if Geometry2D.is_point_in_polygon(p,polygon):return terrain+.035
    return terrain

static func _cube(st: SurfaceTool,p: Vector3,size_: Vector3,color: Color) -> void:
    var mesh:=BoxMesh.new();mesh.size=size_
    var arrays=mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    for i in indices:st.set_color(color);st.add_vertex(p+vertices[i])
