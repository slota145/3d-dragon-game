class_name DayNight
extends Node
## Cykl dnia i nocy: przesuwa słońce (nocą księżyc), zmienia kolory nieba, światła otoczenia
## i mgły. Dzień (6:00–20:00) trwa `day_minutes` minut, noc szybciej — `night_minutes`.
## Noc jest ciemniejsza, ale grywalna na telefonie. Godzinę zapisuje świat (save).

signal midnight  ## nowy dzień kalendarzowy
signal dusk  ## zmierzch (20:00) — pora wracać do legowiska

@export var day_minutes: float = 10.0
@export var night_minutes: float = 4.0
## Godzina 0..24.
@export var hour: float = 8.0
@export var paused: bool = false

var sun: DirectionalLight3D
var environment: Environment

const DAY_START := 6.0
const DAY_END := 20.0

## Klucze: godzina, góra nieba, horyzont, światło otoczenia, energia otoczenia,
## kolor światła kierunkowego, energia światła kierunkowego.
const KEYS := [
	[0.0, Color(0.03, 0.04, 0.1), Color(0.08, 0.1, 0.18), Color(0.3, 0.36, 0.55), 0.55, Color(0.6, 0.7, 1.0), 0.3],
	[4.5, Color(0.03, 0.04, 0.1), Color(0.08, 0.1, 0.18), Color(0.3, 0.36, 0.55), 0.55, Color(0.6, 0.7, 1.0), 0.3],
	[6.0, Color(0.25, 0.34, 0.55), Color(0.9, 0.6, 0.45), Color(0.6, 0.55, 0.6), 0.65, Color(1.0, 0.68, 0.45), 0.55],
	[8.0, Color(0.36, 0.62, 0.95), Color(0.78, 0.9, 1.0), Color(0.75, 0.82, 0.95), 0.7, Color(1.0, 0.95, 0.85), 1.3],
	[17.5, Color(0.36, 0.62, 0.95), Color(0.8, 0.9, 1.0), Color(0.78, 0.8, 0.92), 0.7, Color(1.0, 0.93, 0.8), 1.3],
	[19.5, Color(0.28, 0.3, 0.5), Color(0.95, 0.5, 0.35), Color(0.62, 0.5, 0.55), 0.65, Color(1.0, 0.55, 0.35), 0.6],
	[21.0, Color(0.03, 0.04, 0.1), Color(0.08, 0.1, 0.18), Color(0.3, 0.36, 0.55), 0.55, Color(0.6, 0.7, 1.0), 0.3],
	[24.0, Color(0.03, 0.04, 0.1), Color(0.08, 0.1, 0.18), Color(0.3, 0.36, 0.55), 0.55, Color(0.6, 0.7, 1.0), 0.3],
]


## 0..1 — jak bardzo jest noc (gwiazdy, świetliki, światła w oknach); płynnie o zmierzchu i świcie.
func night_factor() -> float:
	if hour >= 12.0:
		return smoothstep(19.5, 21.0, hour)
	return 1.0 - smoothstep(4.5, 6.0, hour)


func is_night() -> bool:
	return hour >= DAY_END or hour < DAY_START


func clock_text() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]


## Ustaw godzinę (np. po śnie / wczytaniu) i od razu odśwież oświetlenie.
func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_apply()


func _process(delta: float) -> void:
	if paused:
		return
	var minutes := night_minutes if is_night() else day_minutes
	var span := (24.0 - (DAY_END - DAY_START)) if is_night() else (DAY_END - DAY_START)
	var before := hour
	hour += delta * span / (minutes * 60.0)
	if before < DAY_END and hour >= DAY_END:
		dusk.emit()
	if hour >= 24.0:
		hour -= 24.0
		midnight.emit()
	_apply()


func _apply() -> void:
	var k := _sample()
	if environment:
		var sky := environment.sky.sky_material as ShaderMaterial if environment.sky else null
		if sky:
			sky.set_shader_parameter("top_color", k[0])
			sky.set_shader_parameter("horizon_color", k[1])
			sky.set_shader_parameter("ground_color", (k[1] as Color).darkened(0.5))
			sky.set_shader_parameter("night", night_factor())
		environment.ambient_light_color = k[2]
		environment.ambient_light_energy = k[3]
		environment.fog_light_color = k[1]
	if sun:
		sun.light_color = k[4]
		sun.light_energy = k[5]
		# dzień: słońce wędruje ze wschodu na zachód; noc: księżyc po przeciwnej stronie
		var a := (hour - DAY_START) / (DAY_END - DAY_START) * PI
		if is_night():
			var n := fposmod(hour - DAY_END, 24.0) / (24.0 - (DAY_END - DAY_START))
			a = n * PI
		var elev := maxf(sin(a), 0.0) * 0.85 + 0.2  # nigdy całkiem płasko — cienie nie znikają w nieskończoność
		var to_light := Vector3(cos(a) * 0.9, elev, 0.4).normalized()
		sun.basis = Basis.looking_at(-to_light, Vector3.UP if absf(to_light.y) < 0.99 else Vector3.FORWARD)


## Interpolacja kluczy dla bieżącej godziny: [góra, horyzont, otoczenie, energia otocz., kolor światła, energia].
func _sample() -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		var h0: float = a[0]
		var h1: float = b[0]
		if hour >= h0 and hour <= h1:
			var t: float = (hour - h0) / maxf(h1 - h0, 0.001)
			t = t * t * (3.0 - 2.0 * t)
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t), (a[3] as Color).lerp(b[3], t),
				lerpf(a[4], b[4], t), (a[5] as Color).lerp(b[5], t), lerpf(a[6], b[6], t)]
	var last: Array = KEYS[0]
	return [last[1], last[2], last[3], last[4], last[5], last[6]]
