extends "res://tools/botanical_renderer_capture.gd"
## Close views of the reported 1.42 defects, using the real production scene.
func poses() -> Array:
    var result=[
        ["p60-142",Vector3(2,4.7,10.9),Vector3(7,40.7,0)],
        ["stairs",Vector3(14,3.3,43),Vector3(24,2,31)],
        ["water",Vector3(0,5.2,31),Vector3(0,3,20)],
        ["bench",Vector3(-5,1.6,59),Vector3(-9,.65,56.5)],
        ["bed",Vector3(12,1.9,55),Vector3(17,1.1,52)],
    ]
    for kind in [3,4,5]:
        var closest={};var distance=INF
        for record in current_scene.world.placement_records:
            if record.kind!="ground_plant" or record.plant_type!=kind:continue
            var d=Vector2(record.root.x,record.root.z).distance_squared_to(Vector2(30,50))
            if d<distance:closest=record;distance=d
        var p: Vector3=closest.root
        result.append(["herb%d"%kind,p+Vector3(1.2,1.1,1.6),p+Vector3.UP*.35])
    return result
