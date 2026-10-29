shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/cinematics/pajamas151.gdshaderinc"
uniform float seated : hint_range(0.0,1.0) = 0.0;
varying vec4 modulation;
void vertex() { modulation = COLOR; }
void fragment() {
    vec4 image = texture(TEXTURE,UV);
    COLOR = vec4(garment_colour151(UV,image.rgb,seated),image.a)*modulation;
}
