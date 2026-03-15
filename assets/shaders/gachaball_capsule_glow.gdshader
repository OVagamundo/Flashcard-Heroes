shader_type canvas_item;
render_mode unshaded;

uniform vec4 target_color = vec4(1.0, 0.945098, 0.909804, 1.0);
uniform float tolerance : hint_range(0.0, 0.05) = 0.005;
uniform vec4 replacement_color = vec4(1.0, 0.937255, 0.901961, 1.0); // Keep this off the global glow key too.
uniform vec4 glow_color = vec4(1.0, 0.937255, 0.901961, 1.0); // Keep this off the global glow key too.
uniform vec2 source_pixel_size = vec2(1.0 / 96.0, 1.0 / 96.0);
uniform vec2 expansion = vec2(14.0, 14.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float falloff_power : hint_range(1.0, 4.0) = 3.0;

const int SAMPLE_COUNT = 7;
const float SPREAD = 2.0;

bool is_inside_texture(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

vec4 sample_base_color(vec2 uv) {
	if (!is_inside_texture(uv)) {
		return vec4(0.0);
	}

	vec4 tex_color = texture(TEXTURE, uv);
	if (tex_color.a <= 0.0) {
		return vec4(0.0);
	}

	if (distance(tex_color.rgb, target_color.rgb) <= tolerance) {
		tex_color.rgb = replacement_color.rgb;
	}

	return tex_color;
}

void vertex() {
	vec2 expand_dir = sign(UV - vec2(0.5));
	VERTEX += expand_dir * expansion;
	UV += expand_dir * (expansion * source_pixel_size);
}

void fragment() {
	vec4 base_color = sample_base_color(UV);
	float max_glow_weight = 0.0;

	for (int x = -SAMPLE_COUNT; x <= SAMPLE_COUNT; x++) {
		for (int y = -SAMPLE_COUNT; y <= SAMPLE_COUNT; y++) {
			vec2 offset = vec2(float(x), float(y)) * source_pixel_size * SPREAD;
			vec2 sample_uv = UV + offset;
			if (!is_inside_texture(sample_uv)) {
				continue;
			}

			vec4 sample_color = texture(TEXTURE, sample_uv);
			if (sample_color.a <= 0.0) {
				continue;
			}

			if (distance(sample_color.rgb, target_color.rgb) <= tolerance) {
				float d = length(vec2(float(x), float(y)) * SPREAD);
				float max_radius = float(SAMPLE_COUNT) * SPREAD;
				if (d <= max_radius) {
					float weight = 1.0 - (d / max_radius);
					max_glow_weight = max(max_glow_weight, weight * sample_color.a);
				}
			}
		}
	}

	float final_weight = pow(max_glow_weight, falloff_power);
	float glow_strength = final_weight * glow_intensity;
	vec3 final_rgb = min(vec3(1.0), base_color.rgb + (glow_color.rgb * glow_strength));
	float final_alpha = max(base_color.a, glow_strength);
	COLOR = vec4(final_rgb, final_alpha);
}
