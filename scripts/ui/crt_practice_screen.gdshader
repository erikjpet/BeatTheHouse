shader_type canvas_item;
render_mode unshaded;

// CrtPracticeMenu inverts precisely these operations for mouse/touch hit tests.
// Animated displacement is CPU-owned; there is no independent shader TIME.
uniform float curvature = 0.055;
uniform float corner_radius = 0.065;
uniform vec4 glass_displacement = vec4(0.0);
uniform vec2 roll_band = vec2(1.18, 0.0);

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	vec2 sample_uv = centered * (1.0 + curvature * dot(centered, centered)) * 0.5 + 0.5;
	sample_uv += glass_displacement.xy;
	sample_uv.x += sin(UV.y * 149.0 + glass_displacement.z) * glass_displacement.w;
	vec2 corner = abs(UV - 0.5) - vec2(0.5 - corner_radius);
	float rounded = length(max(corner, vec2(0.0)));
	bool outside = rounded > corner_radius || sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0;
	vec3 image = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0))).rgb;
	// Restrained phosphor fringe keeps captions clear.
	float red = texture(TEXTURE, clamp(sample_uv + vec2(0.00035, 0.0), vec2(0.0), vec2(1.0))).r;
	float blue = texture(TEXTURE, clamp(sample_uv - vec2(0.00035, 0.0), vec2(0.0), vec2(1.0))).b;
	image = mix(image, vec3(red, image.g, blue), 0.35);
	// Keep at least three output pixels per phosphor line, including small TVs.
	// Fixed subpixel lines averaged away when the glass was scaled down.
	float line_count = min(192.0, 1.0 / max(fwidth(sample_uv.y) * 3.0, 0.0001));
	float scanline = 0.91 + 0.09 * cos(sample_uv.y * line_count * 6.2831853);
	// A soft camera-like dark roll carries several uneven pronounced lines.
	// The CPU moves it completely off either edge between intermittent passes.
	// Luminance alone changes: text, curved clipping and hit targets do not move.
	float roll = 1.0;
	if (roll_band.y > 0.0) {
		float roll_distance = sample_uv.y - roll_band.x;
		float envelope = 1.0 - smoothstep(0.055, 0.15, abs(roll_distance));
		float band_lines = 0.5 + 0.5 * cos(roll_distance * 24.0 * 6.2831853);
		float uneven = 0.82 + 0.18 * cos(roll_distance * 13.0 * 6.2831853 + 0.7);
		roll -= envelope * (0.12 + 0.30 * band_lines * uneven);
	}
	float vignette = 1.0 - 0.16 * dot(centered * 0.70, centered * 0.70);
	float reflection = 0.025 * pow(max(0.0, 1.0 - length((UV - vec2(0.28, 0.15)) * vec2(1.3, 2.0))), 3.0);
	COLOR = outside ? vec4(0.025, 0.018, 0.035, 1.0) : vec4(image * scanline * roll * vignette + reflection, 1.0);
}
