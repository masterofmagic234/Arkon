# EXPERIMENTAL — not yet wired to a measured hot allocation path.
# Before production use, add explicit reset/initialize and verify no state leaks.
class_name ObjectPool
extends RefCounted

var _scene: PackedScene
var _parent: Node
var _pool: Array[Node] = []
var _active: Array[Node] = []
var _capacity: int

func _init(scene: PackedScene, initial_capacity: int, parent: Node) -> void:
    _scene = scene
    _parent = parent
    _capacity = maxi(initial_capacity, 0)
    for _i in _capacity:
        var inst := _create_instance()
        if inst != null:
            _pool.append(inst)

func _create_instance() -> Node:
    if _scene == null or not is_instance_valid(_parent):
        return null
    var inst := _scene.instantiate() as Node
    if inst == null:
        return null
    inst.process_mode = Node.PROCESS_MODE_DISABLED
    if inst is CanvasItem:
        (inst as CanvasItem).visible = false
    elif inst is Node3D:
        (inst as Node3D).visible = false
    _parent.add_child(inst)
    return inst

func acquire() -> Node:
    var inst: Node = null
    if not _pool.is_empty():
        inst = _pool.pop_back()
    else:
        inst = _create_instance()
        if inst != null:
            _capacity += 1
    if inst == null:
        return null
    inst.process_mode = Node.PROCESS_MODE_INHERIT
    if inst is CanvasItem:
        (inst as CanvasItem).visible = true
    elif inst is Node3D:
        (inst as Node3D).visible = true
    _active.append(inst)
    return inst

func release(inst: Node) -> void:
    if inst == null or not _active.has(inst):
        return
    _active.erase(inst)
    if not is_instance_valid(inst):
        return
    inst.process_mode = Node.PROCESS_MODE_DISABLED
    if inst is CanvasItem:
        (inst as CanvasItem).visible = false
    elif inst is Node3D:
        (inst as Node3D).visible = false
    if inst is Node3D:
        (inst as Node3D).position = Vector3.ZERO
    elif inst is Node2D:
        (inst as Node2D).position = Vector2.ZERO
    elif inst is Control:
        (inst as Control).position = Vector2.ZERO
    _pool.append(inst)

func release_all() -> void:
    for inst in _active.duplicate():
        release(inst)

func active_count() -> int:
    return _active.size()

func capacity() -> int:
    return _capacity
