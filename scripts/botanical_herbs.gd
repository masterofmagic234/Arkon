@tool
extends RefCounted
## Opaque, genuinely three-dimensional undergrowth; no billboard/alpha pass.
## All LODs share one draw surface. Authored garden atlas supplies leaf detail.
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var uv:=PackedVector2Array()
var colors:=PackedColorArray()
var indices:=PackedInt32Array()
var tint:=Color.WHITE
func vertex(p: Vector3,n: Vector3,tex: Vector2) -> int:
    var id=vertices.size();vertices.append(p);normals.append(n);uv.append(tex);colors.append(tint);return id
func triangle(a: int,b: int,c: int) -> void:indices.append_array(PackedInt32Array([a,b,c]))
func leaf(a: Vector3,b: Vector3,width: float,flower:=false) -> void:
    var length_=(b-a).normalized();var side=length_.cross(Vector3.UP).normalized()
    if side.length_squared()<.01:side=Vector3.RIGHT
    var middle=a.lerp(b,.47);var n=side.cross(length_).normalized()
    if n.y<0:n=-n
    var center=middle+n*width*.35
    # A single broad leaf from the existing atlas, rather than a whole fern
    # printed on each leaflet. Petals use the center of one authored white petal.
    var texture_center=Vector2(.493,.86) if not flower else Vector2(.4974,.7695)
    var texture_scale=Vector2(.010,.018) if not flower else Vector2(.004,.006)
    var ids=[]
    var rim=[
        [a,Vector2(0,1)],
        [a.lerp(b,.25)-side*width*.72,Vector2(-.72,.5)],
        [middle-side*width,Vector2(-1,0)],
        [a.lerp(b,.74)-side*width*.65,Vector2(-.65,-.5)],
        [b,Vector2(0,-1)],
        [a.lerp(b,.74)+side*width*.65,Vector2(.65,-.5)],
        [middle+side*width,Vector2(1,0)],
        [a.lerp(b,.25)+side*width*.72,Vector2(.72,.5)],
        [center,Vector2.ZERO],
    ]
    for item in rim:
        ids.append(vertex(item[0],n,texture_center+item[1]*texture_scale))
    for i in range(8):triangle(ids[i],ids[(i+1)%8],ids[8])
func ribbon(a: Vector3,b: Vector3,bend: Vector3,width: float,steps: int) -> void:
    var side=(b-a).cross(Vector3.UP).normalized()
    if side.length_squared()<.01:side=Vector3.RIGHT
    var previous=[]
    for i in range(steps+1):
        var t=float(i)/steps;var p=a.lerp(b,t)+bend*(t*t)
        var n=side.cross((b-a)+bend*(2*t)).normalized()
        if n.y<0:n=-n
        var pair=[]
        for s in [-1,1]:pair.append(vertex(p+side*width*(1-t*.96)*s,n,Vector2(.713+s*.002,.73+t*.04)))
        if not previous.is_empty():triangle(previous[0],pair[0],previous[1]);triangle(previous[1],pair[0],pair[1])
        previous=pair
func flower(p: Vector3,radius: float,petals: int) -> void:
    tint=Color(1.12,1.05,.93)
    for i in range(petals):
        var angle=i*TAU/petals;var direction=Vector3(cos(angle),0,sin(angle))
        leaf(p,p+direction*radius+Vector3.UP*radius*.2,radius*.28,true)
    tint=Color(.9,.69,.2);leaf(p+Vector3(-radius*.22,.02,0),p+Vector3(radius*.22,.02,0),radius*.22,true)
func generate(kind: int,level: int) -> void:
    if kind==3:
        var fronds=[8,6,4,3][level];var pairs=[7,5,3,2][level]
        for f in range(fronds):
            var angle=f*TAU/fronds+.17;var radial=Vector3(cos(angle),0,sin(angle));var side=radial.cross(Vector3.UP)
            tint=Color(.82+f%3*.06,.94,.78)
            ribbon(Vector3.ZERO,radial*.72+Vector3.UP*.8,-Vector3.UP*.58,.012,3)
            for j in range(pairs):
                var t=.17+float(j)/pairs*.8
                var p=radial*(.72*t)+Vector3.UP*(.8*t-.58*t*t)
                var span=.22*(1-t*.72)
                for s in [-1,1]:leaf(p,p+side*(s*span)+radial*.1+Vector3.UP*.035,span*.25)
    elif kind==4:
        var stems=[17,12,8,5][level]
        for i in range(stems):
            var angle=i*2.399963;var radial=Vector3(cos(angle),0,sin(angle));var height=.42+float(i%4)*.1
            tint=Color(.74,.89,.70)
            ribbon(Vector3.ZERO,radial*.36+Vector3.UP*height,radial*.05,.012,2)
            for j in range([5,4,3,2][level]):
                var t=.24+j*.16;var p=radial*(.36*t)+Vector3.UP*(height*t)
                leaf(p,p+radial.rotated(Vector3.UP,(1 if j%2 else -1)*1.3)*.29+Vector3.UP*(.05+(j%3)*.025),.075)
            if i%2==0:flower(radial*.41+Vector3.UP*height,.10,[6,5,4,3][level])
    elif kind==5:
        var blades=[31,23,16,10][level]
        for i in range(blades):
            var a=i*2.399963;var radial=Vector3(cos(a),0,sin(a));var height=.55+(i%5)*.13
            tint=Color(.9+(i%3)*.04,.94,.67+(i%2)*.12)
            ribbon(radial*(.04+(i%4)*.025),radial*.23+Vector3.UP*height,radial*(.24+(i%3)*.08)-Vector3.UP*.16,.032,[4,3,3,2][level])
        for i in range([7,5,3,2][level]):
            var a=i*2.399963;var radial=Vector3(cos(a),0,sin(a));var top=radial*.36+Vector3.UP*(1.12+(i%3)*.12)
            tint=Color(.94,.84,.52);ribbon(Vector3.ZERO,top,radial*.07,.008,2)
            for j in range(4):
                var p=top+Vector3.UP*(j*.035)
                leaf(p,p+Vector3.UP*.12+radial*.025,.022)
    elif kind==6:flower(Vector3.ZERO,.45,[9,7,5,4][level])
func build(kind: int,quality_shift: int=0,two_sided_geometry: bool=false) -> ArrayMesh:
    vertices=PackedVector3Array();normals=PackedVector3Array();uv=PackedVector2Array();colors=PackedColorArray();indices=PackedInt32Array()
    var lods={};var base=PackedInt32Array()
    for level in range(4):
        indices=PackedInt32Array();generate(kind,mini(3,level+quality_shift))
        if two_sided_geometry:
            var front=indices.duplicate()
            for i in range(0,front.size(),3):indices.append_array(PackedInt32Array([front[i],front[i+2],front[i+1]]))
        if level==0:base=indices
        else:lods[[0.0,.01,.027,.065][level]]=indices
    var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=base
    var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods);mesh.set_meta("opaque_herb",true)
    mesh.set_meta("performance_quality_shift",quality_shift)
    mesh.set_meta("two_sided_geometry",two_sided_geometry)
    return mesh
