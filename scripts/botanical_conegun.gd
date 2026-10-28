extends Node3D
## Handmade pneumatic cone launcher, four shared opaque material batches.
var batches: Dictionary={}
func _ready() -> void:
    name="PineConeLauncher"
    var wood=StandardMaterial3D.new();wood.albedo_color=Color("8e6846");wood.albedo_texture=preload("res://assets/level1/textures/park_oak_bark.jpg");wood.roughness=.92
    var steel=StandardMaterial3D.new();steel.albedo_color=Color("3c4953");steel.metallic=.55;steel.roughness=.78
    var brass=StandardMaterial3D.new();brass.albedo_color=Color("b8985a");brass.metallic=.35;brass.roughness=.72
    _box(Vector3(0,.005,.08),Vector3(.11,.115,.28),wood)
    _box(Vector3(0,-.095,.12),Vector3(.066,.17,.075),wood,Vector3(.2,0,0))
    _cylinder(Vector3(0,-.045,.255),.070,.18,wood,Vector3(PI*.5,0,0))
    _box(Vector3(0,.03,-.095),Vector3(.135,.075,.19),wood)
    _cylinder(Vector3(0,.045,-.27),.038,.38,steel,Vector3(PI*.5,0,0))
    _cylinder(Vector3(0,.045,-.455),.043,.022,brass,Vector3(PI*.5,0,0))
    _cylinder(Vector3(0,.045,-.08),.048,.026,brass,Vector3(PI*.5,0,0))
    _box(Vector3(0,.103,-.26),Vector3(.016,.035,.055),steel)
    _box(Vector3(0,-.075,.015),Vector3(.075,.032,.095),steel)
    var cone_material=StandardMaterial3D.new();cone_material.albedo_color=Color("795934");cone_material.roughness=.95
    # Side-loaded cone magazine makes the ammunition legible from first person.
    for i in range(3):
        var center=Vector3(-.078,.08,-.03-i*.082)
        _sphere(center,.027,.10,cone_material)
        for ring in range(4):
            for j in range(6):
                var a=j*TAU/6+ring*.35
                var r=sin((ring+.5)*PI/4)*.025
                _sphere(center+Vector3(cos(a)*r,-.035+ring*.023,sin(a)*r),.014,.014,cone_material)
    for material in batches:
        var st: SurfaceTool=batches[material];st.index();var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.layers=1<<19;add_child(node)
    batches.clear()
    var key_light=OmniLight3D.new();key_light.name="WeaponOnlyReadabilityLight";key_light.position=Vector3(-.15,.28,.2);key_light.light_color=Color("c6b99c");key_light.light_energy=.65;key_light.omni_range=1.3;key_light.shadow_enabled=false;key_light.light_cull_mask=1<<19;add_child(key_light)
func _append(mesh: Mesh,p: Vector3,mat: Material,rotation:=Vector3.ZERO) -> void:
    if not batches.has(mat):var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batches[mat]=st
    var st: SurfaceTool=batches[mat];st.append_from(mesh,0,Transform3D(Basis.from_euler(rotation),p))
func _box(p: Vector3,size: Vector3,mat: Material,rotation:=Vector3.ZERO) -> void:
    var mesh=BoxMesh.new();mesh.size=size;_append(mesh,p,mat,rotation)
func _cylinder(p: Vector3,radius: float,height: float,mat: Material,rotation:=Vector3.ZERO) -> void:
    var mesh=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=10;_append(mesh,p,mat,rotation)

func _sphere(p: Vector3,radius: float,height: float,mat: Material) -> void:
    var mesh=SphereMesh.new();mesh.radius=radius;mesh.height=height;mesh.radial_segments=8;mesh.rings=4;_append(mesh,p,mat)
