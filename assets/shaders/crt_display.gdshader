shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float warp : hint_range(0.0, 0.2) = 0.028;
uniform float wobble_strength : hint_range(0.0, 0.001) = 0.00012;
uniform float wobble_speed : hint_range(0.0, 30.0) = 7.0;
uniform float wobble_frequency : hint_range(20.0, 300.0) = 120.0;
uniform float corner_fade : hint_range(0.3, 3.0) = 0.95;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.35;
uniform float mask_intensity : hint_range(0.0, 0.7) = 0.32;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.26;
uniform float scanline_thickness : hint_range(0.8, 3.0) = 1.35;
uniform float chroma_offset : hint_range(0.0, 0.01) = 0.0014;
uniform float ghost_strength : hint_range(0.0, 0.2) = 0.045;
uniform float bloom_strength : hint_range(0.0, 0.6) = 0.22;
uniform float bloom_threshold : hint_range(0.1, 1.5) = 0.6;
uniform float bloom_radius : hint_range(0.5, 4.0) = 1.7;
uniform float static_noise : hint_range(0.0, 0.1) = 0.015;
uniform float flicker_strength : hint_range(0.0, 0.05) = 0.012;
uniform float saturation_boost : hint_range(0.5, 1.6) = 1.06;
uniform float gamma_in : hint_range(1.6, 2.6) = 2.2;
uniform float gamma_out : hint_range(1.6, 2.6) = 2.2;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);


float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


vec2 warp_uv(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	float radius2 = dot(centered, centered);
	centered *= 1.0 + radius2 * warp;
	return centered * 0.5 + 0.5;
}


vec3 sample_phosphor(vec2 uv) {
	vec2 safe_uv = clamp(uv, vec2(0.0), vec2(1.0));
	float red = texture(screen_texture, clamp(safe_uv + vec2(chroma_offset, 0.0), vec2(0.0), vec2(1.0))).r;
	float green = texture(screen_texture, safe_uv).g;
	float blue = texture(screen_texture, clamp(safe_uv - vec2(chroma_offset, 0.0), vec2(0.0), vec2(1.0))).b;
	return vec3(red, green, blue);
}


void fragment() {
	vec2 curved_uv = warp_uv(SCREEN_UV);
	float bounds_mask = step(0.0, curved_uv.x) * step(curved_uv.x, 1.0) * step(0.0, curved_uv.y) * step(curved_uv.y, 1.0);
	vec2 bounded_uv = clamp(curved_uv, vec2(0.0), vec2(1.0));
	
	vec2 px = SCREEN_PIXEL_SIZE;
	float horizontal_jitter = sin(bounded_uv.y * wobble_frequency + TIME * wobble_speed) * wobble_strength;
	vec2 sample_uv = clamp(bounded_uv + vec2(horizontal_jitter, 0.0), vec2(0.0), vec2(1.0));
	
	vec3 src_color = sample_phosphor(sample_uv) * 0.60;
	src_color += texture(screen_texture, clamp(sample_uv + vec2(px.x * 1.35, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.16;
	src_color += texture(screen_texture, clamp(sample_uv - vec2(px.x * 1.35, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.16;
	src_color += texture(screen_texture, clamp(sample_uv + vec2(px.x * 2.70, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.04;
	src_color += texture(screen_texture, clamp(sample_uv - vec2(px.x * 2.70, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.04;
	
	vec3 ghost = texture(screen_texture, clamp(sample_uv + vec2(px.x * 2.5, -px.y * 1.2), vec2(0.0), vec2(1.0))).rgb;
	src_color += ghost * ghost_strength;
	src_color += texture(screen_texture, clamp(sample_uv - vec2(px.x * 1.8, 0.0), vec2(0.0), vec2(1.0))).rgb * 0.06;
	
	vec3 linear = pow(max(src_color, vec3(0.0)), vec3(gamma_in));
	
	vec2 bloom_step = px * bloom_radius * 2.0;
	vec3 bloom = (
		texture(screen_texture, clamp(sample_uv + vec2(bloom_step.x, 0.0), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv - vec2(bloom_step.x, 0.0), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv + vec2(0.0, bloom_step.y), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv - vec2(0.0, bloom_step.y), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv + vec2(bloom_step.x, bloom_step.y), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv + vec2(-bloom_step.x, bloom_step.y), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv + vec2(bloom_step.x, -bloom_step.y), vec2(0.0), vec2(1.0))).rgb +
		texture(screen_texture, clamp(sample_uv - bloom_step, vec2(0.0), vec2(1.0))).rgb
	) / 8.0;
	vec3 bloom_linear = pow(max(bloom, vec3(0.0)), vec3(gamma_in));
	float bloom_gate = smoothstep(bloom_threshold, 1.25, dot(bloom_linear, LUMA));
	linear += bloom_linear * bloom_strength * bloom_gate;
	
	float scan_phase = (sample_uv.y / max(px.y, 0.000001)) * (2.0 * PI / scanline_thickness);
	float scanline = 1.0 - scanline_intensity * (0.5 + 0.5 * cos(scan_phase));
	linear *= scanline;
	
	float column = floor(sample_uv.x / max(px.x, 0.000001));
	float row = floor(sample_uv.y / max(px.y, 0.000001));
	float triad = mod(column, 3.0);
	vec3 mask = vec3(1.0 - mask_intensity);
	if (triad < 1.0) {
		mask.r = 1.0;
	} else if (triad < 2.0) {
		mask.g = 1.0;
	} else {
		mask.b = 1.0;
	}
	if (mod(row, 2.0) > 0.5) {
		mask = mask.bgr;
	}
	linear *= mask;
	
	float flicker = 1.0 + sin(TIME * 120.0 + sample_uv.y * 12.0) * flicker_strength;
	linear *= flicker;
	
	float noise = hash12(floor(sample_uv / max(px, vec2(0.000001))) + vec2(floor(TIME * 60.0), 0.0)) - 0.5;
	linear += noise * static_noise;
	
	float luma = dot(linear, LUMA);
	linear = mix(vec3(luma), linear, saturation_boost);
	
	vec2 centered = curved_uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered * vec2(0.92, 1.1), centered * vec2(0.92, 1.1));
	vignette = clamp(pow(max(vignette, 0.0), corner_fade), 0.0, 1.0);
	linear *= mix(1.0, vignette, vignette_strength);
	
	float edge_x = smoothstep(0.0, 0.02, curved_uv.x) * (1.0 - smoothstep(0.98, 1.0, curved_uv.x));
	float edge_y = smoothstep(0.0, 0.02, curved_uv.y) * (1.0 - smoothstep(0.98, 1.0, curved_uv.y));
	linear *= mix(1.0, edge_x * edge_y, edge_darkness);
	
	vec3 final_color = pow(max(linear, vec3(0.0)), vec3(1.0 / gamma_out));
	final_color *= bounds_mask;
	COLOR = vec4(clamp(final_color, 0.0, 1.0), 1.0);
}
