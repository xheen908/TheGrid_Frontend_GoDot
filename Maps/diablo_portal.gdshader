shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform vec4 portal_color : source_color = vec4(0.0, 0.4, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float transparency : hint_range(0.0, 1.0) = 0.1;
uniform float rim_power : hint_range(0.1, 10.0) = 3.0;
uniform float glow_intensity : hint_range(1.0, 20.0) = 5.0;
uniform float speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// Fresnel Effekt: 0.0 in der Mitte, 1.0 am Rand
	float fresnel = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	
	// Rand-Leuchten (sanfterer Verlauf)
	float rim = pow(fresnel, rim_power);
	
	// Pulsieren und dezentes Schimmern
	float pulse = sin(TIME * speed) * 0.1 + 0.9;
	float noise = sin(NORMAL.y * 10.0 + TIME * 2.0) * 0.05;
	
	// Farbmischung: Wir erzwingen ein sattes Blau/Cyan
	vec3 base = mix(core_color.rgb * 0.2, portal_color.rgb, rim);
	vec3 final_color = base * glow_intensity * pulse;
	
	// Transparenz: Die Mitte ist durchsichtig (transparency), der Rand ist deckend
	float alpha = mix(transparency, 1.0, rim + noise);
	
	ALBEDO = final_color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
