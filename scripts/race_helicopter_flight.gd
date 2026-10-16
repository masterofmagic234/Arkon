extends RefCounted
# Acceleration-limited cinematic flight, not a rigid-body aviation simulator.
# A C2 pass has explicit position/velocity/acceleration and a moving release;
# the rotor thrust balances gravity + drag + the required net acceleration.
# Hull attitude follows the rotor with a damped response, never phase presets.
const MIN_PASS_SECONDS := 8.0
const MAX_SPEED := 90.0
const MAX_ACCELERATION := 6.0
const MAX_JERK := 6.0
const GRAVITY := 9.81
const DRAG := .00055
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var thrust := Vector3.UP*GRAVITY
var duration := MIN_PASS_SECONDS
var yaw := 0.0
var pitch := 0.0
var bank := 0.0
var rotor_pitch := 0.0
var rotor_bank := 0.0
var collective := 1.0
var angular_velocity := Vector2.ZERO
var yaw_velocity := 0.0
var _coefficients: Array[Vector3]=[]

func plan(start: Vector3,landing: Vector3,fall: float,road_slope: float) -> void:
    duration=MIN_PASS_SECONDS
    # All limits apply to the complete pass, not independent easing sections.
    for iteration in range(8):
        # Carry real airspeed into the frame, then decelerate into the low
        # pass. Both endpoints have zero net acceleration; no hover snap.
        var forward: float=(landing.z-start.z)/(duration+fall*.85)
        var end_velocity:=Vector3(clampf(road_slope*forward*.85,-18,18),0,forward*.85)
        var release:=landing-end_velocity*fall
        _curve(start,release,Vector3(0,0,forward*1.10),end_velocity)
        var scale_:=1.0
        for sample in range(33):
            var u:=float(sample)/32
            scale_=maxf(scale_,_velocity(u).length()/MAX_SPEED)
            scale_=maxf(scale_,sqrt(_acceleration(u).length()/MAX_ACCELERATION))
            scale_=maxf(scale_,pow(_jerk(u).length()/MAX_JERK,1.0/3.0))
        if scale_<=1.001: break
        duration*=scale_*1.015
    position=start;velocity=_velocity(0);acceleration=Vector3.ZERO
    yaw=atan2(velocity.x,velocity.z);angular_velocity=Vector2.ZERO;yaw_velocity=0
    _forces()
    pitch=rotor_pitch;bank=rotor_bank

func _curve(a: Vector3,b: Vector3,va: Vector3,vb: Vector3) -> void:
    var distance:=b-a;var first:=va*duration;var last:=vb*duration
    _coefficients=[a,first,10*distance-6*first-4*last,-15*distance+8*first+7*last,6*distance-3*first-3*last]

func _velocity(u: float) -> Vector3:
    return (_coefficients[1]+3*_coefficients[2]*u*u+4*_coefficients[3]*pow(u,3)+5*_coefficients[4]*pow(u,4))/duration
func _acceleration(u: float) -> Vector3:
    return (6*_coefficients[2]*u+12*_coefficients[3]*u*u+20*_coefficients[4]*pow(u,3))/(duration*duration)
func _jerk(u: float) -> Vector3:
    return (6*_coefficients[2]+24*_coefficients[3]*u+60*_coefficients[4]*u*u)/pow(duration,3)

func pass_at(time: float,delta: float) -> void:
    var u:=clampf(time/duration,0,1)
    position=_coefficients[0]+_coefficients[1]*u+_coefficients[2]*pow(u,3)+_coefficients[3]*pow(u,4)+_coefficients[4]*pow(u,5)
    velocity=_velocity(u);acceleration=_acceleration(u)
    _attitude(delta)

func coast(delta: float) -> void:
    position+=velocity*delta;acceleration=Vector3.ZERO
    _attitude(delta)

func depart(delta: float,side: float,player_speed: float) -> void:
    var desired:=Vector3(side*26,5.5,minf(90,maxf(velocity.z,player_speed+22))).limit_length(MAX_SPEED)
    var target_acceleration:=((desired-velocity)/1.7).limit_length(MAX_ACCELERATION)
    acceleration=acceleration.move_toward(target_acceleration,MAX_JERK*delta)
    position+=velocity*delta+acceleration*delta*delta*.5
    velocity+=acceleration*delta
    _attitude(delta)

func _forces() -> void:
    var drag:=Vector3(velocity.x*absf(velocity.x),velocity.y*absf(velocity.y),velocity.z*absf(velocity.z))*DRAG
    thrust=acceleration+drag+Vector3.UP*GRAVITY
    var local: Vector3=Basis(Vector3.UP,-yaw)*thrust
    rotor_pitch=atan2(local.z,local.y)
    rotor_bank=-atan2(local.x,sqrt(local.y*local.y+local.z*local.z))
    collective=thrust.length()/GRAVITY

func _attitude(delta: float) -> void:
    # A weathercock/yaw actuator has angular inertia too; it cannot snap to
    # the next road heading while the fuselage is still travelling sideways.
    var desired:=atan2(velocity.x,velocity.z)
    var yaw_acceleration:=clampf(angle_difference(yaw,desired)*9.0-yaw_velocity*6.0,-.65,.65)
    yaw_velocity=clampf(yaw_velocity+yaw_acceleration*delta,-.45,.45)
    yaw=wrapf(yaw+yaw_velocity*delta,-PI,PI)
    _forces()
    var error:=Vector2(rotor_pitch-pitch,rotor_bank-bank)
    angular_velocity+=(error*25.0-angular_velocity*9.0)*delta
    pitch+=angular_velocity.x*delta;bank+=angular_velocity.y*delta
