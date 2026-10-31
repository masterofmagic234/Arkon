extends SceneTree
## Native render proof of the internal 3D framebuffer, not a phone benchmark.
## An intentionally pixel-coordinate-based spatial shader makes the internal
## width/height observable after upscaling; 2D stripes remain full resolution.
class PixelMarker:
    extends Node2D
    func _draw() -> void:
        for x in range(32):
            draw_rect(Rect2(16+x,16,1,16),Color.WHITE if x%2==0 else Color.BLACK)

const SIZE := Vector2i(640,360)
var output := "/tmp/graphics-render-scale156"
var failures: Array[String]=[]
var report: Dictionary={"scope":"Native Compatibility render of a controlled spatial shader and full-resolution canvas stripes. Internal pixel dimensions and logical camera invariants, not physical Redmi performance or GPU timing.","samples":[],"failures":[]}
var target: SubViewport
var camera: Camera3D
var decode_srgb := false

func _init() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    call_deferred("run")

func check(value: bool,message: String) -> void:
    if not value:
        failures.append(message)
        push_error("GRAPHICS RENDER SCALE156: "+message)

func frames(count: int=3) -> void:
    for i in range(count):await process_frame

func render() -> Image:
    target.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    for node in target.find_children("*","Node3D",true,false):
        (node as Node3D).force_update_transform()
    await frames(3)
    RenderingServer.force_draw(true)
    await frames(2)
    RenderingServer.force_draw(true)
    return target.get_texture().get_image()

func probes() -> Array[Vector2]:
    var points: Array[Vector2]=[]
    for point in [Vector3(-1,.5,0),Vector3(0,-.6,0),Vector3(1,0,0)]:
        points.append(camera.unproject_position(point))
    return points

func run() -> void:
    DirAccess.make_dir_recursive_absolute(output)
    if DisplayServer.get_name()=="headless":
        push_error("GRAPHICS RENDER SCALE156 requires native graphics")
        quit(1)
        return
    report["engine"]=Engine.get_version_info()
    report["renderer"]=RenderingServer.get_current_rendering_method()
    report["driver"]=RenderingServer.get_current_rendering_driver_name()
    report["adapter"]=RenderingServer.get_video_adapter_name()
    check(report.renderer=="gl_compatibility","Requires actual Compatibility backend")
    root.size=SIZE
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_render_loop_enabled(false)
    target=SubViewport.new()
    target.name="GraphicsScale156Probe"
    target.size=SIZE
    target.own_world_3d=true
    target.transparent_bg=false
    target.msaa_3d=Viewport.MSAA_DISABLED
    target.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
    target.scaling_3d_scale=1.0
    root.add_child(target)
    var environment:=WorldEnvironment.new()
    var settings:=Environment.new()
    settings.background_mode=Environment.BG_COLOR
    settings.background_color=Color.BLACK
    settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
    environment.environment=settings
    target.add_child(environment)
    camera=Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=4.0
    camera.position=Vector3(0,0,5)
    camera.near=.05
    camera.far=20
    target.add_child(camera)
    camera.make_current()
    var surface:=MeshInstance3D.new()
    var quad:=QuadMesh.new()
    quad.size=Vector2(10,10)
    surface.mesh=quad
    var shader:=Shader.new()
    # Keep the probes above the dark region where Compatibility's approximate
    # color conversion loses precision. Each channel remains a direct measure
    # of a different native framebuffer coordinate, not a shader scale uniform.
    shader.code="shader_type spatial; render_mode unshaded,cull_disabled,fog_disabled; void fragment(){ ALBEDO=vec3(FRAGCOORD.x/640.0,FRAGCOORD.y/360.0,VIEWPORT_SIZE.x/1280.0); }"
    var material:=ShaderMaterial.new()
    material.shader=shader
    surface.material_override=material
    target.add_child(surface)
    var canvas:=CanvasLayer.new()
    target.add_child(canvas)
    canvas.add_child(PixelMarker.new())
    await frames(4)
    var expected_projection:=probes()
    var expected_transform:=camera.global_transform
    for scale: float in [1.0,.75,.5]:
        target.scaling_3d_scale=scale
        var image: Image=await render()
        check(image!=null and image.get_size()==SIZE,"Logical target size changed atscale"+str(scale))
        if image==null:continue
        check(image.save_png(output.path_join("internal-scale-"+str(roundi(scale*100))+".png"))==OK,"Could not save native scale image")
        var raw:=image.get_pixel(SIZE.x/2,SIZE.y/2)
        if scale==1.0:
            # Compatibility final images can expose an sRGB or linear target.
            # Determine the transfer function from the controlled blue channel.
            decode_srgb=absf(raw.srgb_to_linear().b-SIZE.x/1280.0)<absf(raw.b-SIZE.x/1280.0)
        var decoded:=raw.srgb_to_linear() if decode_srgb else raw
        var expected_x:=float(SIZE.x)*.5*scale
        var expected_y:=float(SIZE.y)*.5*scale
        var measured_x:=decoded.r*640.0
        var measured_y:=decoded.g*360.0
        check(absf(measured_x-expected_x)<4.0,"FRAGCOORD.x did not expose reduced internal width atscale"+str(scale)+": "+str(measured_x))
        check(absf(measured_y-expected_y)<4.0,"FRAGCOORD.y did not expose reduced internal height atscale"+str(scale)+": "+str(measured_y))
        check(absf(decoded.b*1280.0-float(SIZE.x)*scale)<6.0,"VIEWPORT_SIZE did not expose reduced internal width atscale"+str(scale))
        var crisp:=0
        for x in range(32):
            var color:=image.get_pixel(16+x,22)
            if (x%2==0 and color.r>.95 and color.g>.95 and color.b>.95) or (x%2==1 and color.r<.05 and color.g<.05 and color.b<.05):crisp+=1
        check(crisp==32,"3D scaling blurred or moved the one-pixel 2D canvas marker")
        var projection:=probes()
        var error:=0.0
        for i in range(expected_projection.size()):error=maxf(error,projection[i].distance_to(expected_projection[i]))
        check(error<.01,"Logical camera projection changed with internal scale")
        check(camera.global_transform==expected_transform,"Scale changed the camera transform")
        report.samples.append({"requested_scale":scale,"logical_target_size":[image.get_width(),image.get_height()],"raw_rgba":[raw.r,raw.g,raw.b,raw.a],"transfer":"srgb_to_linear" if decode_srgb else "linear","measured_internal_center_fragcoord":[measured_x,measured_y],"expected_internal_center":[expected_x,expected_y],"viewport_size_blue_pixels":decoded.b*1280.0,"crisp_2d_stripes":crisp,"maximum_logical_projection_error_pixels":error})
    report["failures"]=failures
    report["result"]="PASS" if failures.is_empty() else "FAIL"
    var report_file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
    check(report_file!=null,"Could not save native scale report")
    if report_file!=null:report_file.store_string(JSON.stringify(report,"  "))
    target.queue_free()
    await frames(4)
    print("GRAPHICS RENDER SCALE156: "+report.result)
    quit(0 if failures.is_empty() else 1)
