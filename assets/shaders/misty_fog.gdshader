shader_type canvas_item;
render_mode unshaded;

uniform vec4 mist_color : source_color = vec4(0.76, 0.83, 0.86, 1.0);
uniform float max_opacity : hint_range(0.0, 0.5) = 0.18;
uniform float drift_speed : hint_range(0.0, 2.0) = 1.0;
uniform vec2 field_offset = vec2(0.0, 0.0);
uniform float source_line_y : hint_range(-1.0, 1.0) = -1.0;
uniform float source_fade_height : hint_range(0.01, 1.0) = 0.30;
uniform float source_edge_fade : hint_range(0.0, 0.15) = 0.045;

float hash_2d(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);

	float bottom_left = hash_2d(cell);
	float bottom_right = hash_2d(cell + vec2(1.0, 0.0));
	float top_left = hash_2d(cell + vec2(0.0, 1.0));
	float top_right = hash_2d(cell + vec2(1.0, 1.0));

	float bottom = mix(bottom_left, bottom_right, fraction.x);
	float top = mix(top_left, top_right, fraction.x);
	return mix(bottom, top, fraction.y);
}

float fractal_noise(vec2 point) {
	float total = 0.0;
	float amplitude = 0.5;
	float amplitude_total = 0.0;
	mat2 octave_transform = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6));

	for (int octave = 0; octave < 5; octave++) {
		total += value_noise(point) * amplitude;
		amplitude_total += amplitude;
		point = octave_transform * point + vec2(17.13, 9.27);
		amplitude *= 0.5;
	}

	return total / amplitude_total;
}

void fragment() {
	float aspect_ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 point = vec2(UV.x * aspect_ratio, UV.y) * vec2(3.6, 2.4) + field_offset;
	float time = TIME * drift_speed;

	// Sampling the moving field toward the lower right makes the visible fog drift up and left.
	vec2 drift = time * vec2(0.035, 0.026);
	vec2 warp_point = point * 0.72 + drift * 0.52;
	vec2 warp = vec2(
		fractal_noise(warp_point + vec2(4.7, 1.9)),
		fractal_noise(warp_point + vec2(9.2, 7.3))
	);

	// Slowly changing cross-flow bends the plumes into a gentle, sinuous motion.
	vec2 cross_flow = vec2(
		sin(point.y * 1.7 + time * 0.09),
		cos(point.x * 1.35 - time * 0.07)
	) * 0.12;
	vec2 cloud_point = point + drift + (warp - vec2(0.5)) * 1.05 + cross_flow;
	float broad_clouds = fractal_noise(cloud_point * 1.05);
	float fine_wisps = fractal_noise(cloud_point * 2.0 + vec2(3.8, 11.4));
	float cloud_density = broad_clouds * 0.72 + fine_wisps * 0.28;
	float cloud_shape = smoothstep(0.40, 0.68, cloud_density);
	float lower_haze = mix(0.55, 1.0, smoothstep(0.0, 0.92, UV.y));
	float source_mask = 1.0;
	if (source_line_y >= 0.0) {
		float rising_fog = smoothstep(source_line_y - source_fade_height, source_line_y, UV.y);
		float edge_limit = 1.0 - smoothstep(source_line_y, source_line_y + source_edge_fade, UV.y);
		source_mask = rising_fog * edge_limit;
	}
	float fog_alpha = cloud_shape * lower_haze * source_mask * max_opacity;

	COLOR = vec4(mist_color.rgb, fog_alpha);
}
