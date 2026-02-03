shader_type spatial;
render_mode cull_back, unshaded;

uniform vec3 line_color : source_color = vec3(0.0, 1.0, 1.0);
uniform float line_thickness : hint_range(0.0, 0.5) = 0.02;
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float frequency : hint_range(1.0, 30.0) = 8.0;
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;

varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    // 3D-Gitter Berechnung
    vec3 v_freq = local_pos * frequency;
    vec3 derivative = fwidth(v_freq);
    
    vec3 grid_axes = abs(fract(v_freq - 0.5) - 0.5) / max(derivative, vec3(0.001));
    
    // Fix für flache Seiten (Würfel)
    if (derivative.x < 0.001) grid_axes.x = 100.0;
    if (derivative.y < 0.001) grid_axes.y = 100.0;
    if (derivative.z < 0.001) grid_axes.z = 100.0;
    
    float line = min(min(grid_axes.x, grid_axes.y), grid_axes.z);
    float edge = 1.0 - smoothstep(0.0, line_thickness * 15.0, line);
    
    // Fresnel Effekt am Rand
    float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float fresnel = pow(fres, fresnel_power);
    
    // Maske für die Linien und das Leuchten
    float mask = clamp(edge + fresnel * 0.5, 0.0, 1.0);
    
    // Schwarze Basis mit farbigen Linien
    vec3 base_color = vec3(0.0); // Tiefschwarz
    vec3 glow_color = line_color * (edge * glow_intensity + fresnel * (glow_intensity * 0.5));
    
    ALBEDO = mix(base_color, glow_color, mask);
    ALPHA = 1.0; // Vollständig undurchsichtig
}
