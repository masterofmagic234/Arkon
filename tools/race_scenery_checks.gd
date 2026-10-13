extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")

static func portal_geometry(host) -> String:
    # A segment through the driveable opening must remain clear. Segments
    # through the rock on either side and above the vault must meet a face.
    for z: float in [Data.TUNNEL_START,Data.TUNNEL_END]:
        var center := Math.track_center_x(z/40,host.track_x)
        for offset: Vector2 in [Vector2(0,2),Vector2(-12,2),Vector2(12,2),Vector2(0,10)]:
            var a := Vector3(center+offset.x,Data.road_height(z)+offset.y,z-10)
            var b := a+Vector3(0,0,30)
            var hit := false
            for group in host.scenery.groups.values():
                if absf(float(group.z)-z)>150: continue
                var points: PackedVector3Array=group.points
                for face in group.faces:
                    var ids: PackedInt32Array=face.indices
                    if Geometry3D.segment_intersects_triangle(a,b,points[ids[0]],points[ids[1]],points[ids[2]])!=null:
                        hit=true;break
                if hit: break
            if hit==(offset==Vector2(0,2)):
                return "The mountain blocks its opening or has no solid rock around the portal"
    return ""

static func frame_geometry(host, dimensions: Vector2) -> String:
    var scenery=host.scenery
    scenery.begin(host,dimensions);scenery.draw(host,dimensions)
    if scenery.triangles>2400 or scenery.transformed_vertices>4000:
        return "Scenery exceeds its per-frame geometry budget"
    var surfaces := 0
    for batch in [scenery.opaque]+scenery.textures.values()+scenery.foreground.values():
        surfaces+=batch.mesh.get_surface_count()
        for point: Vector3 in batch.vertices:
            if not point.is_finite() or point.x<-.02 or point.y<-.02 or point.x>dimensions.x+.02 or point.y>dimensions.y*host.PLAYFIELD_FRACTION+.02:
                return "A passing scenery connector escaped the clipped viewport"
    if surfaces>9:
        return "Scenery fragments into too many mesh submissions"
    for color: Color in scenery.opaque.colors:
        if color.a<.999: return "A tunnel or mountain face has become transparent"
    # The optimized transform must agree with the shared car/ground camera.
    var z: float=host.player_car.world_z+60
    var p := Vector3(float(host.player_car.world_x)+6,2,z)
    var expected: Vector2=host._project_camera_point(host._camera_point(p),dimensions)
    var camera: Vector3=scenery.frame.transform*(p+Vector3.UP*Data.road_height(z))
    if scenery.frame.project(camera).distance_to(expected)>.15:
        return "Cached scenery projection diverges from the vehicle camera"
    return ""
