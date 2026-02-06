shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;

uniform vec4 circle_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float thickness : hint_range(0.0, 0.5) = 0.05;
uniform float glow_intensity : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // Time-based rotation
    float rot_speed = 1.0;
    float time_angle = TIME * rot_speed;
    
    // Rotating UVs for pattern
    float rot_angle = angle + time_angle;
    
    // --- Outer Ring (Rune-like segments) ---
    float radius_outer = 0.45;
    float ring_width = thickness;
    
    // Create segments using sine of angle
    float segments = sin(rot_angle * 12.0); // 12 segments
    float segment_mask = smoothstep(0.5, 0.6, segments); // Sharp gaps
    
    float ring_outer = smoothstep(radius_outer - ring_width - 0.01, radius_outer - ring_width, dist) 
                     - smoothstep(radius_outer, radius_outer + 0.01, dist);
    
    // Apply segments to outer ring
    float final_outer = ring_outer * (0.2 + 0.8 * segment_mask); // Never fully transparent, just dim in gaps
    
    // --- Inner Pattern (Geometric/Runes) ---
    float radius_inner = 0.35;
    float inner_rot_angle = angle - time_angle * 1.5; // Rotate opposite and faster
    
    // Create a 6-pointed star-ish or rune pattern
    float pattern = sin(inner_rot_angle * 3.0) * sin(inner_rot_angle * 7.0); 
    float ring_inner = smoothstep(radius_inner - 0.02, radius_inner, dist) 
                     - smoothstep(radius_inner, radius_inner + 0.02, dist);
                     
    // Decorate inner ring
    float final_inner = ring_inner * smoothstep(0.0, 0.5, pattern + 0.5);
    
    // --- Center Dot / Core ---
    float center_dot = 1.0 - smoothstep(0.03, 0.05, dist);
    
    // Combine everything
    float final_mask = max(max(final_outer, final_inner), center_dot);
    
    if (final_mask <= 0.01) discard;
    
    // Pulse effect
    float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
    
    ALBEDO = circle_color.rgb;
    ALPHA = final_mask * circle_color.a;
    EMISSION = circle_color.rgb * glow_intensity * final_mask * pulse;
}
