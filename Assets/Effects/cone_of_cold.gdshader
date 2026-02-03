shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float cone_angle = 120.0;
uniform float range = 8.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex;

void fragment() {
    // Convert UV to polar coordinates
    vec2 uv = UV - 0.5;
    float dist = length(uv) * 2.0; // 0.0 to 1.0
    float angle = degrees(atan(uv.x, uv.y)) + 180.0; // 0 to 360
    
    // Normalize angle to front (180 is center)
    float angle_diff = abs(angle - 180.0);
    if (angle_diff > 180.0) angle_diff = 360.0 - angle_diff;
    
    // Cone mask
    float half_cone = cone_angle / 2.0;
    float cone_mask = smoothstep(half_cone, half_cone - 10.0, angle_diff);
    
    // Distance mask (radial expansion)
    float dist_mask = smoothstep(progress, progress - 0.2, dist) * (1.0 - dist);
    
    // Noise for frost texture
    vec2 noise_uv = UV * 2.0 + vec2(0.0, -TIME * 2.0);
    float noise = texture(noise_tex, noise_uv).r;
    
    float alpha = cone_mask * dist_mask * noise * color.a;
    
    // Fade out based on progress
    alpha *= (1.0 - progress);
    
    ALBEDO = color.rgb;
    ALPHA = clamp(alpha, 0.0, 1.0);
}
