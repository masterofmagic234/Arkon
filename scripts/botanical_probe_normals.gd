extends CompositorEffect
## Diagnostic-only: request the same resolved normal/depth prepass as SSAO,
## without running the AO compute/filter passes. No scene or pixels are edited.
func _init() -> void:
    effect_callback_type=CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_OPAQUE
    needs_normal_roughness=true
    access_resolved_depth=true
func _render_callback(_type: int,_data: RenderData) -> void:
    pass
