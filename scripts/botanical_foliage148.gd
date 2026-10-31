extends RefCounted
## Spatial, immutable foliage. Near silhouettes retain the authored atlas;
## opaque branch lobes and whole crowns replace overlapping cards at distance.
const CELL := 16.0
const NEAR_END := 44.0
const MID_END := 94.0
const FAR_END := 176.0
class Chunk:
    var node: GeometryInstance3D
    var bounds: AABB
    var kind := ""
    var count := 0
    var triangles := 0
    var level := 0
    var near: GeometryInstance3D
    var middle: GeometryInstance3D
    var far: GeometryInstance3D
    var center := Vector3.ZERO
    var transforms: Array[Transform3D] = []
    var root_distances := PackedVector3Array()
var world: Node3D
var root: Node3D
var nodes: Array[GeometryInstance3D] = []
var chunks: Array[Chunk] = []
var herb_chunks: Array[Chunk] = []
var construction_upload_bytes := 0
var construction_upload_count := 0
var near_card_count := 0
var lobe_count := 0
var far_crown_count := 0
var herb_count := 0
var _hulls: Dictionary = {}
var _atlas_image: Image
var _last_eye := Vector3(INF,INF,INF)
var _active := true
var _distance_culling_enabled := true
var _detail_material: ShaderMaterial
var _ivy_material: ShaderMaterial
var _middle_material: ShaderMaterial
var _far_material: ShaderMaterial
var _near_builders: Dictionary = {}
var _middle_builders: Dictionary = {}
var _far_builders: Dictionary = {}
var _herb_builders: Dictionary = {}
var quality: Dictionary = quality_settings("high")

static func quality_settings(profile: String, dynamic_step: int = 0) -> Dictionary:
    # Only cosmetic density and render distances change. Far opaque crowns
    # retain the skyline; all authored transforms and immutable buffers survive.
    var settings: Dictionary
    match profile:
        "low":
            settings={"detail":Vector2(12,22),"detail_end":28.0,"ivy":Vector2(24,36),"ivy_end":44.0,"middle_grow":Vector2(10,18),"middle_shrink":Vector2(40,56),"middle_end":64.0,"far_grow":Vector2(40,50),"far_shrink":Vector2(148,170),"far_end":176.0,"herb_near":10.0,"herb_middle":22.0,"herb_end":42.0,"herb_fade":Vector2(28,38)}
        "balanced":
            settings={"detail":Vector2(18,29),"detail_end":36.0,"ivy":Vector2(30,44),"ivy_end":52.0,"middle_grow":Vector2(14,24),"middle_shrink":Vector2(54,72),"middle_end":80.0,"far_grow":Vector2(52,66),"far_shrink":Vector2(148,170),"far_end":176.0,"herb_near":14.0,"herb_middle":30.0,"herb_end":58.0,"herb_fade":Vector2(36,50)}
        _:
            settings={"detail":Vector2(23,36),"detail_end":NEAR_END,"ivy":Vector2(40,56),"ivy_end":64.0,"middle_grow":Vector2(18,29),"middle_shrink":Vector2(65,86),"middle_end":MID_END,"far_grow":Vector2(64,80),"far_shrink":Vector2(148,170),"far_end":FAR_END,"herb_near":17.0,"herb_middle":36.0,"herb_end":74.0,"herb_fade":Vector2(48,64)}
    var density_scale: float=1.0-float(clampi(dynamic_step,0,2))*.15
    for key in ["herb_near","herb_middle","herb_end"]:settings[key]=float(settings[key])*density_scale
    settings.herb_fade*=density_scale
    settings["profile"]=profile;settings["dynamic_step"]=clampi(dynamic_step,0,2)
    return settings

func apply_quality(settings: Dictionary) -> void:
    quality=quality_settings(String(settings.get("profile","high")),int(settings.get("dynamic_step",0)))
    if _detail_material==null:return
    for entry in [[_detail_material,quality.detail],[_ivy_material,quality.ivy]]:
        entry[0].set_shader_parameter("detail_fade_begin",entry[1].x)
        entry[0].set_shader_parameter("detail_fade_end",entry[1].y)
    for entry in [[_middle_material,quality.middle_grow,quality.middle_shrink],[_far_material,quality.far_grow,quality.far_shrink]]:
        entry[0].set_shader_parameter("grow_begin",entry[1].x);entry[0].set_shader_parameter("grow_end",entry[1].y)
        entry[0].set_shader_parameter("shrink_begin",entry[2].x);entry[0].set_shader_parameter("shrink_end",entry[2].y)
    for chunk: Chunk in chunks:
        var end: float=quality.detail_end if chunk.kind=="canopy_detail" else (quality.ivy_end if chunk.kind=="climbing_detail" else (quality.middle_end if chunk.kind=="branch_lobes" else quality.far_end))
        _set_quality_range(chunk.node,end)
    for chunk: Chunk in herb_chunks:
        for node in [chunk.near,chunk.middle,chunk.far]:_set_quality_range(node,float(quality.herb_end))
    _last_eye=Vector3(INF,INF,INF)

func _set_quality_range(node: GeometryInstance3D,end: float) -> void:
    node.set_meta("performance_visibility_end",end)
    node.visibility_range_end=end if _distance_culling_enabled else 0.0

func setup(owner_: Node3D, sources: Array) -> void:
    world=owner_
    root=Node3D.new();root.name="MobileFoliage148";world.add_child(root)
    var atlas: Texture2D=preload("res://assets/level1/botanical/foliage_color_gl.png") if RenderingServer.get_current_rendering_method()=="gl_compatibility" else world.ATLAS
    _atlas_image=world.ATLAS.get_image()
    if _atlas_image.is_compressed():_atlas_image.decompress()
    _detail_material=_card_material(atlas,23.0,36.0)
    _ivy_material=_card_material(atlas,40.0,56.0)
    _middle_material=_volume_material(atlas,18.0,29.0,65.0,86.0)
    _far_material=_volume_material(atlas,64.0,80.0,148.0,170.0)
    _make_canopies()
    for record in sources:
        var source: MultiMeshInstance3D=record.instance
        if bool(source.get_meta("botanical_cutout",false)):
            if bool(source.get_meta("tree_canopy",false)):continue
            var mesh_key=String(source.get_meta("lightmap_source_id","")).trim_prefix("batch:").get_slice("|",0)
            var cell=int(mesh_key.trim_prefix("leaf"))
            for i in range(source.multimesh.instance_count):
                _add_card(source.global_transform*source.multimesh.get_instance_transform(i),cell,false)
        else:
            _make_herbs(source)
    _finish_cards()
    _finish_volumes(_middle_builders,false)
    _finish_volumes(_far_builders,true)
    _finish_herbs()
    _near_builders.clear();_middle_builders.clear();_far_builders.clear();_herb_builders.clear()
    _atlas_image=null

func _card_material(atlas: Texture2D,start: float,end: float) -> ShaderMaterial:
    var material=ShaderMaterial.new();material.shader=preload("res://shaders/woodland/garden_foliage148.gdshader")
    material.set_shader_parameter("atlas",atlas)
    material.set_shader_parameter("detail_fade_begin",start);material.set_shader_parameter("detail_fade_end",end)
    return material

func _volume_material(atlas: Texture2D,grow_begin: float,grow_end: float,shrink_begin: float,shrink_end: float) -> ShaderMaterial:
    var material=ShaderMaterial.new();material.shader=preload("res://shaders/woodland/garden_canopy148.gdshader")
    material.set_shader_parameter("atlas",atlas)
    material.set_shader_parameter("grow_begin",grow_begin);material.set_shader_parameter("grow_end",grow_end)
    material.set_shader_parameter("shrink_begin",shrink_begin);material.set_shader_parameter("shrink_end",shrink_end)
    return material

func _cell(point: Vector3) -> Vector2i:return Vector2i(floori(point.x/CELL),floori(point.z/CELL))

func _make_canopies() -> void:
    var trees: Dictionary={}
    for group: Dictionary in world.canopy_groups:
        var bounds: AABB=group.bounds
        var point: Vector3=group.root
        var key=String(group.kind)+str(point.snapped(Vector3.ONE*.001))
        if not trees.has(key):trees[key]={"bounds":bounds,"root":point,"kind":String(group.kind)}
        else:trees[key].bounds=trees[key].bounds.merge(bounds)
        for transform_: Transform3D in group.card_transforms:_add_card(transform_,0,true)
        if String(group.kind)!="cypress":
            var b=bounds.size*Vector3(.89,.90,.89)
            var transform_=Transform3D(Basis.from_scale(b),bounds.get_center())
            _append_volume(_middle_builders,_cell(point),transform_)
            lobe_count+=1
    for tree in trees.values():
        var bounds: AABB=tree.bounds
        var point: Vector3=tree.root
        var scale_=Vector3(.88,.91,.88)
        var transform_=Transform3D(Basis.from_scale(bounds.size*scale_),bounds.get_center())
        _append_volume(_far_builders,_cell(point),transform_)
        far_crown_count+=1
        if String(tree.kind)=="cypress":
            # Three overlapping rounded sections keep a tapering cypress
            # silhouette. Nine separate ring discs looked like stacked barrels.
            for section in [[-.22,Vector3(.92,.56,.92)],[.06,Vector3(.74,.54,.74)],[.33,Vector3(.46,.38,.46)]]:
                var center=bounds.get_center()+Vector3.UP*bounds.size.y*section[0]
                _append_volume(_middle_builders,_cell(point),Transform3D(Basis.from_scale(bounds.size*section[1]),center))
                lobe_count+=1

func _append_volume(builders: Dictionary,key: Vector2i,transform_: Transform3D) -> void:
    if not builders.has(key):builders[key]=[]
    builders[key].append(transform_)

func _hull(cell: int) -> PackedVector2Array:
    if _hulls.has(cell):return _hulls[cell]
    var points=PackedVector2Array()
    var tile=Vector2i(cell%3,floori(float(cell)/3.0))
    var tile_size=Vector2i(_atlas_image.get_width()/3,_atlas_image.get_height()/2)
    for row in range(1,32):
        for column in range(1,32):
            var uv=Vector2(column,row)/32.0
            var pixel=tile*tile_size+Vector2i(uv*Vector2(tile_size))
            if _atlas_image.get_pixelv(pixel).a>.42:points.append(uv)
    var hull=Geometry2D.convex_hull(points)
    if hull.size()>1 and hull[0].is_equal_approx(hull[-1]):hull.remove_at(hull.size()-1)
    if hull.size()<3:hull=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
    _hulls[cell]=hull
    return hull

func _add_card(transform_: Transform3D,cell: int,canopy: bool) -> void:
    var key=Vector3i(floori(transform_.origin.x/CELL),floori(transform_.origin.z/CELL),1 if canopy else 0)
    if not _near_builders.has(key):
        _near_builders[key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array(),"roots":PackedVector3Array(),"count":0}
    var data: Dictionary=_near_builders[key]
    var points=_hull(cell)
    var triangles=Geometry2D.triangulate_polygon(points)
    var start: int=data.vertices.size()
    var local_center=Vector3(key.x*CELL,0,key.y*CELL)
    var normal=(transform_.basis.inverse().transposed()*Vector3.FORWARD).normalized()
    var tile=Vector2(cell%3,floori(float(cell)/3.0))
    for uv: Vector2 in points:
        data.vertices.append(transform_*Vector3(uv.x-.5,.5-uv.y,0)-local_center)
        data.normals.append(normal)
        data.uv.append((tile+uv*.98+Vector2(.01,.01))/Vector2(3,2))
        data.colors.append(Color.WHITE)
    # The hull is generated in image Y-down coordinates. Reversing only the
    # triangle winding restores the original card's authored face direction.
    for i in range(0,triangles.size(),3):
        data.indices.append_array(PackedInt32Array([start+triangles[i],start+triangles[i+2],start+triangles[i+1]]))
        data.indices.append_array(PackedInt32Array([start+triangles[i],start+triangles[i+1],start+triangles[i+2]]))
    data.count+=1;data.roots.append(transform_.origin);near_card_count+=1

func _finish_cards() -> void:
    for key: Vector3i in _near_builders:
        var data: Dictionary=_near_builders[key]
        var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals
        arrays[Mesh.ARRAY_TEX_UV]=data.uv;arrays[Mesh.ARRAY_COLOR]=data.colors;arrays[Mesh.ARRAY_INDEX]=data.indices
        var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
        var node=MeshInstance3D.new();node.name="CanopyDetail" if key.z==1 else "ClimbingPlants"
        node.mesh=mesh;node.position=Vector3(key.x*CELL,0,key.y*CELL)
        node.material_override=_detail_material if key.z==1 else _ivy_material
        _configure(node,NEAR_END if key.z==1 else 64.0)
        var chunk=Chunk.new();chunk.node=node;chunk.bounds=node.transform*mesh.get_aabb()
        chunk.count=int(data.count);chunk.triangles=data.indices.size()/3
        chunk.kind="canopy_detail" if key.z==1 else "climbing_detail";chunk.root_distances=data.roots
        chunks.append(chunk)

func _lobe_mesh(far: bool) -> ArrayMesh:
    var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
    var rings=4 if far else 5
    var sectors=10 if far else 12
    for ring in range(rings+1):
        var latitude=PI*ring/rings
        for sector in range(sectors+1):
            var longitude=TAU*sector/sectors
            var normal=Vector3(sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude))
            var organic=1.0+.055*sin(longitude*3.0+latitude*2.7)*sin(latitude)
            vertices.append(normal*.5*organic);normals.append(normal)
            # Reuse the oak tile. The opaque surface needs its RGB only;
            # transparent background pixels already carry fixed border colour.
            uv.append(Vector2((.08+.84*float(sector)/sectors)/3.0,(.06+.88*float(ring)/rings)/2.0))
            colors.append(Color(.96,.99,.94))
    for ring in range(rings):
        for sector in range(sectors):
            var a=ring*(sectors+1)+sector;var b=a+1;var c=a+sectors+1;var d=c+1
            if ring>0:indices.append_array(PackedInt32Array([a,c,b]))
            if ring<rings-1:indices.append_array(PackedInt32Array([b,c,d]))
    var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
    var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return mesh

func _finish_volumes(builders: Dictionary,far: bool) -> void:
    var mesh=_lobe_mesh(far)
    for key: Vector2i in builders:
        var transforms: Array=builders[key]
        var node=_multimesh(mesh,transforms,_far_material if far else _middle_material,"DistantCrowns" if far else "CanopyLobes",FAR_END if far else MID_END)
        var chunk=Chunk.new();chunk.node=node;chunk.bounds=node.get_aabb();chunk.kind="far_crown" if far else "branch_lobes"
        chunk.count=transforms.size();chunk.triangles=mesh.surface_get_array_index_len(0)/3*chunk.count
        for transform_: Transform3D in transforms:chunk.root_distances.append(transform_.origin)
        chunks.append(chunk)

func _make_herbs(source: MultiMeshInstance3D) -> void:
    var key=String(source.get_meta("lightmap_source_id","")).trim_prefix("batch:").get_slice("|",0)
    if not key.begins_with("herb") and key!="lilyflower":return
    var kind=6 if key=="lilyflower" else int(key.trim_prefix("herb"))
    for i in range(source.multimesh.instance_count):
        var t=source.global_transform*source.multimesh.get_instance_transform(i)
        # Combine adjacent original batches once. Repartitioning each old batch
        # independently would duplicate small draw objects along its boundaries.
        var cell=Vector3i(kind,floori(t.origin.x/24.0),floori(t.origin.z/24.0))
        if not _herb_builders.has(cell):_herb_builders[cell]={"transforms":[],"fallback_mesh":source.multimesh.mesh,"fallback_material":source.material_override}
        _herb_builders[cell].transforms.append(t)

func _finish_herbs() -> void:
    for cell: Vector3i in _herb_builders:
        var data: Dictionary=_herb_builders[cell]
        var mesh: Mesh=world.performance_herb_meshes.get(cell.x,data.fallback_mesh)
        var original: Array=data.transforms
        var middle: Array=[];var far: Array=[]
        for i in range(original.size()):
            if i%3!=1:middle.append(original[i])
            if i%3==0:far.append(original[i])
        var material: Material=world.performance_herb_material if world.performance_herb_material!=null else data.fallback_material
        var chunk=Chunk.new();chunk.kind="herbs";chunk.count=original.size();chunk.transforms.assign(original)
        chunk.near=_multimesh(mesh,original,material,"HerbsNear",74.0);chunk.near.lod_bias=.7
        chunk.middle=_multimesh(mesh,middle,material,"HerbsMiddle",74.0);chunk.middle.lod_bias=.22;chunk.middle.hide()
        chunk.far=_multimesh(mesh,far,material,"HerbsFar",74.0);chunk.far.lod_bias=.06;chunk.far.hide()
        chunk.node=chunk.near;chunk.bounds=chunk.near.get_aabb();chunk.center=chunk.bounds.get_center();chunk.level=0
        herb_chunks.append(chunk);herb_count+=original.size()

func _multimesh(mesh: Mesh,transforms: Array,material: Material,name_: String,end: float) -> MultiMeshInstance3D:
    var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=transforms.size()
    for i in range(transforms.size()):mm.set_instance_transform(i,transforms[i])
    construction_upload_bytes+=transforms.size()*12*4;construction_upload_count+=1
    var node=MultiMeshInstance3D.new();node.name=name_;node.multimesh=mm;node.material_override=material
    _configure(node,end)
    mm.custom_aabb=node.get_aabb()
    return node

func _configure(node: GeometryInstance3D,end: float) -> void:
    node.set_meta("botanical_foliage",true);node.set_meta("performance_foliage_148",true)
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
    node.visibility_range_end=end;node.visibility_range_end_margin=6.0
    node.set_meta("performance_visibility_end",end)
    node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
    root.add_child(node);nodes.append(node)

func set_active(value: bool) -> void:
    _active=value;root.visible=value;_last_eye=Vector3(INF,INF,INF)

func set_distance_culling_enabled(value: bool) -> void:
    _distance_culling_enabled=value;_last_eye=Vector3(INF,INF,INF)
    for node in nodes:
        node.visibility_range_end=float(node.get_meta("performance_visibility_end")) if value else 0.0
    if not value:
        # Disable the custom distance/density decisions as well as native range
        # rejection. The engine's ordinary frustum culling remains intact.
        for chunk: Chunk in herb_chunks:
            chunk.level=0;chunk.near.show();chunk.middle.hide();chunk.far.hide()

func update(camera: Camera3D) -> void:
    if not _active or not _distance_culling_enabled or camera==null:return
    var eye=camera.global_position
    if _last_eye.distance_squared_to(eye)<1.0:return
    _last_eye=eye
    for chunk: Chunk in herb_chunks:
        var d=eye.distance_to(eye.clamp(chunk.bounds.position,chunk.bounds.end))
        var close: float=quality.herb_near;var middle: float=quality.herb_middle
        var next=0 if d<close else (1 if d<middle else 2)
        # Hysteresis avoids density flicker at a cell boundary. Vertex shrink
        # in the fast herb material handles the final distant disappearance.
        if chunk.level==0 and d<close+3.0:next=0
        elif chunk.level==1 and d>maxf(0,close-3.0) and d<middle+4.0:next=1
        elif chunk.level==2 and d>middle-3.0:next=2
        if next==chunk.level:continue
        chunk.level=next;chunk.near.visible=next==0;chunk.middle.visible=next==1;chunk.far.visible=next==2

func summary(camera: Camera3D) -> Dictionary:
    var result={"near_cards_authored":near_card_count,"branch_lobes_authored":lobe_count,"far_crowns_authored":far_crown_count,"herbs_authored":herb_count,"spatial_chunks":chunks.size()+herb_chunks.size(),"visible_cards":0,"visible_proxies":0,"visible_herbs":0,"estimated_submitted_triangles":0,"construction_upload_bytes":construction_upload_bytes,"construction_upload_count":construction_upload_count,"foliage_buffer_upload_bytes":0,"foliage_buffer_upload_count":0,"note":"Frustum/distance estimates for immutable physical chunks; actual rendered calls/triangles come from RenderingServer. No device FPS inference."}
    result["quality"]=quality.duplicate(true)
    if camera==null:return result
    var planes=camera.get_frustum();var eye=camera.global_position
    for chunk: Chunk in chunks:
        var d=eye.distance_to(eye.clamp(chunk.bounds.position,chunk.bounds.end))
        if (_distance_culling_enabled and d>chunk.node.visibility_range_end) or not _intersects(planes,chunk.bounds):continue
        var active=0
        for center: Vector3 in chunk.root_distances:
            var distance=eye.distance_to(center)
            if chunk.kind=="canopy_detail" and distance<quality.detail.y:active+=1
            elif chunk.kind=="climbing_detail" and distance<quality.ivy.y:active+=1
            elif chunk.kind=="branch_lobes" and distance>quality.middle_grow.x and distance<quality.middle_shrink.y:active+=1
            elif chunk.kind=="far_crown" and distance>quality.far_grow.x and distance<quality.far_shrink.y:active+=1
        if chunk.kind.ends_with("detail"):result.visible_cards+=active
        else:result.visible_proxies+=active
        result.estimated_submitted_triangles+=chunk.triangles
    for chunk: Chunk in herb_chunks:
        var d=eye.distance_to(eye.clamp(chunk.bounds.position,chunk.bounds.end))
        if (_distance_culling_enabled and d>quality.herb_end) or not _intersects(planes,chunk.bounds):continue
        var node: MultiMeshInstance3D=chunk.near if chunk.level==0 else (chunk.middle if chunk.level==1 else chunk.far)
        result.visible_herbs+=node.multimesh.instance_count
    return result

func _intersects(planes: Array[Plane],bounds: AABB) -> bool:
    var center=bounds.get_center();var extent=bounds.size*.5
    for plane: Plane in planes:
        if plane.distance_to(center)>plane.normal.abs().dot(extent):return false
    return true
