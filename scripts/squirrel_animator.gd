extends RefCounted

# Procedural micro-animation for squirrel billboards.
# Presentation only: no gameplay state or movement is changed.
# Bob + squash/stretch + roll. Yaw is intentionally omitted because these
# squirrels are billboard QuadMesh sprites and their camera-facing orientation
# should remain untouched.

const STATE_STUNNED := 4

const BOB_FREQ_MIN := 6.0
const BOB_FREQ_MAX := 10.0
const SQUASH_AMOUNT := 0.045
const ROLL_AMOUNT := 0.05
const SPEED_FOR_MAX_INTENSITY := 5.0

static func apply(node: MeshInstance3D, phase: float, state: int,
        speed: float, _direction: Vector3, _dt: float) -> void:
    if node == null or not (node.mesh is QuadMesh):
        return

    if state == STATE_STUNNED:
        node.scale = Vector3(1.0, 0.78, 1.0)
        node.rotation.z = deg_to_rad(-7.0)
        return

    var t := Time.get_ticks_msec() * 0.001
    var intensity: float = clampf(speed / SPEED_FOR_MAX_INTENSITY, 0.0, 1.0)
    var freq: float = BOB_FREQ_MIN + intensity * (BOB_FREQ_MAX - BOB_FREQ_MIN)
    var bob: float = sin(t * freq + phase)

    var squash: float = bob * SQUASH_AMOUNT * intensity
    node.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0)
    node.rotation.z = bob * ROLL_AMOUNT * (0.4 + intensity * 0.6)
