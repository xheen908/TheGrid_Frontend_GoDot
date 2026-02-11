shader_type sky;

uniform vec3 day_top_color : source_color = vec3(0.1, 0.6, 1.0);
uniform vec3 day_bottom_color : source_color = vec3(0.4, 0.8, 1.0);
uniform vec3 night_top_color : source_color = vec3(0.01, 0.01, 0.05);
uniform vec3 night_bottom_color : source_color = vec3(0.02, 0.02, 0.1);

uniform vec3 sun_color : source_color = vec3(1.0, 1.0, 0.8);
uniform float sun_size : hint_range(0.01, 1.0) = 0.05;
uniform float sun_blur : hint_range(0.01, 1.0) = 0.01;

uniform vec3 moon_color : source_color = vec3(0.8, 0.8, 0.9);
uniform float moon_size : hint_range(0.01, 1.0) = 0.04;
uniform float moon_blur : hint_range(0.01, 1.0) = 0.01;

uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.05;

uniform vec3 star_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float star_density : hint_range(0.0, 100.0) = 50.0;

uniform vec3 sun_direction;
uniform float day_intensity : hint_range(0.0, 1.0) = 0.5;

const float PI = 3.14159265359;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = m * p;
        a *= 0.5;
    }
    return v;
}

void sky() {
    float horizon_mask = abs(EYEDIR.y);
    
    // Background gradient
    vec3 top = mix(night_top_color, day_top_color, day_intensity);
    vec3 bottom = mix(night_bottom_color, day_bottom_color, day_intensity);
    vec3 sky_color = mix(bottom, top, horizon_mask);
    
    // Sun
    float sun_dist = distance(EYEDIR, sun_direction);
    float sun_mask = smoothstep(sun_size + sun_blur, sun_size, sun_dist);
    sky_color = mix(sky_color, sun_color, sun_mask);
    
    // Moon (opposite to sun)
    vec3 moon_direction = -sun_direction;
    float moon_dist = distance(EYEDIR, moon_direction);
    float moon_mask = smoothstep(moon_size + moon_blur, moon_size, moon_dist);
    
    // Moon details
    float craters = noise(EYEDIR.xz * 15.0 + EYEDIR.y * 15.0);
    vec3 final_moon_color = moon_color * (0.9 + 0.1 * craters);
    sky_color = mix(sky_color, final_moon_color, moon_mask * (1.0 - day_intensity * 0.9));
    
    // Stars
    if (day_intensity < 0.2) {
        float stars = hash(EYEDIR.xy * 1000.0 + EYEDIR.z * 1000.0);
        // Twinkle effect
        float twinkle = hash(EYEDIR.xy + vec2(TIME * 0.5));
        float star_mask = pow(stars, 25.0) * star_density * (1.0 - day_intensity / 0.2) * (0.8 + 0.2 * twinkle);
        sky_color += star_color * star_mask;
    }
    
    // Clouds
    vec2 sky_uv = EYEDIR.xz / (max(abs(EYEDIR.y), 0.001));
    float cloud_noise = fbm(sky_uv + TIME * cloud_speed);
    float cloud_mask = smoothstep(1.0 - cloud_coverage, 1.0, cloud_noise) * horizon_mask;
    
    // Cloud color (darker at night)
    vec3 final_cloud_color = mix(night_top_color, cloud_color, day_intensity * 0.8 + 0.2);
    sky_color = mix(sky_color, final_cloud_color, cloud_mask * 0.8);
    
    COLOR = sky_color;
}
