extends RefCounted
## Mobile garden renderer. The 1.47 controller is retained explicitly for
## reversible, warmed comparisons; production foliage uses immutable chunks.
const Legacy = preload("res://scripts/botanical_rendering_147.gd")
const Foliage = preload("res://scripts/botanical_foliage148.gd")
const CELL = 16.0
var records: Array=[]
var foliage_records: Array=[]
var preserved_foliage_records: Array=[]
var static_records: Array=[]
var legacy: RefCounted
var mobile_foliage: RefCounted
var world: Node3D
var _reference_147 := false
var _original_visibility: Dictionary={}
var _preserved_materials: Dictionary={}
var enabled := true
var foliage_sorting_enabled := true
var cluster_sorting_enabled := true
var foliage_geometry_enabled := true
var force_upload := false
var upload_count := 0
var last_update_usec := 0
var last_camera := Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF))
var last_sort_position := Vector3(INF,INF,INF)
static func optimize_materials(owner_: Node3D) -> void:Legacy.optimize_materials(owner_)
static func alpha_mask(atlas: Texture2D) -> Texture2D:return Legacy.alpha_mask(atlas)
static func atlas_alpha_shader(source: Shader) -> Shader:return Legacy.atlas_alpha_shader(source)
static func add_occluders(owner_: Node3D) -> void:Legacy.add_occluders(owner_)
static func intersects(planes: Array[Plane],normals: PackedVector3Array,center: Vector3,extent: Vector3) -> bool:return Legacy.intersects(planes,normals,center,extent)
static func casts_into_view(planes: Array[Plane],normals: PackedVector3Array,extensions: PackedFloat32Array,center: Vector3,extent: Vector3,length_: float) -> bool:return Legacy.casts_into_view(planes,normals,extensions,center,extent,length_)
func setup(owner_: Node3D) -> void:
    world=owner_
    if DisplayServer.get_name()=="headless":return
    legacy=Legacy.new();legacy.setup(world);records=legacy.records.duplicate()
    for record in records:
        var shape=String(record.instance.get_meta("lightmap_source_id","")).trim_prefix("batch:").get_slice("|",0)
        var is_foliage=bool(record.instance.get_meta("botanical_foliage",false))
        var replaced=is_foliage and (bool(record.instance.get_meta("botanical_cutout",false)) or shape in ["herb3","herb4","herb5","lilyflower"])
        if replaced:
            foliage_records.append(record);_original_visibility[record.instance]=record.instance.visible
            var shadow=record.instance.get_meta("foliage_shadow_node") if record.instance.has_meta("foliage_shadow_node") else null
            if shadow!=null:_original_visibility[shadow]=shadow.visible
        else:
            static_records.append(record)
            if is_foliage:
                preserved_foliage_records.append(record)
                _preserved_materials[record.instance]=record.instance.material_override
                record.instance.set_meta("performance_preserve_material_147",true)
    mobile_foliage=Foliage.new();mobile_foliage.setup(world,foliage_records)
    set_reference_147_enabled(bool(world.get_meta("reference_147",false)))
func set_reference_147_enabled(value: bool) -> void:
    _reference_147=value
    if legacy==null:return
    # Restore immutable authored reference buffers before changing the active
    # controller subset. Visibility here applies only to foliage; baked static
    # receivers retain the post-bake visibility/shadow state managed elsewhere.
    legacy.records.assign(records)
    legacy.set_enabled(enabled)
    for node in _original_visibility:
        if is_instance_valid(node):node.visible=bool(_original_visibility[node]) and value
    # Unsupported shapes deliberately retain their original render contract,
    # too. A one-sided lily pad cannot use the fast herb cull-back material
    # unless its topology has also been rebuilt with the matching back face.
    for node in _preserved_materials:
        if is_instance_valid(node):node.material_override=_preserved_materials[node]
    mobile_foliage.set_active(not value)
    legacy.records.assign(records if value else static_records)
    legacy.last_camera=Transform3D(Basis.IDENTITY,Vector3(INF,INF,INF))
    last_camera=legacy.last_camera
func is_reference_147_enabled() -> bool:return _reference_147
func apply_quality(settings: Dictionary) -> void:
    if mobile_foliage!=null:mobile_foliage.apply_quality(settings)
func update(camera: Camera3D) -> void:
    if legacy==null or camera==null:return
    var started=Time.get_ticks_usec()
    legacy.foliage_sorting_enabled=foliage_sorting_enabled
    legacy.cluster_sorting_enabled=cluster_sorting_enabled
    legacy.update(camera)
    if not _reference_147:mobile_foliage.update(camera)
    last_update_usec=Time.get_ticks_usec()-started
    upload_count=legacy.upload_count;last_camera=camera.global_transform
func set_enabled(value: bool) -> void:
    enabled=value
    if legacy!=null:legacy.set_enabled(value)
    if mobile_foliage!=null:mobile_foliage.set_distance_culling_enabled(value)
func set_foliage_sorting_enabled(value: bool) -> void:
    foliage_sorting_enabled=value
    if legacy!=null:legacy.set_foliage_sorting_enabled(value)
func set_foliage_geometry_enabled(value: bool) -> void:
    foliage_geometry_enabled=value
    if legacy==null:return
    var subset=legacy.records.duplicate();legacy.records.assign(foliage_records)
    legacy.set_foliage_geometry_enabled(value);legacy.records.assign(subset)
func apply_foliage_geometry(record) -> void:
    if legacy!=null:legacy.apply_foliage_geometry(record)
func foliage_workload(camera: Camera3D) -> Dictionary:
    if legacy==null:return {}
    if _reference_147:return legacy.foliage_workload(camera)
    return mobile_foliage.summary(camera)
func workload_summary(camera: Camera3D=null) -> Dictionary:
    if legacy==null:return {"reference_147":_reference_147,"headless":true}
    var result=legacy.foliage_workload(camera) if _reference_147 and camera!=null else (mobile_foliage.summary(camera) if not _reference_147 else {})
    result["reference_147"]=_reference_147
    result["buffer_upload_count"]=legacy.upload_count
    result["buffer_upload_bytes"]=legacy.buffer_upload_bytes
    result["update_cpu_us"]=last_update_usec
    result["original_foliage_instances"]=0
    for record in foliage_records:result.original_foliage_instances+=record.multi.instance_count
    result["preserved_original_foliage_instances"]=0
    for record in preserved_foliage_records:
        result.original_foliage_instances+=record.multi.instance_count
        result.preserved_original_foliage_instances+=record.multi.instance_count
    if _reference_147:
        result["foliage_buffer_upload_count"]=-1
        result["foliage_buffer_upload_bytes"]=-1
        result["note"]="Actual 1.47 reference renderer; total controller buffer writes measured, foliage-only attribution not separated."
    return result
