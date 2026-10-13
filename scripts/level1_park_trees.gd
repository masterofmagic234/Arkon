extends RefCounted
# Shared oak profiles: curved continuous tubes, irregular layered crowns and
# small alpha-tested sprigs. Distant border trees have a cheaper closed canopy.
const BARK = preload("res://assets/level1/textures/park_oak_bark.jpg")
const CANOPY = preload("res://assets/level1/textures/park_oak_canopy.jpg")
const BAKED_CANOPY = preload("res://assets/level1/textures/park_oak_canopy_baked.png")
const SPRIG = preload("res://assets/level1/textures/park_oak_cluster.png")
var profiles: Array[Dictionary] = []
var planted := 0
var distant_count := 0
var sprig_count := 0

func make_resources(host) -> void:
    var bark := ShaderMaterial.new()
    bark.shader = preload("res://shaders/level1_tree_bark.gdshader")
    bark.set_shader_parameter("bark_tex",BARK)
    host.materials["tree_bark"] = bark
    for id in ["tree_leaf","tree_leaf_light","tree_gold"]:
        var mat := ShaderMaterial.new()
        mat.shader = preload("res://shaders/level1_tree_foliage.gdshader")
        mat.set_shader_parameter("leaf_tex",CANOPY)
        mat.set_shader_parameter("baked_tex",BAKED_CANOPY)
        mat.set_shader_parameter("tint",Vector3(0.76,0.87,0.77) if id=="tree_leaf" else Vector3(0.88,0.98,0.85))
        mat.set_shader_parameter("golden",id=="tree_gold")
        host.materials[id] = mat
    for golden in [false,true]:
        var mat := ShaderMaterial.new()
        mat.shader = preload("res://shaders/level1_tree_sprig.gdshader")
        mat.set_shader_parameter("leaf_tex",SPRIG)
        mat.set_shader_parameter("golden",golden)
        host.materials["tree_sprig_gold" if golden else "tree_sprig"] = mat
    host.meshes["oak_crown"] = _crown_mesh(16,8)
    host.meshes["oak_crown_far"] = _crown_mesh(10,6)
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    host.meshes["oak_sprig"] = quad
    for i in range(5):
        var profile := _profile(i,i==3,i==4)
        host.meshes["oak_body_%d"%i] = profile["mesh"]
        profiles.append(profile)

func plant(host, p: Vector3, height: float, golden: bool, distant: bool = false) -> void:
    var random := RandomNumberGenerator.new()
    random.seed = absi(roundi(p.x*100.0)*73856093 ^ roundi(p.z*100.0)*19349663) + 11207
    var id := 4 if distant else (3 if golden else random.randi_range(0,2))
    var yaw := random.randf()*TAU
    var turn := Basis(Vector3.UP,yaw)
    host._batch("oak_body_%d"%id,"tree_bark",p,Vector3.ONE*height,turn)
    var crowns: Array = profiles[id]["crowns"]
    for i in range(crowns.size()):
        var crown: Dictionary = crowns[i]
        var center: Vector3 = p+turn*(crown["center"]*height)
        var size_: Vector3 = crown["size"]*height
        size_.y *= 0.82
        var material := "tree_gold" if golden else ("tree_leaf_light" if i%3==0 else "tree_leaf")
        host._batch("oak_crown_far" if distant else "oak_crown",material,center,size_*(1.0 if distant else 0.90),Basis(Vector3.UP,yaw+crown["yaw"]))
        if not distant:
            _sprigs(host,center,size_,golden,random,12 if golden else 9)
    planted += 1
    if distant: distant_count += 1

func _sprigs(host, center: Vector3, size_: Vector3, golden: bool, random: RandomNumberGenerator, count: int) -> void:
    for i in range(count):
        var angle := float(i)*2.399963+random.randf_range(-0.25,0.25)
        var vertical := -0.28+float(i%3)*0.28+random.randf_range(-0.07,0.07)
        var radius := sqrt(1.0-vertical*vertical*4.0)*0.49
        var offset := Vector3(cos(angle)*size_.x*radius,vertical*size_.y,sin(angle)*size_.z*radius)
        var width := random.randf_range(0.65,0.94) * (1.18 if golden else 1.0)
        var turn := Basis.from_euler(Vector3(random.randf_range(-0.6,0.6),-angle-PI*0.5,random.randf_range(-0.65,0.65)))
        host._batch("oak_sprig","tree_sprig_gold" if golden else "tree_sprig",center+offset,Vector3(width,width,1.0),turn)
        sprig_count += 1

func _profile(id: int, golden: bool, distant: bool) -> Dictionary:
    var random := RandomNumberGenerator.new()
    random.seed = 72571+id*1877
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var crowns: Array[Dictionary] = []
    var radial := 6 if distant else 10
    var steps := 1 if distant else 2
    var reference_height := 13.0 if golden else 7.0
    var base := 0.086 if golden else 0.062
    var trunk := PackedVector3Array([Vector3.ZERO,Vector3(0.012,0.20,-0.008),Vector3(0.026,0.43,0.008),Vector3(-0.012,0.63,0.018),Vector3(-0.045,0.80,0.030),Vector3(-0.020,0.94,0.035)])
    _tube(st,trunk,PackedFloat32Array([base,base*0.87,base*0.68,base*0.43,base*0.22,0.002]),radial,steps,reference_height)
    var count := 3 if distant else (7 if golden else 5)
    for i in range(count):
        var angle := i*TAU/count+random.randf_range(-0.22,0.22)
        var direction := Vector3(cos(angle),0,sin(angle))
        var y := 0.60+float(i%3)*0.065+random.randf_range(-0.025,0.025)
        var reach := random.randf_range(0.21,0.28)
        var start := Vector3(0.015,0.40+float(i%3)*0.065,0.012)
        var middle := start+direction*reach*0.52+Vector3.UP*0.09
        var end := direction*reach+Vector3.UP*y
        _tube(st,PackedVector3Array([start,middle,end]),PackedFloat32Array([base*0.48,base*0.27,base*0.075]),radial,steps,reference_height)
        var center := end+Vector3.UP*0.062
        var size_ := Vector3(random.randf_range(0.32,0.40),random.randf_range(0.22,0.28),random.randf_range(0.32,0.42))
        crowns.append({"center":center,"size":size_,"yaw":angle})
        if not distant and (i%2==0 or golden):
            var fork_end := end+direction*0.075+Vector3(-direction.z,0.07,direction.x)*0.08
            _tube(st,PackedVector3Array([middle,end,fork_end]),PackedFloat32Array([base*0.23,base*0.10,0.001]),6,steps,reference_height)
            crowns.append({"center":fork_end+Vector3.UP*0.03,"size":Vector3(0.19,0.16,0.23),"yaw":angle+0.7})
    crowns.append({"center":Vector3(-0.02,0.82,0.018),"size":Vector3(0.36,0.29,0.37),"yaw":0.4})
    if not distant:
        crowns.append({"center":Vector3(-0.06,0.94,0.04),"size":Vector3(0.31,0.21,0.32),"yaw":1.1})
        for i in range(6 if golden else 4):
            var angle := i*TAU/(6.0 if golden else 4.0)+0.35
            var direction := Vector3(cos(angle),0,sin(angle))
            var reach := 2.0/reference_height if golden else 0.11
            _tube(st,PackedVector3Array([Vector3.UP*0.105,direction*reach*0.43+Vector3.UP*0.027,direction*reach+Vector3.UP*0.006]),PackedFloat32Array([base*0.48,base*0.29,0.004]),6,2,reference_height)
    st.generate_normals()
    st.index()
    return {"mesh":st.commit(),"crowns":crowns}

func _tube(st: SurfaceTool, control: PackedVector3Array, radii: PackedFloat32Array, radial: int, steps: int, reference_height: float) -> void:
    var centers := PackedVector3Array()
    var widths := PackedFloat32Array()
    for i in range(control.size()-1):
        for j in range(steps):
            var t := float(j)/steps
            centers.append(control[i].cubic_interpolate(control[i+1],control[maxi(0,i-1)],control[mini(control.size()-1,i+2)],t))
            widths.append(lerpf(radii[i],radii[i+1],t))
    centers.append(control[-1])
    widths.append(radii[-1])
    var rings: Array[PackedVector3Array] = []
    var ring_normals: Array[PackedVector3Array] = []
    var distances := PackedFloat32Array([0.0])
    for i in range(centers.size()):
        var direction := (centers[mini(i+1,centers.size()-1)]-centers[maxi(0,i-1)]).normalized()
        var helper := Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD))<0.9 else Vector3.RIGHT
        var side := direction.cross(helper).normalized()
        var other := direction.cross(side).normalized()
        var vertices := PackedVector3Array()
        var normals := PackedVector3Array()
        for j in range(radial+1):
            var angle := float(j)*TAU/radial
            var normal := side*cos(angle)+other*sin(angle)
            var ridge := 1.0+0.045*sin(angle*3.0+float(i)*0.4)
            vertices.append(centers[i]+normal*widths[i]*ridge)
            normals.append(normal)
        rings.append(vertices)
        ring_normals.append(normals)
        if i>0: distances.append(distances[-1]+centers[i].distance_to(centers[i-1])*reference_height)
    for i in range(rings.size()-1):
        for j in range(radial):
            for index in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i,j+1),Vector2i(i,j+1),Vector2i(i+1,j),Vector2i(i+1,j+1)]:
                st.set_normal(ring_normals[index.x][index.y])
                st.set_uv(Vector2(float(index.y)/radial*TAU*widths[index.x]*reference_height/1.0,distances[index.x]/1.7))
                st.add_vertex(rings[index.x][index.y])

func _crown_mesh(radial: int, bands: int) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for y in range(bands):
        for x in range(radial):
            var corners := [Vector2(float(x)/radial,float(y)/bands),Vector2(float(x+1)/radial,float(y)/bands),Vector2(float(x)/radial,float(y+1)/bands),Vector2(float(x+1)/radial,float(y+1)/bands)]
            for index in [0,2,1,1,2,3]:
                var uv: Vector2 = corners[index]
                var a := uv.x*TAU
                var b := uv.y*PI
                var normal := Vector3(sin(b)*cos(a),cos(b),sin(b)*sin(a))
                var lobe := 1.0+0.13*sin(a*3.0+b*1.7)*sin(b)+0.085*cos(a*5.0-b*3.0)*sin(b)
                st.set_normal(normal)
                st.set_uv(uv)
                st.add_vertex(normal*0.5*lobe)
    st.generate_normals()
    st.index()
    return st.commit()
