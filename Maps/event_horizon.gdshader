shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 portal_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.2;
uniform sampler2D target_preview : source_color;
uniform float parallax_depth : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    float time = TIME * speed;
    
    // Distanz vom Zentrum für kreisförmige Wellen
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);
    
    // Parallax Effekt: UVs basierend auf der Blickrichtung verschieben
    // VIEW ist in View-Space, wir brauchen es in Tangent/Local Space (hier vereinfacht)
    vec3 view_dir = normalize(VIEW);
    vec2 parallax_offset = view_dir.xy * parallax_depth;
    vec2 preview_uv = UV + parallax_offset;
    
    // Preview Texture laden
    vec4 preview_color = texture(target_preview, preview_uv);
    
    // Simuliere Wasserwellen-Effekt
    float ripple = sin(dist * 20.0 - time * 2.0) * wave_strength;
    float ripple2 = cos(dist * 15.0 + time * 1.5) * wave_strength * 0.5;
    
    // Mix Colors
    vec3 base_color = portal_color.rgb;
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
    
    // Das "Bild" der anderen Welt durchscheinen lassen
    vec3 final_color = mix(base_color, preview_color.rgb, 1.0 - dist * 2.0);
    final_color = mix(final_color, vec3(1.0), fresnel + ripple + ripple2);
    
    ALBEDO = final_color;
    ALPHA = portal_color.a * (0.8 + ripple * 0.2);
    EMISSION = final_color * (1.5 + ripple * 2.0);
    ROUGHNESS = 0.1;
    METALLIC = 0.5;
}
