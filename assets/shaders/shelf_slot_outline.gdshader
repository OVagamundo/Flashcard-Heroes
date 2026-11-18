shader_type canvas_item;

uniform float width = 1.0;
uniform sampler2D asset_texture : filter_nearest, repeat_disable;

float asset_alpha(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(asset_texture, uv).a;
}

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * width;
	float edge = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			edge = min(edge, asset_alpha(UV + vec2(float(x), float(y)) * step_uv));
		}
	}
	float alpha = asset_alpha(UV);
	COLOR = vec4(vec3(1.0), alpha * (1.0 - step(0.1, edge)));
}
