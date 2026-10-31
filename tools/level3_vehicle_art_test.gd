extends SceneTree
const Vehicle = preload("res://scripts/level3_vehicle_visual.gd")
var failures: Array[String] = []
func _init() -> void:call_deferred("_run")
func check(value: bool, why: String) -> void:
    if not value:failures.append(why);push_error("LEVEL3 VEHICLE ART: "+why)
func _run() -> void:
    var body := Image.load_from_file(ProjectSettings.globalize_path(Vehicle.CAR_BODY))
    var leaf := Image.load_from_file(ProjectSettings.globalize_path(Vehicle.CAR_DOOR))
    check(body != null and body.get_size()==Vector2i(107,70),"240 native body canvas changed")
    check(leaf != null and leaf.get_size()==Vector2i(33,12),"240 driver door is missing")
    if body==null or leaf==null:quit(1);return
    var mint := 0;var red := 0;var opaque := 0
    for y in range(body.get_height()):
        for x in range(body.get_width()):
            var color := body.get_pixel(x,y)
            check(color.a==0.0 or color.a==1.0,"240 sprite contains blended alpha")
            if color.a==0.0:continue
            opaque+=1
            if color.g>color.r*1.6 and color.b>color.r*1.3:mint+=1
            if color.r>color.g*1.7 and color.r>color.b*1.5:red+=1
    check(opaque>2000 and mint>250 and red>15,"real mint/black/red240livery missing")
    var car := Vehicle.new();car.kind="240";root.add_child(car)
    await process_frame
    check(car.body.texture!=null and car.body.texture.get_size()==Vector2(107,70),"runtime240 is not its native sprite")
    check(car.door_leaf!=null and car.door_leaf.texture!=null,"runtime car has no separate driver door")
    var hinge := car.door_pivot.position
    var closed_leaf := car.door_pivot.to_global(Vector2(-32,0))
    car.door_open_amount=1.0
    check(car.door_pivot.position==hinge,"car door hinge moved instead of rotating")
    check(car.door_pivot.to_global(Vector2(-32,0)).distance_to(closed_leaf)>25.0,"car door did not actually open")
    check(car.boarding_socket.y<car.inside_socket.y-15.0,"car boarding socket is inside the body")
    check(car.boarding_socket.x<car.door_pivot.to_global(Vector2(-32,0)).x-6,"boarding path intersects open door leaf")
    check(car.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"vehicle uses smoothed pixel filtering")
    var van := Vehicle.new();van.kind="van";root.add_child(van)
    await process_frame
    check(van._van_frames.size()==13,"clean van opening must have13frames")
    check(Vehicle.VAN_DOOR_FRAMES.ends_with("sprVanOpenDoor_strip13.png"),"human-containing van strip selected")
    var closed := van.body.texture
    van.door_open_amount=1.0
    check(van.body.texture!=closed,"van sliding door never changes")
    check(van.body.texture==van._van_frames[12],"van did not reach fully open frame")
    check(van.exit_socket.y< -26.0 and van.outside_socket.y<van.exit_socket.y,"van exit is not its north-side doorway")
    check(absf(van.exit_socket.x)<16.0,"van exits through wheel/cabin rather than central doorway")
    car.queue_free();van.queue_free();await process_frame
    if failures.is_empty():print("LEVEL3 VEHICLE ART: PASS — actual240livery, separate pivoting driverdoor, clean13framevan, coherent entry/exit sockets")
    quit(0 if failures.is_empty() else 1)
