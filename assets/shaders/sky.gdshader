shader_type sky;
// Niebo: gradient (góra / horyzont / ziemia — kolory ustawia DayNight), tarcza słońca w dzień,
// nocą księżyc (to samo światło kierunkowe) i migoczące gwiazdy.

uniform vec3 top_color : source_color = vec3(0.36, 0.62, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.9, 1.0);
uniform vec3 ground_color : source_color = vec3(0.4, 0.45, 0.5);
uniform float night : hint_range(0.0, 1.0) = 0.0;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col;
	if (d.y > 0.0) {
		col = mix(horizon_color, top_color, pow(d.y, 0.5));
	} else {
		col = mix(horizon_color, ground_color, pow(-d.y, 0.4));
	}
	if (LIGHT0_ENABLED) {
		float s = dot(d, LIGHT0_DIRECTION);
		// dzień: słońce z poświatą; noc: jasna tarcza księżyca
		col += LIGHT0_COLOR * (smoothstep(0.9965, 0.9992, s) * 2.2 + pow(max(s, 0.0), 48.0) * 0.3) * (1.0 - night);
		col = mix(col, vec3(0.96, 0.95, 0.86), smoothstep(0.9972, 0.9990, s) * night);
		col += vec3(0.5, 0.55, 0.7) * pow(max(s, 0.0), 200.0) * 0.4 * night;
	}
	if (night > 0.01 && d.y > 0.02) {
		vec3 p = d * 140.0;
		vec3 cell = floor(p);
		float h = hash(cell);
		float star = step(0.975, h) * smoothstep(0.42, 0.05, length(fract(p) - 0.5));
		float twinkle = 0.7 + 0.3 * sin(TIME * 2.5 + h * 60.0);
		col += vec3(1.0, 0.97, 0.9) * star * twinkle * 2.2 * night * smoothstep(0.02, 0.25, d.y);
	}
	COLOR = col;
}
