extends Node2D
## One world-space story target, using the same phase/position authority as
## ACTION and automatic boarding. It never marks an unavailable story beat.
const Story = preload("res://scripts/level3_story.gd")
const Data = preload("res://scripts/level3_store_data.gd")
var world: Node2D
var target_kind: StringName = &""
var target_position := Vector2.ZERO
var clock := 0.0

func _ready() -> void:
    name = "InteractionArrow"
    z_index = 30
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var ink := CanvasItemMaterial.new()
    ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    material = ink
    # The red marker replaces the old floating word, not another layer of text
    # over the same pizza. Keep the physical pizza sprite and its soft glow.
    for child in world.environment.order_marker.get_children():
        if child is Label: child.hide()
    hide()

func resolve_target() -> Dictionary:
    if world == null or not is_instance_valid(world.mission): return {}
    if world._player_dead or world._level_complete_started or world.mission.controls_locked(): return {}
    match world.mission.phase:
        &"street": return {"kind":&"reception","position":Story.RECEPTION}
        &"kitchen", &"cleared": return {"kind":&"chef","position":world.mission.chef.global_position}
        &"pizza":
            if not world.order_collected and world._enemies_alive==0:
                return {"kind":&"order","position":world._scaled_cell_world(Data.ORDER_CELL)}
        &"exit":
            if world.order_collected and not world.mission.boarding_started:
                return {"kind":&"car","position":world.mission.car.global_position}
    return {}

func _process(delta: float) -> void:
    var target := resolve_target()
    if target.is_empty():
        target_kind = &""
        hide()
        return
    target_kind = target.kind
    target_position = target.position
    # Screen-up bob, not the actor's aim direction. Modest 3.4px at 1.7x.
    clock = fmod(clock+delta,TAU)
    position = target_position+Vector2(0,-17-roundf(sin(clock*4.0)*2.0))
    show()
    queue_redraw()

func _draw() -> void:
    # Chunky 1px ink outline; the tip identifies the object below it.
    draw_colored_polygon(PackedVector2Array([Vector2(-3,-12),Vector2(3,-12),Vector2(3,-7),Vector2(7,-7),Vector2(0,1),Vector2(-7,-7),Vector2(-3,-7)]),Color("171318"))
    draw_colored_polygon(PackedVector2Array([Vector2(-2,-11),Vector2(2,-11),Vector2(2,-6),Vector2(5,-6),Vector2(0,-1),Vector2(-5,-6),Vector2(-2,-6)]),Color("f13248"))
    draw_line(Vector2(-1,-10),Vector2(-1,-6),Color("ff7a7d"),1)
