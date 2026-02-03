/*
	Optimierter Backstein-Shader für Godot 4
*/
shader_type spatial;

uniform vec3 brick_color : source_color = vec3(0.5, 0.15, 0.1);
uniform vec3 brick_color2 : source_color = vec3(0.4, 0.1, 0.05);
uniform vec3 mortar_color : source_color = vec3(0.7, 0.7, 0.6);

uniform vec2 brick_counts = vec2(12.0, 24.0); // Ziegel um die Säule / Ziegel in der Höhe
uniform float joint_width : hint_range(0.0, 0.1) = 0.05;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.71, 31.17))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV * brick_counts;
	
	// Jede zweite Reihe versetzen
	float row = floor(uv.y);
	uv.x += fract(row * 0.5) > 0.1 ? 0.5 : 0.0;
	
	vec2 brick_uv = fract(uv);
	vec2 tile_id = floor(uv);
	
	// Fugen berechnen (härtere Kanten für saubereren Look)
	vec2 joint = smoothstep(0.0, joint_width, brick_uv) * (1.0 - smoothstep(1.0 - joint_width, 1.0, brick_uv));
	float is_brick = joint.x * joint.y;
	
	// Zufällige Variation der Ziegelfarbe
	float variation = hash(tile_id);
	vec3 final_brick_color = mix(brick_color, brick_color2, variation);
	
	// Albedo mischen
	ALBEDO = mix(mortar_color, final_brick_color, is_brick);
	
	// Normals für die Fugen-Tiefe
	float border = 0.05;
	float nx = smoothstep(0.0, border, brick_uv.x) - smoothstep(1.0-border, 1.0, brick_uv.x);
	float ny = smoothstep(0.0, border, brick_uv.y) - smoothstep(1.0-border, 1.0, brick_uv.y);
	NORMAL_MAP = normalize(vec3(nx * 0.5 + 0.5, ny * 0.5 + 0.5, 1.0));
	
	ROUGHNESS = mix(0.5, roughness, is_brick);
	METALLIC = 0.0;
}
