extends RefCounted
## Closed stairs, a traversable bank behind the rocks, and a real park entrance.
## Layout152 owns paths, landing footprints and replacement receiver policy.
## TERRAIN_TILES retains the five offline151 assets; nine playable tiles now
## render their full physical triangles and sample the retained probe volume.
const TERRAIN_TILES := [7,11,12,13,17]
const CUT_PATHS := [1,2,5]
const FLIGHTS := preload("res://scripts/botanical_layout.gd").STAIR_FLIGHTS
const ENTRY_HALF_WIDTH := 6.0
const ENTRY_STREET_Z := 94.0
const LOWER_LANDING_FRONT := 2.0

static func stair_footprint(flight: Array) -> Rect2:
    return preload("res://scripts/botanical_layout.gd").stair_footprint(flight)

static func clip_path_triangle(points: PackedVector3Array) -> PackedVector3Array:
    # Remove the sloping path ribbon where real stone treads and their upper
    # landing already supply the surface. Cutting triangle polygons preserves
    # each visible path edge exactly; dropping whole triangles leaves holes.
    var original:=PackedVector2Array()
    for p in points:original.append(Vector2(p.x,p.z))
    var polygons: Array[PackedVector2Array]=[original]
    var clipped:=false
    for flight in FLIGHTS:
        var footprint:=stair_footprint(flight)
        var remaining: Array[PackedVector2Array]=[]
        for polygon in polygons:
            var bounds:=Rect2(polygon[0],Vector2.ZERO)
            for p in polygon:bounds=bounds.expand(p)
            if not bounds.intersects(footprint):remaining.append(polygon);continue
            var edge:=PackedVector2Array([footprint.position,footprint.position+Vector2(footprint.size.x,0),footprint.end,footprint.position+Vector2(0,footprint.size.y)])
            remaining.append_array(Geometry2D.clip_polygons(polygon,edge));clipped=true
        polygons=remaining
    if not clipped:return points
    var result:=PackedVector3Array()
    var ab:=original[1]-original[0];var ac:=original[2]-original[0]
    var determinant:=ab.cross(ac)
    if absf(determinant)<.00000001:return result
    for polygon in polygons:
        var indices:=Geometry2D.triangulate_polygon(polygon)
        for i in range(0,indices.size(),3):
            var triangle:=PackedVector3Array()
            for j in range(3):
                var p: Vector2=polygon[indices[i+j]];var relative:=p-original[0]
                var u:=relative.cross(ac)/determinant;var v:=ab.cross(relative)/determinant
                triangle.append(Vector3(p.x,points[0].y+u*(points[1].y-points[0].y)+v*(points[2].y-points[0].y),p.y))
            if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y<0:
                var swap:=triangle[1];triangle[1]=triangle[2];triangle[2]=swap
            result.append_array(triangle)
    return result

static func terrain_height(x: float,z: float,original: float) -> float:
    var y:=original
    # The former rock/wall pocket is filled by a visible45° earth bank and
    # level rear shelf. The planted beds at z−5 stay on the lower terrace.
    if absf(x)>=10.0 and absf(x)<=58.0 and z<=-8.0 and z>=-14.0:
        y=maxf(y,3.0+4.0*clampf((-8.0-z)/4.0,0.0,1.0))
    for flight in FLIGHTS:
        var a: Vector3=flight[0];var b: Vector3=flight[1]
        if absf(x-a.x)<=float(flight[2])*.5+.05 and z<=a.z+.65 and z>=b.z-.65:
            # Ground stays below the underside of every original stone tread.
            y-=.45
            break
    return y

static func build(world: Node3D) -> void:
    var root:=Node3D.new();root.name="GardenCirculation151";world.add_child(root)
    for index in range(FLIGHTS.size()):
        var flight=FLIGHTS[index]
        var a: Vector3=flight[0];var b: Vector3=flight[1]
        var width: float=flight[2];var count: int=flight[3]
        var step_depth:=absf(a.z-b.z)/count
        var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var landings:=SurfaceTool.new();landings.begin(Mesh.PRIMITIVE_TRIANGLES)
        var base:=a.y-.65
        for i in range(count):
            var p:=a.lerp(b,float(i+1)/count)
            var top:=p.y-.15 # Meets the bottom of the unchanged .16m tread.
            _append_box(st,Vector3(p.x,(base+top)*.5,p.z),Vector3(width,top-base,step_depth))
        # The two-metre terrain grid interpolates a lowered edge vertex out to
        # its next row. Cover that entire seam with visible stone, including
        # for navigation's floor samples that do not bridge narrow depressions.
        _append_box(landings,Vector3(a.x,(base+a.y+.01)*.5,a.z+.65),Vector3(width+4.0,a.y+.01-base,2.7))
        # Lowering the terrain under the treads also cuts the final terrain
        # triangle at each crest. A real upper landing bridges that cut so
        # descending does not require a >20cm climb onto the highest tread.
        # Start beyond the final tread, not at its centre. The old landing
        # covered half of that tread at exactly the same height (z-fighting).
        var landing_front:=b.z-step_depth*.5
        var landing_back:=b.z-2.0
        _append_box(landings,Vector3(b.x,b.y-.32,(landing_front+landing_back)*.5),Vector3(width+4.0,.66,landing_front-landing_back))
        var foundation:=_mesh(root,st,world.mats.trim,"ClosedStairFoundation151_%d"%index)
        # Landings are the paving forecourt, not a bright limestone sticker.
        # Keep the same closed boxes/physical mesh, with their own material
        # surface so world mapping, probe light and fast-profile tone match.
        var combined:=foundation.mesh as ArrayMesh
        landings.index();landings.commit(combined)
        combined.surface_set_material(0,world.mats.trim)
        combined.surface_set_material(1,world.mats.paving)
        foundation.material_override=null
    var escapes:=SurfaceTool.new();escapes.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1.0,1.0]:
        # Real short steps cross the two outlook pads interrupting the shelf.
        for edge in [27.0,39.0]:
            for i in range(4):
                var x: float=edge+(-1.0 if edge<30 else 1.0)*(1.75-float(i)*.5)
                var top:=6.96+float(i)*.18
                _append_box(escapes,Vector3(side*x,(6.65+top)*.5,-11.8),Vector3(.55,top-6.65,1.8))
        # The existing top rail starts at x±12. The narrow service steps use
        # the clear gap between that rail and the main stair's shoulder.
        _append_box(escapes,Vector3(side*11.35,6.89,-12.55),Vector3(1.2,.18,.4))
        _append_box(escapes,Vector3(side*11.35,7.00,-13.10),Vector3(1.2,.24,.8))
    _mesh(root,escapes,world.mats.trim,"RockBankEscapeSteps151")
    _entry(world,root)
    world.set_meta("world151_circulation",{
        "terrain_tiles":TERRAIN_TILES,"closed_flights":FLIGHTS.size(),
        "bank":Rect2(-58,-14,116,6),"bank_max_slope_degrees":45,
        "entry_gap_half_width":ENTRY_HALF_WIDTH,"street_z":ENTRY_STREET_Z,
        "physics_policy":"Visible closed stairs and an earth-bank escape. No per-frame position recovery.",
    })

static func _entry(world: Node3D,root: Node3D) -> void:
    var entry:=Node3D.new();entry.name="ParkVehicleEntrance151";root.add_child(entry)
    var asphalt:=StandardMaterial3D.new();asphalt.albedo_color=Color("535b60");asphalt.roughness=.96
    asphalt.albedo_texture=preload("res://assets/level2/asphalt_aggregate.png")
    asphalt.uv1_triplanar=true;asphalt.uv1_world_triplanar=true;asphalt.uv1_scale=Vector3.ONE*.35
    var markings:=StandardMaterial3D.new();markings.albedo_color=Color("c9cbbb");markings.roughness=.95
    var metal:=StandardMaterial3D.new();metal.albedo_color=Color("28343c");metal.metallic=.35;metal.roughness=.8
    # The turning court behind the parked240 joins an actual outside road.
    # It starts where the old entrance path ends, without coplanar overlap.
    _physical_box(entry,Vector3(0,-.10,75),Vector3(12,.27,14),world.mats.paving,"EntranceTurningCourt151")
    _physical_box(entry,Vector3(0,-.10,86),Vector3(10,.27,8),asphalt,"EntranceDrive151")
    _physical_box(entry,Vector3(0,-.10,ENTRY_STREET_Z),Vector3(196,.27,8),asphalt,"OutsideStreet151")
    for x in range(-94,95,8):_box(entry,Vector3(x,.039,ENTRY_STREET_Z),Vector3(3,.012,.12),markings,"StreetCentreLine151")
    for side in [-1.0,1.0]:
        _physical_box(entry,Vector3(side*6.1,1.4,77),Vector3(.85,2.8,.85),world.mats.trim,"EntranceGatePillar151")
        _box(entry,Vector3(side*6.1,2.88,77),Vector3(1.05,.16,1.05),world.mats.trim,"EntranceGateCap151")
        # Open leaves sit alongside the drive rather than blocking it.
        for z in [78.1,79.2,80.3,81.4]:_physical_box(entry,Vector3(side*6.1,1.15,z),Vector3(.065,1.9,.065),metal,"OpenEntranceGateBar151")
        for y in [.55,1.8]:_physical_box(entry,Vector3(side*6.1,y,79.7),Vector3(.075,.07,4.8),metal,"OpenEntranceGateRail151")
        # Visible verges bound the playable approach beside the open gateway.
        for z in [82.0,85.0,88.0]:_physical_box(entry,Vector3(side*8.0,1.0,z),Vector3(.14,2.0,.14),metal,"EntranceVergePost151")
        for y in [.65,1.55]:_physical_box(entry,Vector3(side*8.0,y,85),Vector3(.08,.08,8),metal,"EntranceVergeRail151")
        _physical_box(entry,Vector3(side*8.5,2,84.5),Vector3(1,6,11),null,"EntranceVergeBoundary151")
    # Verge rails end before the junction, leaving both driving turns clear.
    _physical_box(entry,Vector3(0,2,99),Vector3(180,6,2),null,"EntranceFarBoundary151")
    for x in range(-84,85,8):_physical_box(entry,Vector3(x,.6,98.6),Vector3(.12,1.2,.12),metal,"OutsideStreetFencePost151")
    for y in [.45,.95]:_physical_box(entry,Vector3(0,y,98.6),Vector3(176,.065,.065),metal,"OutsideStreetFenceRail151")
    _batch_entry_visuals(entry)

static func _batch_entry_visuals(root: Node3D) -> void:
    # Road markings, rails and posts share only five material draws. Their
    # simple physical boxes remain independent of rendering and culling.
    var groups: Dictionary={}
    for node in root.get_children():
        if not node is MeshInstance3D:continue
        var mat: Material=node.material_override
        if not groups.has(mat):
            var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);groups[mat]=st
        groups[mat].append_from(node.mesh,0,node.transform)
        node.free()
    var index:=0
    for mat in groups:
        var node:=_mesh(root,groups[mat],mat,"VehicleEntranceSurface151_%d"%index)
        node.set_meta("already_physical151",true);index+=1

static func _append_box(st: SurfaceTool,at: Vector3,size: Vector3) -> void:
    var box:=BoxMesh.new();box.size=size;st.append_from(box,0,Transform3D(Basis.IDENTITY,at))

static func _mesh(root: Node3D,st: SurfaceTool,mat: Material,label: String) -> MeshInstance3D:
    st.index()
    var node:=MeshInstance3D.new();node.name=label;node.mesh=st.commit();node.material_override=mat
    node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("mission151_world",true);root.add_child(node);return node

static func _box(root: Node3D,at: Vector3,size: Vector3,mat: Material,label: String) -> MeshInstance3D:
    var node:=MeshInstance3D.new();node.name=label;var mesh:=BoxMesh.new();mesh.size=size
    node.mesh=mesh;node.position=at;node.material_override=mat
    node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("already_physical151",true);node.set_meta("mission151_world",true)
    root.add_child(node);return node

static func _physical_box(root: Node3D,at: Vector3,size: Vector3,mat: Material,label: String) -> void:
    if mat!=null:_box(root,at,size,mat,label)
    var body:=StaticBody3D.new();body.name=label+"Collision";body.position=at;body.collision_layer=1
    body.set_meta("audio_surface",&"stone")
    var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape
    body.add_child(collision);root.add_child(body)
