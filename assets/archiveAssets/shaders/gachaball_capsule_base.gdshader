shader_type canvas_item;
render_mode unshaded;

uniform vec4 target_color = vec4(1.0, 0.945098, 0.909804, 1.0);
uniform float tolerance : hint_range(0.0, 0.05) = 0.005;
uniform vec4 replacement_color = vec4(1.0, 0.937255, 0.901961, 1.0); // Slightly off the global glow key.

void fragment() {
	vec4 vertex_color = COLOR;
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 output_color = tex_color * vertex_color;
	float source_dist = distance(tex_color.rgb, target_color.rgb);

	if (tex_color.a > 0.0 && source_dist <= tolerance) {
		output_color.rgb = replacement_color.rgb * vertex_color.rgb;
		output_color.a = tex_color.a * vertex_color.a;
	}

	COLOR = output_color;
}
