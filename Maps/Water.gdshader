shader_type spatial;

render_mode blend_mix, depth_draw_always, cull_disabled;

uniform vec4 albedo : source_color = vec4(0.1, 0.3, 0.5, 1.0);
uniform vec4 color_deep : source_color = vec4(0.0, 0.1, 0.2, 1.0);
uniform sampler2D noise_texture;
uniform float texture_speed : hint_range(0, 0.5) = 0.05;
uniform float texture_scale : hint_range(0, 2.0) = 0.5;
uniform float refraction_strength : hint_range(0, 1.0) = 0.05;
uniform float beers_law : hint_range(0, 20.0) = 2.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture;

varying vec3 world_pos;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Scrolling noise for surface detail
	vec2 uv_offset = vec2(TIME * texture_speed);
	vec4 noise = texture(noise_texture, UV * texture_scale + uv_offset);
	noise *= texture(noise_texture, UV * texture_scale * 0.8 - uv_offset * 1.2);
	
	vec3 normal = normalize(vec3(noise.r - 0.5, 2.0, noise.g - 0.5));
	NORMAL = (VIEW_MATRIX * vec4(normal, 0.0)).xyz;

	// Depth calculations
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	float water_depth = linear_depth + VERTEX.z;
	
	// Beers Law for depth fog
	float depth_fade = exp(-water_depth * beers_law * 0.1);
	vec3 depth_color = mix(color_deep.rgb, albedo.rgb, clamp(depth_fade, 0.0, 1.0));
	
	// Refraction
	vec2 ref_offset = normal.xy * refraction_strength;
	vec3 screen_color = textureLod(screen_texture, SCREEN_UV + ref_offset, 0.0).rgb;
	
	// Fresnel for surface reflection
	float fresnel_factor = fresnel(4.0, NORMAL, VIEW);
	
	vec3 final_color = mix(depth_color, screen_color, clamp(depth_fade * 0.5, 0.0, 1.0));
	final_color = mix(final_color, albedo.rgb, fresnel_factor * 0.5);
	
	ALBEDO = final_color;
	ROUGHNESS = 0.1;
	SPECULAR = 0.5;
}
