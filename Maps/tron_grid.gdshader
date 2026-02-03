shader_type spatial;

uniform vec4 background_color : source_color = vec4( 0.0, 0.05, 0.1, 1.0 );
uniform vec4 line_color : source_color = vec4( 0.0, 0.8, 1.0, 1.0 );
uniform float grid_size = 3.0;
uniform float line_width = 1.0;
uniform float glow_strength = 4.0;

void fragment( )
{
	vec2 uv = UV * grid_size;
	vec2 grid = abs( fract( uv - 0.5 ) - 0.5 ) / fwidth( uv );
	float line = min( grid.x, grid.y );
	float mask = 1.0 - smoothstep( 0.0, line_width, line );

	ALBEDO = mix( background_color.rgb, line_color.rgb, mask );
	EMISSION = line_color.rgb * mask * glow_strength;
}