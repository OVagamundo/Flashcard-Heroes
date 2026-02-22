shader_type canvas_item;

uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;
uniform float press_amount : hint_range(0.0, 1.0) = 0.0;
uniform float selection_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 pointer_uv = vec2(0.5, 0.5);
uniform vec2 perspective_tilt = vec2(0.0, 0.0);
uniform float edge_padding_px : hint_range(0.0, 64.0) = 36.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.45, 1.0);

void vertex() {
	// Expand geometry so perspective warp is not clipped by the original card bounds.
	vec2 expand_dir = sign(UV - vec2(0.5));
	VERTEX += expand_dir * edge_padding_px;
	UV += expand_dir * (edge_padding_px * TEXTURE_PIXEL_SIZE);
}

void fragment() {
	vec2 base_uv = UV;
	vec2 uv_centered = base_uv - vec2(0.5);

	// Subtle perspective-like skew (no aggressive depth division).
	vec2 warped_uv = base_uv;
	warped_uv += vec2(
		uv_centered.y * perspective_tilt.x * 0.065,
		-uv_centered.x * perspective_tilt.y * 0.055
	);

	vec4 tex = vec4(0.0);
	if (warped_uv.x >= 0.0 && warped_uv.x <= 1.0 && warped_uv.y >= 0.0 && warped_uv.y <= 1.0) {
		tex = texture(TEXTURE, warped_uv);
	}

	if (tex.a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 card_uv = warped_uv;
		vec2 center_uv = card_uv - vec2(0.5);
		float edge_factor = smoothstep(0.30, 0.62, length(center_uv));
		float pointer_glow = smoothstep(0.45, 0.0, distance(card_uv, pointer_uv)) * hover_amount;

		// Flat, mostly fixed-angle diagonal sheen.
		// Uses horizontal center only; moving away wipes the sheen fully across and out.
		vec2 mouse_offset = pointer_uv - vec2(0.5);
		float horizontal_abs = abs(mouse_offset.x);
		float exit_mix = smoothstep(0.018, 0.16, horizontal_abs);

		vec2 base_dir = normalize(vec2(0.88, -0.47));
		vec2 base_perp = vec2(-base_dir.y, base_dir.x);
		float angle_shift = exit_mix * 0.10 * sign(mouse_offset.x + 0.0001); // Small angle change only while exiting.
		vec2 sheen_dir = normalize(base_dir + base_perp * angle_shift);
		vec2 sheen_normal = vec2(sheen_dir.y, -sheen_dir.x);

		float sweep_coord = dot(center_uv, sheen_normal);
		float sweep_center = -sign(mouse_offset.x + 0.0001) * mix(0.0, 1.45, exit_mix); // Full diagonal wipe and quick exit.
		float along_coord = dot(center_uv, sheen_dir);

		float center_focus = 1.0 - smoothstep(0.03, 0.14, horizontal_abs); // Horizontal-center only.
		float sweep_half_width = mix(0.145, 0.055, exit_mix); // Thick while centered, narrows while leaving.
		sweep_half_width *= mix(1.0, 0.8, clamp(abs(along_coord) / 0.72, 0.0, 1.0)); // Mild thickness deformation near extremes.
		float sweep_softness = 0.003;
		float dist_to_sheen = abs(sweep_coord - sweep_center);
		float white_sheen = (1.0 - smoothstep(sweep_half_width, sweep_half_width + sweep_softness, dist_to_sheen)) * center_focus * hover_amount;
		float sheen_opacity = clamp(white_sheen * 1.7, 0.0, 1.0);

		float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		vec3 saturated = mix(vec3(luminance), tex.rgb, 1.0 + hover_amount * 0.35);
		vec3 color = mix(tex.rgb, saturated, hover_amount * 0.65);

		vec2 aberration_offset = (pointer_uv - vec2(0.5)) * 0.0055 * hover_amount;
		float shifted_r = texture(TEXTURE, clamp(warped_uv + aberration_offset, vec2(0.0), vec2(1.0))).r;
		float shifted_b = texture(TEXTURE, clamp(warped_uv - aberration_offset, vec2(0.0), vec2(1.0))).b;
		vec3 shifted_rgb = vec3(shifted_r, tex.g, shifted_b);
		color = mix(color, shifted_rgb, hover_amount * 0.10);

		// Subtle depth cue: slightly lighter leading edge and darker trailing edge.
		float tilt_mag = clamp(length(perspective_tilt), 0.0, 1.0);
		float right_edge = smoothstep(0.43, 0.50, center_uv.x);
		float left_edge = smoothstep(0.43, 0.50, -center_uv.x);
		float top_edge = smoothstep(0.43, 0.50, -center_uv.y);
		float bottom_edge = smoothstep(0.43, 0.50, center_uv.y);
		float lead_light =
			right_edge * max(0.0, perspective_tilt.x) +
			left_edge * max(0.0, -perspective_tilt.x) +
			bottom_edge * max(0.0, perspective_tilt.y) +
			top_edge * max(0.0, -perspective_tilt.y);
		float trail_dark =
			right_edge * max(0.0, -perspective_tilt.x) +
			left_edge * max(0.0, perspective_tilt.x) +
			bottom_edge * max(0.0, -perspective_tilt.y) +
			top_edge * max(0.0, perspective_tilt.y);
		color += vec3(1.0) * lead_light * tilt_mag * 0.035;
		color -= vec3(1.0) * trail_dark * tilt_mag * 0.05;

		color += glow_color.rgb * pointer_glow * 0.15;
		color += glow_color.rgb * edge_factor * hover_amount * 0.11;
		color = mix(color, vec3(1.0), sheen_opacity);

		float flash_pulse = 0.5 + 0.5 * sin((TIME * 12.0) + (UV.y * 20.0));
		color += glow_color.rgb * flash_pulse * selection_flash * 0.36;

		color *= 1.0 - (press_amount * 0.14);
		COLOR = vec4(clamp(color, vec3(0.0), vec3(1.25)), tex.a);
	}
}
