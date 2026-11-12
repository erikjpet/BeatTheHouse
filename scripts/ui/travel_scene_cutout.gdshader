shader_type canvas_item;
render_mode unshaded;

// Generated PNG bytes remain untouched. Near-opaque painted surfaces must
// occlude the far backdrop, while real cutouts and soft edges stay transparent.
uniform float solid_alpha_threshold : hint_range(0.5, 1.0) = 0.95;
varying vec4 cutout_tint;

void vertex() {
	cutout_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * cutout_tint;
	if (pixel.a <= 2.0 / 255.0) {
		pixel.a = 0.0;
	} else if (pixel.a >= solid_alpha_threshold) {
		pixel.a = 1.0;
	}
	COLOR = pixel;
}
