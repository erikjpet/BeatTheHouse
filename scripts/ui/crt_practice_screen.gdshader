shader_type canvas_item;
render_mode unshaded;

// CrtPracticeMenu inverts precisely these operations for mouse/touch hit tests.
// Animated displacement is CPU-owned; there is no independent shader TIME.
uniform float curvature = 0.055;
uniform float corner_radius = 0.065;
uniform bool reduce_motion = false;
uniform vec2 jitter = vec2(0.0);
uniform float ripple_phase = 0.0;
uniform float ripple_strength = 0.0;
uniform float scan_phase = 0.0;
uniform float roll_phase = 0.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	vec2 sample_uv = centered * (1.0 + curvature * dot(centered, centered)) * 0.5 + 0.5;
	if (!reduce_motion) {
		sample_uv += jitter;
		sample_uv.x += sin(UV.y * 149.0 + ripple_phase) * ripple_strength;
	}
	vec2 corner = abs(UV - 0.5) - vec2(0.5 - corner_radius);
	float rounded = length(max(corner, vec2(0.0)));
	bool outside = rounded > corner_radius || sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0;
	vec3 image = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0))).rgb;
	// Restrained phosphor fringe and slowly drifting lines keep captions clear.
	float red = texture(TEXTURE, clamp(sample_uv + vec2(0.00035, 0.0), vec2(0.0), vec2(1.0))).r;
	float blue = texture(TEXTURE, clamp(sample_uv - vec2(0.00035, 0.0), vec2(0.0), vec2(1.0))).b;
	image = mix(image, vec3(red, image.g, blue), 0.35);
	float scanline = 0.94 + 0.06 * cos(sample_uv.y * 576.0 * 3.14159265 - (reduce_motion ? 0.0 : scan_phase));
	// A broad, low-contrast roll travels down the glass every 8.3 seconds.
	// Periodic distance wraps smoothly; no flash, hard edge or geometry shift.
	float roll_distance = abs(fract(sample_uv.y - roll_phase + 0.5) - 0.5);
	float roll = reduce_motion ? 1.0 : 1.0 - 0.035 * (1.0 - smoothstep(0.0, 0.16, roll_distance));
	float vignette = 1.0 - 0.16 * dot(centered * 0.70, centered * 0.70);
	float reflection = 0.025 * pow(max(0.0, 1.0 - length((UV - vec2(0.28, 0.15)) * vec2(1.3, 2.0))), 3.0);
	COLOR = outside ? vec4(0.025, 0.018, 0.035, 1.0) : vec4(image * scanline * roll * vignette + reflection, 1.0);
}
