shader_type spatial;
render_mode cull_back, unshaded; // cull_back verhindert den "Inside-Out" Effekt

uniform vec3 line_color : source_color = vec3(0.0, 1.0, 1.0);
uniform float line_thickness : hint_range(0.0, 1.0) = 0.1;
uniform float glow_intensity : hint_range(1.0, 10.0) = 3.0;
uniform float frequency : hint_range(1.0, 20.0) = 5.0;
uniform float fresnel_power : hint_range(1.0, 5.0) = 2.0;

void fragment() {
    // Grid Effekt basierend auf UV
    vec2 grid = abs(fract(UV * frequency - 0.5) - 0.5) / fwidth(UV * frequency);
    float line = min(grid.x, grid.y);
    float edge = 1.0 - smoothstep(0.0, line_thickness * 10.0, line);
    
    // Fresnel Effekt für leuchtende Außenkanten des Objekts
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    
    // Basis-Farbe Schwarz
    vec3 base_color = vec3(0.0, 0.0, 0.0);
    
    // Kombiniere Gitter-Linien und Fresnel für einen massiven Neon-Look
    vec3 final_glow = line_color * (edge * glow_intensity + fresnel * (glow_intensity * 0.5));
    
    ALBEDO = mix(base_color, final_glow, clamp(edge + fresnel, 0.0, 1.0));
    ALPHA = 1.0;
}
