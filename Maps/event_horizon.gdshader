shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 portal_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    float time = TIME * speed;
    
    // Distanz vom Zentrum für kreisförmige Wellen
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);
    
    // Simuliere Wasserwellen-Effekt
    float ripple = sin(dist * 20.0 - time * 2.0) * wave_strength;
    float ripple2 = cos(dist * 15.0 + time * 1.5) * wave_strength * 0.5;
    
    // Mix Colors
    vec3 base_color = portal_color.rgb;
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    
    ALBEDO = mix(base_color, vec3(1.0), fresnel + ripple + ripple2);
    ALPHA = portal_color.a * (0.7 + ripple * 0.3);
    EMISSION = base_color * (2.0 + ripple * 5.0);
    ROUGHNESS = 0.1;
    METALLIC = 0.5;
}
