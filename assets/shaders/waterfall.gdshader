shader_type spatial;
// Wodospad / strumień na wstędze: UV.y = metry wzdłuż biegu wody, COLOR.r = stromość (0 płasko, 1 spadek).
// Smugi przesuwają się z prądem (na spadku szybciej), na spadku woda bieleje (piana).
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D streaks : repeat_enable, filter_linear;
uniform vec3 deep_color : source_color = vec3(0.28, 0.62, 0.8);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform float speed = 1.6;

void fragment() {
	float steep = COLOR.r;
	float flow = TIME * speed * (0.5 + steep * 2.5);
	float s = texture(streaks, vec2(UV.x * 0.6, UV.y * 0.05 - flow * 0.05)).r;
	float s2 = texture(streaks, vec2(UV.x * 1.3 + 0.37, UV.y * 0.11 - flow * 0.09)).r;
	float foam = clamp(steep * 0.35 + (s * 0.7 + s2 * 0.6) * (0.6 + steep * 0.6) - 0.5, 0.0, 1.0);
	ALBEDO = mix(deep_color, foam_color, foam);
	ROUGHNESS = 0.25;
	EMISSION = foam_color * foam * 0.12;
}
