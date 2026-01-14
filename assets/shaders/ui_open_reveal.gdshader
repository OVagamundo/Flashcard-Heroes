shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float shine_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float shine_width : hint_range(0.0, 1.0) = 0.05;

void fragment() {
    float current_y = UV.y;
    
    // Invert progress so 0.0 starts fully invisible (masked) and 1.0 is fully visible
    // We want the window to "wipe down" or "wipe up" or "expand".
    // Let's do a vertical wipe from top to bottom effectively, or center out.
    // Simpler: Reveal from top to bottom (0 -> 1).
    // Actually, "Holographic" often implies building up.
    // Let's do a vertical wipe: visible if UV.y < progress
    
    // Add a bit of softness to the edge
    float edge_softness = 0.02;
    float alpha = smoothstep(progress + edge_softness, progress - edge_softness, current_y);
    
    // Add shine line at the leading edge
    float shine = smoothstep(progress - shine_width, progress, current_y) * smoothstep(progress + shine_width, progress, current_y);
    // Fix shine logic: we want a peak at 'progress'
    // A simple bell curve or distance check:
    float dist = abs(current_y - progress);
    float shine_line = smoothstep(shine_width, 0.0, dist) * shine_strength;
    
    vec4 texture_color = texture(TEXTURE, UV);
    
    // Apply alpha mask
    COLOR = texture_color;
    COLOR.a *= alpha;
    
    // Apply shine
    // Only where the image exists and is being revealed
    if (alpha > 0.01) {
        COLOR.rgb = mix(COLOR.rgb, shine_color.rgb, shine_line * shine_color.a);
    }
}
