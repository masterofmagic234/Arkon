extends RefCounted
# Full volumetric flowers, ferns and carved garden urns. Immutable geometry is
# spatially combined; no per-petal nodes, alpha overdraw or per-frame updates.
const Data=preload("res://scripts/level_data.gd")
const Props=preload("res://scripts/level1_park_props.gd")
const Batch=preload("res://scripts/level1_trail_batch.gd")
static func build(host) -> void:
    var batch := Batch.new()
    var stem := CylinderMesh.new();stem.top_radius=.007;stem.bottom_radius=.012;stem.height=1;stem.radial_segments=5
    var leaf := _leaf_mesh()
    var petal := SphereMesh.new();petal.radius=.5;petal.height=.34;petal.radial_segments=6;petal.rings=3
    var rng := RandomNumberGenerator.new();rng.seed=131026
    var beds := 0
    for section in range(1,Data.PATH_CELLS.size()):
        var a := Data.cell_center_world(Data.PATH_CELLS[section-1])
        var b := Data.cell_center_world(Data.PATH_CELLS[section])
        var side := a.direction_to(b).cross(Vector3.UP)
        var steps := ceili(a.distance_to(b)/3.2)
        for i in range(steps):
            if (i+section)%2!=0: continue
            var p := a.lerp(b,(i+.5)/steps)+side*(1.8 if (section+i)%3==0 else -1.8)
            if not _safe(p) or Data.on_gravel(p): continue
            var is_fern := section%3==0
            for plant in range(5):
                var at := p+Vector3(rng.randf_range(-.38,.38),0,rng.randf_range(-.38,.38))
                if not _safe(at): continue
                if is_fern: _fern(batch,leaf,at,rng)
                else: _flowers(batch,stem,leaf,petal,at,rng,section%2==0)
            beds+=1
    for cell in Props.URNS:
        var at := Data.cell_center_world(cell)
        _urn(batch,at)
        for i in range(9):
            var p := at+Vector3(cos(i*2.4)*.22,.85,sin(i*2.4)*.22)
            _flowers(batch,stem,leaf,petal,p,rng,i%2==0,.62)
        # Ivy drapes over the rim but stays outside the urn body.
        for i in range(8):
            var angle := i*TAU/8
            for j in range(4):
                var p := at+Vector3(cos(angle)*(.40+j*.023),.85-j*.14,sin(angle)*(.40+j*.023))
                batch.add(leaf,Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(.16,.16,.20)),p),Color("4f7651"))
    batch.finish(host.scenery_root)
    host.scenery_root.set_meta("flower_beds",beds)
    host.scenery_root.set_meta("garden_urns",Props.URNS.size())
static func _safe(p: Vector3) -> bool:
    var cell := Data.world_to_cell(p.x,p.z)
    return cell.x>=2 and cell.x<Data.MAP_WIDTH-2 and cell.y>=2 and cell.y<Data.MAP_HEIGHT-2 and Data.CANONICAL_MAP[cell.y][cell.x]=="." and not Props.contains_point(p+Vector3.UP*.3,.45) and p.distance_to(preload("res://scripts/level1_park_pond.gd").center())>7.8
static func _leaf_mesh() -> ArrayMesh:
    var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var points := [Vector3(0,0,0),Vector3(-.3,.12,.45),Vector3(0,.22,1),Vector3(.3,.12,.45),Vector3(0,.19,.45)]
    for triangle in [[0,1,4],[1,2,4],[2,3,4],[3,0,4]]:
        for index in triangle:
            surface.set_normal(Vector3.UP);surface.add_vertex(points[index])
        for index in [triangle[2],triangle[1],triangle[0]]:
            surface.set_normal(Vector3.DOWN);surface.add_vertex(points[index]+Vector3.DOWN*.02)
    return surface.commit()
static func _flowers(batch,stem,leaf,petal,at: Vector3,rng: RandomNumberGenerator,warm: bool,scale_: float=1.0) -> void:
    for stalk in range(3):
        var h := rng.randf_range(.45,.95)*scale_
        var p := at+Vector3(rng.randf_range(-.13,.13),0,rng.randf_range(-.13,.13))
        batch.add(stem,Transform3D(Basis.from_scale(Vector3(1,h,1)),p+Vector3.UP*h*.5),Color("476347"))
        for k in range(3):
            var yaw := stalk*2.4+k*2.2
            batch.add(leaf,Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(.36,.36,.32)*scale_),p+Vector3.UP*h*(.23+k*.21)),Color("567852"))
        var center := p+Vector3.UP*h
        var zone := Data.episode_at(at)
        var shade: Color = [Color("ebc7aa"),Color("9cc6df"),Color("c29ae1"),Color("e8c477")][zone]
        if not warm: shade=shade.lerp(Color("e6e2d0"),.35)
        for k in range(7):
            var angle := k*TAU/7
            var place := center+Vector3(cos(angle)*.085,.025,sin(angle)*.085)*scale_
            batch.add(petal,Transform3D((Basis(Vector3.UP,-angle)*Basis(Vector3.RIGHT,-.28)).scaled(Vector3(.13,.16,.23)*scale_),place),shade)
        batch.add(petal,Transform3D(Basis.from_scale(Vector3(.105,.11,.105)*scale_),center+Vector3.UP*.04*scale_),Color("dfb86c"))
static func _fern(batch,leaf,at: Vector3,rng: RandomNumberGenerator) -> void:
    for i in range(7):
        var yaw := i*TAU/7+rng.randf_range(-.2,.2)
        var basis := Basis(Vector3.UP,yaw)
        for k in range(6):
            var t := float(k)/6
            var p := at+basis*Vector3(0,sin(t*PI)*.44+.12,t*.75)
            for side: float in [-1,1]:
                var size_ := lerpf(.42,.10,t)
                batch.add(leaf,Transform3D(basis*Basis(Vector3.UP,side*.9).scaled(Vector3(size_,size_,size_*.65)),p),Color("49745a").lerp(Color("8b9c69"),t))
static func _urn(batch,at: Vector3) -> void:
    var urn := CylinderMesh.new();urn.top_radius=.40;urn.bottom_radius=.21;urn.height=.54;urn.radial_segments=16
    batch.add(urn,Transform3D(Basis.IDENTITY,at+Vector3.UP*.54),Color("a6a292"))
    var foot := CylinderMesh.new();foot.top_radius=.18;foot.bottom_radius=.26;foot.height=.28;foot.radial_segments=12
    batch.add(foot,Transform3D(Basis.IDENTITY,at+Vector3.UP*.14),Color("949689"))
    var rim := TorusMesh.new();rim.inner_radius=.33;rim.outer_radius=.43;rim.rings=16;rim.ring_segments=6
    batch.add(rim,Transform3D(Basis.IDENTITY,at+Vector3.UP*.82),Color("c1b8a2"))
    var soil := CylinderMesh.new();soil.top_radius=.34;soil.bottom_radius=.34;soil.height=.02;soil.radial_segments=16
    batch.add(soil,Transform3D(Basis.IDENTITY,at+Vector3.UP*.82),Color("383429"))
    # Twelve raised ribs turn the bowl into a readable carved prop.
    var rib := SphereMesh.new();rib.radius=.5;rib.height=1;rib.radial_segments=6;rib.rings=3
    for i in range(12):
        var a := i*TAU/12
        batch.add(rib,Transform3D(Basis(Vector3.UP,a).scaled(Vector3(.075,.39,.08)),at+Vector3(cos(a)*.30,.52,sin(a)*.30)),Color("b9b29d"))
