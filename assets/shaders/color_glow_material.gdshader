shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(1.0, 0.945, 0.91, 1.0); // Exact #fff1e8
uniform float tolerance : hint_range(0.0, 255.0) = 5.0; // 0-255 RGB tolerance
uniform float glow_intensity : hint_range(0.0, 10.0) = 4.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.945, 0.91, 1.0);

const float GLOW_RADIUS = 12.0;

void vertex() {
    // Determine which corner this vertex is
    vec2 expand_dir = sign(UV - vec2(0.5));
    
    // Push the vertex outward by GLOW_RADIUS pixels to give the fragment shader padded room
    VERTEX += expand_dir * GLOW_RADIUS;
    
    // Scale the UV map to account for the larger geometry, so the texture stays its original size
    UV += expand_dir * (GLOW_RADIUS * TEXTURE_PIXEL_SIZE);
}

void fragment() {
    // Only fetch base texture color if we are inside the original image bounds
    vec4 base_color = vec4(0.0);
    if (UV.x >= 0.0 && UV.x <= 1.0 && UV.y >= 0.0 && UV.y <= 1.0) {
        base_color = texture(TEXTURE, UV);
    }
    
    vec2 pixel_size = TEXTURE_PIXEL_SIZE;
    float glow_weight = 0.0;
    
    // Sweep neighboring pixels looking for the exact target color
    for (float x = -GLOW_RADIUS; x <= GLOW_RADIUS; x += 1.0) {
        for (float y = -GLOW_RADIUS; y <= GLOW_RADIUS; y += 1.0) {
            vec2 offset = vec2(x, y) * pixel_size;
            vec2 sample_uv = UV + offset;
            
            // Prevent sampling the repeated/clamped edges of the texture itself
            if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
                vec4 sample_color = texture(TEXTURE, sample_uv);
                
                if (sample_color.a > 0.1) {
                    // Check against exact hex representation in 0-255 bounds
                    vec3 sample_255 = round(sample_color.rgb * 255.0);
                    vec3 target_255 = round(target_color.rgb * 255.0);
                    
                    float dist = distance(sample_255, target_255);
                    if (dist <= tolerance) {
                        float d = length(vec2(x, y));
                        if (d <= GLOW_RADIUS) {
                            // Weight glow stronger the closer the target pixel is
                            float weight = 1.0 - (d / GLOW_RADIUS);
                            glow_weight += weight;
                        }
                    }
                }
            }
        }
    }
    
    glow_weight = glow_weight / (GLOW_RADIUS * 1.5); 
    
    // Add the glow light to either the base_color or the empty padded space
    vec3 final_rgb = base_color.rgb + (glow_color.rgb * glow_weight * glow_intensity);
    float final_alpha = min(1.0, base_color.a + (glow_weight * glow_intensity));
    
    COLOR = vec4(final_rgb, final_alpha);
}
