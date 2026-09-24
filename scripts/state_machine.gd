extends RefCounted
class_name StateMachine

var states: Dictionary = {}
var current_id = null
var current_state: CallableState = null

func add_state(state_id, state: CallableState) -> void:
    states[state_id] = state

func transition(next_id) -> void:
    if current_id == next_id:
        return
    if current_state != null:
        current_state.exit()
    current_id = next_id
    current_state = states.get(next_id) as CallableState
    if current_state != null:
        current_state.enter()

func update(delta: float) -> void:
    if current_state != null:
        current_state.update(delta)
