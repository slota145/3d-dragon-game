shader_type canvas_item;
// Linie pędu + winieta przy dużych prędkościach. intensity: 0 (brak) .. 1 (pełne).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0; // krótki rozbłysk przy zrywie
uniform float line_count = 160.0;
uniform float flow_speed = 2.6;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.75);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	float a = atan(uv.y, uv.x) / 6.2831853 + 0.5;
	float cell = a * line_count;
	float id = floor(cell);
	float h = hash(id);
	float thin = 1.0 - smoothstep(0.0, 0.18, abs(fract(cell) - 0.5));
	float t = fract(TIME * flow_speed * (0.6 + h) + h * 7.0);
	float head = mix(0.2, 1.0, t);
	float len = 0.1 + 0.25 * h;
	float streak = smoothstep(head - len, head, r) * (1.0 - smoothstep(head, head + 0.015, r));
	float shown = step(1.0 - clamp(intensity + flash * 0.5, 0.0, 1.0) * 0.85, h);
	float mask = smoothstep(0.22, 0.6, r);
	float lines = streak * thin * shown * mask * clamp(intensity + flash, 0.0, 1.0);
	float vig = smoothstep(0.3, 0.95, r) * (intensity * 0.45 + flash * 0.25);
	float alpha = clamp(lines * line_color.a + vig, 0.0, 1.0);
	vec3 col = mix(vec3(0.0), line_color.rgb, lines / max(lines + vig, 0.0001));
	COLOR = vec4(col, alpha);
}
