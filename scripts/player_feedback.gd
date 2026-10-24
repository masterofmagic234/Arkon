extends Control
# Shared, scene-owned feedback. Signals carry the actual damage source; no
# camera motion, time scaling or input changes are introduced by a hit.
var actor: Node
var damage_strength := 0.0
var heal_strength := 0.0
var hit_strength := 0.0
var _source_position: Variant
var _previous_health := 100

func bind(player: Node) -> void:
    actor=player
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index=90
    var bus := get_node("/root/SignalBus")
    bus.entity_damaged.connect(_damage)
    bus.health_changed.connect(_health)
    bus.combat_event.connect(_combat)
    _previous_health=actor.get_hp() if actor.has_method("get_hp") else actor.health

func _damage(entity: Node, amount: int, source: Node) -> void:
    if entity!=actor: return
    damage_strength=minf(1.0,.48+amount/70.0)
    _source_position=source.global_position if is_instance_valid(source) and (source is Node2D or source is Node3D) else null
    queue_redraw()
func _health(entity: Node, current: int, _maximum: int) -> void:
    if entity!=actor: return
    if current>_previous_health: heal_strength=.55
    _previous_health=current
func _combat(kind: StringName, _at: Vector2) -> void:
    if actor is Node3D and kind==&"weapon_hit": confirm_hit()
func confirm_hit() -> void:
    hit_strength=1.0
    queue_redraw()
func _process(delta: float) -> void:
    if damage_strength<=0 and heal_strength<=0 and hit_strength<=0: return
    damage_strength=maxf(0,damage_strength-delta*1.6)
    heal_strength=maxf(0,heal_strength-delta)
    hit_strength=maxf(0,hit_strength-delta*5)
    queue_redraw()
func _draw() -> void:
    var v := get_viewport_rect().size
    var center := v*.5
    if damage_strength>0:
        var color := Color(.77,.18,.12,damage_strength*.28)
        # Translucent edges leave the playable centre unobscured.
        for i in range(5):
            var width := 9.0+i*6
            var c := Color(color,color.a*(1.0-i*.18))
            draw_rect(Rect2(Vector2.ONE*width,v-Vector2.ONE*width*2),c,false,6)
        if _source_position!=null and is_instance_valid(actor):
            var angle := 0.0
            if actor is Node3D:
                var relative: Vector3=actor.global_basis.inverse()*(_source_position-actor.global_position)
                angle=Vector2(relative.x,relative.z).angle()
            else: angle=(_source_position-actor.global_position).angle()
            draw_arc(center,61,angle-.30,angle+.30,14,Color(1,.39,.24,damage_strength),3,true)
    if heal_strength>0: draw_rect(Rect2(3,3,v.x-6,v.y-6),Color(.43,.8,.59,heal_strength*.5),false,3)
    if hit_strength>0 and actor is Node3D:
        for d: Vector2 in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
            draw_line(center+d*7,center+d*12,Color(1,.82,.46,hit_strength),2,true)
