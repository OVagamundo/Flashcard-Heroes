shader_type canvas_item;

// Outline shader that creates a border around opaque pixels only
// Ignores transparent parts of the sprite

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White by default
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform bool outline_enabled = false;

void fragment() {
    vec4 sprite_color = texture(TEXTURE, UV);
    
    if (outline_enabled && outline_width > 0.0) {
        // Get the pixel size for sampling neighbors
        vec2 pixel_size = TEXTURE_PIXEL_SIZE;
        
        // If current pixel is transparent, check if any neighbor is opaque
        if (sprite_color.a < 0.1) {
            // Sample in multiple directions for a smooth outline
            float max_alpha = 0.0;
            
            // Sample in 8 directions + additional samples for thicker outlines
            for (float angle = 0.0; angle < 6.28318; angle += 0.7854) { // 8 directions (45° increments)
                for (float dist = 1.0; dist <= outline_width; dist += 1.0) {
                    vec2 offset = vec2(cos(angle), sin(angle)) * pixel_size * dist;
                    float neighbor_alpha = texture(TEXTURE, UV + offset).a;
                    max_alpha = max(max_alpha, neighbor_alpha);
                }
            }
            
            // If any neighbor is opaque, draw outline
            if (max_alpha > 0.5) {
                COLOR = outline_color;
            } else {
                COLOR = sprite_color;
            }
        } else {
            // Current pixel is opaque, keep original color
            COLOR = sprite_color;
        }
    } else {
        // Outline disabled, just show the sprite
        COLOR = sprite_color;
    }
}
