extends RefCounted
## The same fuse, reduction gear and key appear on pedestals and in the panel.
static func build(index: int) -> Node3D:
    var root=Node3D.new();root.name=["PumpFuse","GateReductionGear","ServicePanelKey"][index]
    var brass=StandardMaterial3D.new();brass.albedo_color=Color("c3a163");brass.roughness=.78;brass.metallic=.35
    var ceramic=StandardMaterial3D.new();ceramic.albedo_color=Color("d0d4c8");ceramic.roughness=.9
    if index==0:
        var fuse=CylinderMesh.new();fuse.top_radius=.075;fuse.bottom_radius=.075;fuse.height=.32;fuse.radial_segments=12;_mesh(root,fuse,Vector3.ZERO,ceramic)
        for y in [-.16,.16]:
            var cap=CylinderMesh.new();cap.top_radius=.085;cap.bottom_radius=.085;cap.height=.05;cap.radial_segments=12;_mesh(root,cap,Vector3(0,y,0),brass)
    elif index==1:
        var ring=TorusMesh.new();ring.inner_radius=.09;ring.outer_radius=.18;ring.rings=16;ring.ring_segments=6;_mesh(root,ring,Vector3.ZERO,brass)
        for i in range(10):
            var a=i*TAU/10;var tooth=BoxMesh.new();tooth.size=Vector3(.075,.05,.09);var n=_mesh(root,tooth,Vector3(cos(a)*.18,0,sin(a)*.18),brass);n.rotation.y=-a
    else:
        var ring=TorusMesh.new();ring.inner_radius=.065;ring.outer_radius=.10;ring.rings=12;ring.ring_segments=5;_mesh(root,ring,Vector3(0,0,.1),brass)
        var stem=BoxMesh.new();stem.size=Vector3(.04,.035,.27);_mesh(root,stem,Vector3(0,0,-.10),brass)
        for z in [-.16,-.22]:
            var tooth=BoxMesh.new();tooth.size=Vector3(.10,.035,.035);_mesh(root,tooth,Vector3(.035,0,z),brass)
    _merge(root)
    return root
static func _mesh(parent: Node3D,mesh: Mesh,p: Vector3,mat: Material) -> MeshInstance3D:
    var node=MeshInstance3D.new();node.mesh=mesh;node.position=p;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node

static func _merge(root: Node3D) -> void:
    var batches={}
    for node in root.get_children():
        var mat=node.material_override
        if not batches.has(mat):var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[mat]=st
        batches[mat].append_from(node.mesh,0,node.transform);root.remove_child(node);node.free()
    for mat in batches:
        var st: SurfaceTool=batches[mat];st.index();var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node)
