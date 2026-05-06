shader_type canvas_item;

// Prismatic Foil Shader
// Applies a holographic rainbow effect and metallic sheen to the sprite

uniform float speed : hint_range(0.0, 5.0) = 0.5;
uniform float frequency : hint_range(0.0, 10.0) = 2.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float sheen_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float sheen_width : hint_range(0.0, 1.0) = 0.15;

// Shared uniforms from standard unit shader for compatibility
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;

// Function to convert HSL to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 sprite_color = texture(TEXTURE, UV);
    
    if (sprite_color.a > 0.0) {
        // 1. Rainbow Cycle
        // Calculate hue based on UV and time
        float hue = fract(UV.x * frequency + UV.y * (frequency * 0.5) + TIME * speed);
        vec3 rainbow = hsv2rgb(vec3(hue, 0.6, 1.0));
        
        // 2. Metallic Sheen
        // A diagonal line that sweeps across the sprite
        float sheen_pos = fract(TIME * speed * 1.5);
        float dist_to_sheen = abs((UV.x + UV.y) * 0.5 - sheen_pos);
        float sheen = smoothstep(sheen_width, 0.0, dist_to_sheen) * sheen_intensity;
        
        // 3. Combine
        vec3 final_rgb = mix(sprite_color.rgb, rainbow, intensity);
        final_rgb += sheen;
        
        // Apply flash effect
        final_rgb = mix(final_rgb, flash_color.rgb, flash_intensity);
        
        COLOR = vec4(final_rgb, sprite_color.a * alpha_multiplier);
    } else {
        COLOR = vec4(0.0);
    }
}
