shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform vec4 target_color = vec4(1.0, 0.945098, 0.909804, 1.0); // Exact #fff1e8 mathematically
uniform float tolerance : hint_range(0.0, 1.0) = 0.005; // Extremely strict tolerance for exact matches only 
uniform float glow_intensity : hint_range(0.0, 10.0) = 4.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.945, 0.91, 1.0);

const int SAMPLE_COUNT = 7; // Loop 15x15 times instead of 31x31 (saves 75% GPU power)
const float SPREAD = 2.0;   // Skips every other pixel to maintain the massive 14-pixel aura

void fragment() {
    vec4 base_color = texture(screen_texture, SCREEN_UV);
    vec2 pixel_size = SCREEN_PIXEL_SIZE;
    
    float max_glow_weight = 0.0;
    
    // WebGL/OpenGL Compatibility STRICTLY requires integer loop counters!
    for (int x = -SAMPLE_COUNT; x <= SAMPLE_COUNT; x++) {
        for (int y = -SAMPLE_COUNT; y <= SAMPLE_COUNT; y++) {
            // Expand the read area physically by multiplying our coordinates
            vec2 offset = vec2(float(x), float(y)) * pixel_size * SPREAD;
            vec4 sample_color = texture(screen_texture, SCREEN_UV + offset);
            
            float dist = distance(sample_color.rgb, target_color.rgb);
            
            if (dist <= tolerance) {
                // Calculate physical distance across the expanded 14-pixel grid
                float d = length(vec2(float(x), float(y)) * SPREAD);
                float max_radius = float(SAMPLE_COUNT) * SPREAD;
                
                if (d <= max_radius) {
                    // Linear distance falloff
                    float weight = 1.0 - (d / max_radius);
                    if (weight > max_glow_weight) {
                        max_glow_weight = weight;
                    }
                }
            }
        }
    }
    
    // Exponential curve for softer edge bleeding instead of solid blocks
    // Increased power (3.0) drops brightness dramatically as it moves away from the source
    float final_weight = pow(max_glow_weight, 3.0);
    
    // Blend the glow physically as a light addition
    // The intensity is scaled down heavily so a massive radius doesn't blow out the visuals
    vec3 glow_light = glow_color.rgb * final_weight * (glow_intensity * 0.15);
    
    // Add the computed glow physically on top of the screen's existing color
    vec3 final_rgb = min(vec3(1.0), base_color.rgb + glow_light);
    
    COLOR = vec4(final_rgb, base_color.a);
}
