extends RefCounted
## The 1.40 garden in GL. Keep authored assets/lightmaps; compensate for the
## sRGB additive-light and HDR differences with a restrained environment grade.
const EXPOSURE=.75
static func active() -> bool:
    return RenderingServer.get_current_rendering_method()=="gl_compatibility"
static func configure_environment(environment: Environment) -> void:
    if not active():return
    # The background is independent of the reduced surface-light exposure.
    environment.background_energy_multiplier=1.0/EXPOSURE
    environment.adjustment_enabled=true
    environment.adjustment_brightness=1.0
    environment.adjustment_contrast=.8
    environment.adjustment_saturation=.85
static func configure_camera(camera: Camera3D) -> void:
    if not active():return
    var attributes=CameraAttributesPractical.new()
    attributes.exposure_multiplier=EXPOSURE
    camera.attributes=attributes
