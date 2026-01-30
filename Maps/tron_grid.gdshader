shader_type spatial;

uniform vec3 background_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 line_color : source_color = vec3(0.0, 0.5, 1.0);
uniform float grid_size = 1.0; // Cell size in meters
uniform float line_width = 0.1;
uniform float glow_strength = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
    // Triplanar-style grid projection
    vec3 blending = abs(world_normal);
    blending /= (blending.x + blending.y + blending.z);
    
    vec2 uv_x = world_pos.zy / grid_size;
    vec2 uv_y = world_pos.xz / grid_size;
    vec2 uv_z = world_pos.xy / grid_size;
    
    // Grid calculation for each plane
    // auto float grid_func(vec2 uv) { // This lambda-like syntax is not standard GLSL and might cause issues.
    //     vec2 grid = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
    //     return 1.0 - smoothstep(0.0, line_width, min(grid.x, grid.y));
    // }
    
    // Manual expansion of the lambda-like logic since GLSL doesn't support them well in all versions
    vec2 g_x = abs(fract(uv_x - 0.5) - 0.5) / fwidth(uv_x);
    float m_x = 1.0 - smoothstep(0.0, line_width, min(g_x.x, g_x.y));
    
    vec2 g_y = abs(fract(uv_y - 0.5) - 0.5) / fwidth(uv_y);
    float m_y = 1.0 - smoothstep(0.0, line_width, min(g_y.x, g_y.y));
    
    vec2 g_z = abs(fract(uv_z - 0.5) - 0.5) / fwidth(uv_z);
    float m_z = 1.0 - smoothstep(0.0, line_width, min(g_z.x, g_z.y));
    
    float mask = m_x * blending.x + m_y * blending.y + m_z * blending.z;
    
    ALBEDO = background_color;
    EMISSION = line_color * mask * glow_strength;
}