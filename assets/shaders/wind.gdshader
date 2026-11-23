shader_type spatial;
// Kołysanie na wietrze (trawa, kwiaty, korony drzew). Wychylenie rośnie z wysokością wierzchołka
// nad `sway_start` (w przestrzeni modelu), faza zależy od położenia w świecie — fale przechodzą
// przez łąkę i las. Kolor: albedo × kolor wierzchołka × kolor instancji (COLOR).
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float strength = 0.06;
uniform float sway_start = 0.0;
uniform float speed = 1.6;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y - sway_start, 0.0);
	float gust = 0.6 + 0.4 * sin(TIME * 0.35 + wp.x * 0.004 + wp.z * 0.003);
	float w = sin(TIME * speed + wp.x * 0.12 + wp.z * 0.08) + 0.4 * sin(TIME * speed * 2.3 + wp.x * 0.37);
	VERTEX.x += w * strength * h * gust;
	VERTEX.z += w * strength * 0.5 * h * gust;
}

void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}
