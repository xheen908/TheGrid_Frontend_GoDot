shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 aura_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 3.0;
uniform float intensity : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    float time = TIME * speed;
    
    // UV-Animation für aufsteigende Partikel/Strahlen
    float noise1 = sin(UV.x * 20.0 + time) * cos(UV.y * 10.0 - time);
    float noise2 = sin(UV.x * 15.0 - time * 1.3) * cos(UV.y * 20.0 + time * 1.5);
    
    float combined_noise = (noise1 + noise2 + 1.0) / 2.0;
    
    // Kreisförmiger Gradient (unten stärker)
    float gradient = 1.0 - UV.y;
    
    ALBEDO = aura_color.rgb * intensity;
    ALPHA = aura_color.a * combined_noise * gradient * 0.8;
}
