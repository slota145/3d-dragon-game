shader_type spatial;
// Woda: płytko turkus, głęboko błękit, piana przy brzegu — głębokość z mapy wody liczonej
// z terenu (Terrain: depth_map, 8 m/piksel; działa na każdym telefonie, bez bufora głębi),
// zmarszczki z przesuwanych map normalnych (błyski słońca), lekka przezroczystość.
render_mode blend_mix, depth_draw_always, cull_disabled;

// R = głębokość / 8 m; brak mapy (jeszcze się liczy) = głęboko, bez piany
uniform sampler2D depth_map : filter_linear;
uniform bool has_depth_map = false;
uniform float world_size = 4096.0;
uniform sampler2D ripples_a : hint_normal;
uniform sampler2D ripples_b : hint_normal;
uniform vec3 shallow : source_color = vec3(0.32, 0.85, 0.82);
uniform vec3 deep : source_color = vec3(0.08, 0.38, 0.62);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);

void fragment() {
	vec2 wxz = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec3 na = texture(ripples_a, wxz * 0.03 + TIME * vec2(0.012, 0.007)).rgb;
	vec3 nb = texture(ripples_b, wxz * 0.07 - TIME * vec2(0.009, 0.014)).rgb;
	NORMAL_MAP = mix(na, nb, 0.5);
	NORMAL_MAP_DEPTH = 0.6;
	float diff = has_depth_map ? texture(depth_map, wxz / world_size + 0.5).r * 8.0 : 8.0;
	vec3 col = mix(shallow, deep, clamp(diff / 7.0, 0.0, 1.0));
	float wobble = 0.25 * sin(TIME * 1.5 + wxz.x * 0.3 + wxz.y * 0.2);
	float foam = 1.0 - smoothstep(0.15, 0.9 + wobble, diff);
	ALBEDO = mix(col, foam_color, foam * 0.85);
	ALPHA = mix(0.6, 0.92, clamp(diff / 4.0, 0.0, 1.0));
	ROUGHNESS = 0.06;
	METALLIC = 0.1;
	SPECULAR = 0.7;
}
