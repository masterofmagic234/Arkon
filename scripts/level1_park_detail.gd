extends RefCounted
# Low ground decoration follows the authored path and the same prop exclusion
# used by grass. Shared meshes, spatial batches; no nodes or work per leaf.
const Data=preload("res://scripts/level_data.gd")
const Props=preload("res://scripts/level1_park_props.gd")
static func build(host) -> void:
    var leaf := SurfaceTool.new()
    leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(12):
        var a := float(i)*TAU/12
        var b := float(i+1)*TAU/12
        for p: Vector3 in [Vector3.ZERO,Vector3(cos(b)*(.55 if i%2==0 else .42),0,sin(b)*.25),Vector3(cos(a)*(.42 if i%2==0 else .55),0,sin(a)*.25)]:
            leaf.set_normal(Vector3.UP)
            leaf.add_vertex(p)
    host.meshes["fallen_leaf"]=leaf.commit()
    host.materials["leaf_litter"]=host._material(Color(.29,.19,.075))
    host.materials["gold_litter"]=host._material(Color(.48,.30,.09))
    host.materials["flower_cream"]=host._material(Color(.62,.59,.38))
    host.materials["flower_lilac"]=host._material(Color(.36,.30,.46))
    var flower := SphereMesh.new()
    flower.radius=.5
    flower.height=.3
    flower.radial_segments=6
    flower.rings=3
    host.meshes["wildflower"]=flower
    var pebble := SphereMesh.new()
    pebble.radius=.5
    pebble.height=1
    pebble.radial_segments=7
    pebble.rings=3
    host.meshes["path_pebble"]=pebble
    var random := RandomNumberGenerator.new()
    random.seed=1201026
    for section in range(1,Data.PATH_CELLS.size()):
        var a := Data.cell_center_world(Data.PATH_CELLS[section-1])
        var b := Data.cell_center_world(Data.PATH_CELLS[section])
        var tangent := a.direction_to(b)
        var side := tangent.cross(Vector3.UP)
        var steps := ceili(a.distance_to(b)/.55)
        for i in range(steps):
            var along := a.lerp(b,(i+.5)/steps)
            for sign_: float in [-1,1]:
                var edge := along+side*sign_*random.randf_range(1.0,1.25)
                if not _safe(edge): continue
                if i%3==0:
                    host._batch("path_pebble","stone_dark",edge+Vector3.UP*.035,Vector3(.26,.07,.13),Basis(Vector3.UP,random.randf()*TAU))
                for j in range(2):
                    var p := edge+Vector3(random.randf_range(-.36,.36),.029,random.randf_range(-.36,.36))
                    if not _safe(p): continue
                    var golden := Data.episode_at(p)==3
                    host._batch("fallen_leaf","gold_litter" if golden else "leaf_litter",p,Vector3.ONE*random.randf_range(.10,.23),Basis(Vector3.UP,random.randf()*TAU))
                if section in [2,8,9,10,11,23,24] and i%4==0:
                    var flower_at := edge+side*sign_*.24
                    if not _safe(flower_at): continue
                    for petal in range(5):
                        var at := flower_at+Vector3(cos(petal*TAU/5)*.036,.15,sin(petal*TAU/5)*.036)
                        host._batch("wildflower","flower_cream" if section>20 else "flower_lilac",at,Vector3(.085,.045,.085))
                    host._batch("box","hedge",flower_at+Vector3.UP*.075,Vector3(.018,.15,.018))
static func _safe(p: Vector3) -> bool:
    var cell := Data.world_to_cell(p.x,p.z)
    return cell.x>=0 and cell.x<Data.MAP_WIDTH and cell.y>=0 and cell.y<Data.MAP_HEIGHT and Data.CANONICAL_MAP[cell.y][cell.x]=="." and not Props.contains_point(p+Vector3.UP*.3,.14)
