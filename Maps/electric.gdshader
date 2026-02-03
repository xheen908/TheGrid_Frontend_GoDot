/*
	動적電子背景シェーダー by あるる（きのもと 結衣） @arlez80
	Procedural Electric Background Shader by Yui Kinomoto @arlez80

	MIT License
	Converted to Spatial for Godot 4
*/
shader_type spatial;

uniform vec4 background_color : source_color = vec4( 0.0, 0.0, 0.0, 1.0 );
uniform vec4 line_color : source_color = vec4( 0.0, 1.0, 1.0, 1.0 );
uniform float line_freq = 9.56;
uniform float height = 0.6;
uniform float speed = 0.8;
uniform vec2 scale = vec2( 2.0, 16.0 );
uniform float emission_strength = 2.0;

void fragment( )
{
	vec2 uv = UV * scale;
	float shift = cos( floor( uv.y ) );
	uv.x += shift;

	float freq = clamp( cos( uv.x * line_freq ) * 3.0, 0.0, 1.0 ) * height;
	float line = 1.0 - clamp( abs( freq - mod( uv.y, 1.0 ) ) * 11.0, 0.0, 1.0 );

	vec3 final_color = mix( background_color, line_color, line * mod( uv.x - TIME * speed * abs( shift ), 1.0 ) ).rgb;
	
	ALBEDO = final_color;
	EMISSION = final_color * emission_strength;
}
