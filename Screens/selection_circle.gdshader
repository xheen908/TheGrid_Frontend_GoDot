shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;

uniform vec4 circle_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float thickness : hint_range(0.0, 0.5) = 0.1;
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Zentrierte UVs (-0.5 bis 0.5)
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    
    // Erzeuge einen sauberen Ring
    float radius = 0.45; // Etwas kleiner als der Rand
    float inner = radius - thickness;
    
    // Maske für den Ring
    float mask = smoothstep(inner - 0.01, inner, dist) - smoothstep(radius, radius + 0.01, dist);
    
    if (mask <= 0.0) discard;
    
    ALBEDO = circle_color.rgb;
    ALPHA = mask * circle_color.a;
    EMISSION = circle_color.rgb * glow_intensity;
}
