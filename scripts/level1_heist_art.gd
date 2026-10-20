extends RefCounted
# Compact, opaque mechanical silhouettes; two shared materials, spatially
# culled meshes, no new light, viewport, particles or full-screen effect.
const Batch = preload("res://scripts/level1_trail_batch.gd")
const Data = preload("res://scripts/level_data.gd")
const BRASS := Color("bca06a")
const DARK := Color("203d49")
const MINT := Color("81e6d4")
const GOLD := Color("ffd28a")
var solid_material: StandardMaterial3D
var glow_material: ShaderMaterial
var box := BoxMesh.new()
var cylinder := CylinderMesh.new()
var sphere := SphereMesh.new()
var torus := TorusMesh.new()
var solid: RefCounted
var glow: RefCounted

func build(host: Node3D) -> void:
    box.size = Vector3.ONE
    cylinder.top_radius=.5; cylinder.bottom_radius=.5; cylinder.height=1; cylinder.radial_segments=12; cylinder.rings=0
    sphere.radius=.5; sphere.height=1; sphere.radial_segments=8; sphere.rings=4
    torus.inner_radius=.42; torus.outer_radius=.50; torus.rings=24; torus.ring_segments=6
    solid_material = StandardMaterial3D.new()
    solid_material.vertex_color_use_as_albedo=true; solid_material.vertex_color_is_srgb=true
    solid_material.roughness=.62; solid_material.metallic=.45
    glow_material = ShaderMaterial.new()
    glow_material.shader = preload("res://shaders/level1_garden_inlay.gdshader")
    for device in host.devices: _device(device)
    for id: String in host.locked_acorns:
        var acorn: Node3D=host.locked_acorns[id]
        var root_ := Node3D.new(); root_.name=id+"Seal"; root_.position=Vector3(acorn.position.x,0,acorn.position.z)
        host.add_child(root_)
        _start()
        for height: float in [.20,1.35]: _part(torus,Vector3(0,height,0),Vector3(1.55,.7,1.55),BRASS)
        for angle in range(6):
            var at := Vector3(cos(angle*TAU/6)*.70,.78,sin(angle*TAU/6)*.70)
            _part(cylinder,at,Vector3(.045,1.15,.045),MINT,true)
        _finish(root_)
        host.cages[id]=root_
    for cell: Vector2i in preload("res://scripts/level1_heist_data.gd").SCANNERS:
        var scanner := Node3D.new(); scanner.name="GalleryScanner"; scanner.position=Data.cell_center_world(cell)
        host.add_child(scanner)
        _start()
        _part(cylinder,Vector3(0,1.35,0),Vector3(.12,2.7,.12),BRASS)
        _part(box,Vector3(0,2.75,0),Vector3(.55,.28,.50),DARK)
        _part(sphere,Vector3(0,2.75,-.23),Vector3(.28,.21,.06),GOLD,true)
        _finish(scanner)
        var beam := MeshInstance3D.new(); beam.name="SweepFootprint"
        var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in range(20):
            var a := lerpf(-.25,.25,float(i)/20.0)
            var b := lerpf(-.25,.25,float(i+1)/20.0)
            for vertex: Vector3 in [Vector3(0,.035,0),Vector3(sin(b)*9,.035,-cos(b)*9),Vector3(sin(a)*9,.035,-cos(a)*9)]: st.add_vertex(vertex)
        beam.mesh=st.commit()
        var material := StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.albedo_color=Color(1,.63,.28,.14)
        material.cull_mode=BaseMaterial3D.CULL_DISABLED
        beam.material_override=material; beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        scanner.add_child(beam); scanner.visible=false
        host.scanners.append(scanner)
    # A physical hint, readable from the first lens rather than a modal menu.
    var hint := _label("ЛУННАЯ ОРАНЖЕРЕЯ\nI · ЛУНА    II · ЛИСТ    III · ЛУНА",Vector3(0,2.4,0),MINT)
    hint.position += Data.cell_center_world(Vector2i(16,4))
    hint.visibility_range_end=12
    host.add_child(hint)

func _device(device: Node3D) -> void:
    _start()
    var tint := MINT if device.kind in ["dial","relay"] else GOLD
    if device.kind=="note":
        _part(cylinder,Vector3(0,.5,0),Vector3(.08,1,.08),BRASS)
        _part(box,Vector3(0,1.05,0),Vector3(.52,.40,.12),DARK)
        for y: float in [.95,1.05,1.15]: _part(box,Vector3(0,y,-.07),Vector3(.34,.018,.015),GOLD,true)
    elif device.kind=="bell":
        _part(cylinder,Vector3(0,.85,0),Vector3(.09,1.7,.09),DARK)
        _part(torus,Vector3(0,1.45,0),Vector3(.66,.66,.66),BRASS,false,Basis(Vector3.RIGHT,PI*.5))
        _part(cylinder,Vector3(0,1.38,-.02),Vector3(.24,.28,.24),BRASS)
        _part(sphere,Vector3(0,1.17,-.02),Vector3(.08,.08,.08),tint,true)
    else:
        _part(cylinder,Vector3(0,.10,0),Vector3(.86,.20,.86),DARK)
        _part(cylinder,Vector3(0,.48,0),Vector3(.40,.72,.40),BRASS)
        _part(cylinder,Vector3(0,.83,0),Vector3(.70,.10,.70),DARK)
        _part(torus,Vector3(0,.90,0),Vector3(.70,.40,.70),tint,true)
        _part(torus,Vector3(0,1.12,0),Vector3(.68,.68,.68),BRASS,false,Basis(Vector3.RIGHT,PI*.5))
        if device.kind=="seal":
            _part(sphere,Vector3(0,1.14,0),Vector3(.40,.48,.32),GOLD,true)
        elif device.kind=="relay":
            _part(box,Vector3(0,1.12,0),Vector3(.46,.38,.24),DARK)
            _part(box,Vector3(0,1.13,-.14),Vector3(.30,.08,.025),tint,true)
    _finish(device)
    if device.kind=="dial":
        var dial := Node3D.new(); dial.name="LensRotor"; dial.position.y=1.12
        device.add_child(dial); device.dial=dial
        _start()
        for i in range(3):
            var yaw := float(i)*TAU/3.0
            var at := Vector3(sin(yaw)*.30,0,-cos(yaw)*.30)
            _part(sphere,at,Vector3(.12,.14,.07),[GOLD,MINT,Color("cbb0ec")][i],true,Basis(Vector3.UP,-yaw))
        _part(box,Vector3(0,0,-.17),Vector3(.025,.025,.28),BRASS)
        _finish(dial)
    device.title = _label(device.description(),Vector3(0,1.95 if device.kind=="bell" else 1.70,0),tint)
    device.add_child(device.title)

func _label(line: String, at: Vector3, tint: Color) -> Label3D:
    var label := Label3D.new(); label.text=line; label.position=at
    label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.font_size=36; label.pixel_size=.0030
    label.modulate=tint; label.outline_size=7; label.visibility_range_end=9.5
    label.no_depth_test=false
    return label

func _start() -> void:
    solid=Batch.new(); glow=Batch.new()

func _part(mesh: Mesh, at: Vector3, scale_: Vector3, tint: Color, emissive := false, basis_ := Basis.IDENTITY) -> void:
    (glow if emissive else solid).add(mesh,Transform3D(basis_*Basis.from_scale(scale_),at),tint)

func _finish(parent: Node3D) -> void:
    solid.finish(parent,"Mechanism",26,solid_material)
    glow.finish(parent,"Engraving",26,glow_material)
