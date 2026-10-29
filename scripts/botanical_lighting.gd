extends RefCounted
## Offline indirect lighting and sky occlusion; direct sun remains realtime.
const SCENE="res://assets/level1/botanical/lighting/garden.scn"
const BINDINGS="res://assets/level1/botanical/lighting/source_bindings.json"
var world: Node3D
var baked_root: Node3D
var gi: LightmapGI
var data: LightmapGIData
var originals: Array[GeometryInstance3D]=[]
var original_visibility: Array[bool]=[]
var original_shadow: Array[int]=[]
var probe_sources: Dictionary={}
var enabled:=false
var previous_ssao:=true
var retired_sources: Dictionary={}
func setup(garden: Node3D) -> void:
    world=garden
    if not ResourceLoader.exists(SCENE):return
    baked_root=load(SCENE).instantiate()
    gi=baked_root.get_node("BakedGI");data=preload("res://assets/level1/botanical/lighting/garden_evening.lmbake");gi.light_data=data
    if data==null or data.get_user_count()==0:
        baked_root.free();baked_root=null;return
    # Stable authored IDs survive adding colliders, moving furniture, and new
    # planting batches. Keep the original atlas/probes; never bind by child
    # position after editing the garden layout.
    var bindings=JSON.parse_string(FileAccess.get_file_as_string(BINDINGS)).sources
    var sources={}
    for child in world.get_children():
        if child is GeometryInstance3D and child.has_meta("lightmap_source_id"):
            sources[String(child.get_meta("lightmap_source_id"))]=child
    var seen={}
    for receiver in baked_root.get_children():
        if not receiver is MeshInstance3D:continue
        var index=int(receiver.get_meta("source_child",-1))
        var id=String(receiver.get_meta("lightmap_source_id",bindings.get(str(index),"")))
        # These old bench surfaces are intentionally retired. Their replacements
        # use the saved probe volume, with their new positions and live shadows.
        if id=="batch:box|wood|0|0" and not sources.has(id):
            receiver.hide();retired_sources[id]=true;continue
        if not sources.has(id):
            push_error("Baked garden does not match source geometry")
            baked_root.free();baked_root=null;return
        var source: GeometryInstance3D=sources[id]
        if source.get_meta("authored_geometry151",false):
            # Corrected stair/rock-bank terrain and three ribbons cut around
            # actual stair footprints cannot keep the old receiver's vertices.
            # These five tiles/three paths use the existing probe volume.
            retired_sources[id]=true;receiver.hide();source.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
            if not seen.has(source):
                seen[source]=true;originals.append(source);original_visibility.append(source.visible);original_shadow.append(source.cast_shadow)
            probe_sources[source]=true
            continue
        var moved_props=id.begins_with("batch:box|iron|") or id.begins_with("batch:cylinder|moss|")
        var expected: AABB=receiver.get_meta("source_bounds")
        var actual: AABB=source.transform*source.get_aabb()
        # Dummy rendering does not retain MultiMesh buffers/bounds. Native
        # validation compares the same conservative source bounds as the bake.
        if not moved_props and DisplayServer.get_name()!="headless" and (actual.position.distance_to(expected.position)>.05 or actual.size.distance_to(expected.size)>.05):
            push_error("Baked garden bounds no longer match source geometry: %s expected %s actual %s"%[id,str(expected),str(actual)])
            baked_root.free();baked_root=null;return
        if not seen.has(source):
            seen[source]=true
            originals.append(source);original_visibility.append(source.visible)
            original_shadow.append(source.cast_shadow)
        # Repeated natural props keep their original instanced LODs, like
        # leaves. Unique UV2 seams limit simplification of branches and rocks.
        if moved_props or source is MultiMeshInstance3D and (source.material_override in [world.mats.bark,world.mats.cliff] or source.multimesh.mesh==world.meshes.cylinder):
            probe_sources[source]=true
            receiver.hide();source.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
        # Keep the original instanced, culled shadow geometry. The merged UV2
        # receiver exists only in the color pass, avoiding much heavier shadows.
        receiver.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # These vertices use world units. Default one-display-pixel LOD error
        # remains subpixel at the capped internal 3D resolution.
        receiver.lod_bias=1.0
    previous_ssao=world.environment.ssao_enabled
    world.add_child(baked_root)
    # MultiMeshes sample the baked SH probe volume rather than needing unique
    # UV2 charts for thousands of repeated leaves. Squirrels use the same volume.
    for source in world.get_children():
        if source is GeometryInstance3D and source.get_meta("botanical_foliage",false):source.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
    set_enabled(true)
func set_enabled(value: bool) -> void:
    if baked_root==null:return
    enabled=value
    # LightmapGI visibility does not detach its data; explicitly detach it for
    # the original-lighting A/B so neither probes nor receiver bindings leak.
    gi.light_data=data if value else null
    baked_root.visible=value
    for i in range(originals.size()):
        if probe_sources.has(originals[i]):
            originals[i].visible=original_visibility[i];originals[i].cast_shadow=original_shadow[i]
            continue
        var casts=original_shadow[i]!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        originals[i].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if value and casts else original_shadow[i]
        originals[i].visible=original_visibility[i] and (not value or casts)
    world.environment.ssao_enabled=false if value else previous_ssao
