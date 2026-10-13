extends RefCounted
# One camera transform per frame, rather than recomputing its basis, lens,
# terrain lookup and five frustum planes for every scenery triangle.
const NEAR := .8
var transform := Transform3D.IDENTITY
var lens := Transform2D.IDENTITY
var focal := 1.0
var vertical := 1.0
var pivot := Vector2.ZERO
var viewport := Rect2()
var planes: Array[Vector4] = []

func configure(host, size_: Vector2) -> void:
    var camera=host.camera_state
    var yaw: float=camera.yaw_offset
    var c := cos(yaw);var s := sin(yaw)
    var origin: float=host.player_car.world_z
    var x: float=host._camera_world_x(host.player_car.track_phase())
    var behind: float=host._behind()
    var grade: float=camera.road_grade
    var height: float=camera.road_height
    transform=Transform3D(Basis(Vector3(c,0,s),Vector3(0,1,0),Vector3(-s,-grade,c)),Vector3(-x*c+(origin-behind)*s,-height+origin*grade,-x*s+(-origin+behind)*c))
    lens=Transform2D(-float(camera.roll),Vector2.ZERO)
    focal=host.CAMERA_DEPTH*float(camera.zoom)*size_.x*host.ROAD_SCREEN_SCALE
    var h: float=size_.y*host.PLAYFIELD_FRACTION
    var horizon: float=host._horizon(h)
    vertical=(h-horizon)*host.CAMERA_BEHIND*float(camera.zoom)
    pivot=Vector2(size_.x*.5,horizon)
    viewport=Rect2(Vector2.ZERO,Vector2(size_.x,h))
    var cr := cos(float(camera.roll));var sr := sin(float(camera.roll))
    planes=[Vector4(0,0,1,-NEAR),Vector4(focal*cr,-focal*sr,pivot.x,vertical*sr),Vector4(-focal*cr,focal*sr,pivot.x,-vertical*sr),Vector4(-focal*sr,-focal*cr,horizon,vertical*cr),Vector4(focal*sr,focal*cr,h-horizon,-vertical*cr)]

func project(p: Vector3) -> Vector2:
    return pivot+(lens*Vector2(focal*p.x,vertical-focal*p.y))/p.z

func clip(points: Array[Vector3], all_planes: bool=false) -> Array[Vector3]:
    var result := points
    for plane in planes if all_planes else [planes[0]]:
        var output: Array[Vector3]=[]
        if result.is_empty(): break
        for i in range(result.size()):
            var a := result[i];var b := result[(i+1)%result.size()]
            var da := a.x*plane.x+a.y*plane.y+a.z*plane.z+plane.w
            var db := b.x*plane.x+b.y*plane.y+b.z*plane.z+plane.w
            if da>=0: output.append(a)
            if (da>=0)!=(db>=0): output.append(a.lerp(b,da/(da-db)))
        result=output
    return result
