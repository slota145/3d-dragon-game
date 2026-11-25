class_name GryphonRider
extends Gryphon
## Jeździec gryfa królestwa: gryf w czerwonym rzędzie (people.glb: Tack) z rycerzem w siodle.
## Zachowanie jak dzikiego gryfa (Gryphon), ale „gniazdem” jest wieża zamku, a szarża to cios
## kopią. Z oddziału łowców (`hunter`) poluje na smoka w całym świecie.
## Jeździec: Body/Rider (części postaci z people.glb) — nogi w strzemionach, kopia w szarży poziomo.

## Ściga smoka wszędzie (rozgłos „Legenda”), nie tylko na terytorium wieży.
var hunter: bool = false
var _rider: Node3D
var _arm_l: Node3D
var _arm_r: Node3D


func _ready() -> void:
	super._ready()
	_rider = _body.get_node_or_null("Rider") if _body else null
	if _rider:
		_arm_l = _rider.get_node_or_null("ArmL")
		_arm_r = _rider.get_node_or_null("ArmR")
		var ll := _rider.get_node_or_null("LegL") as Node3D
		var lr := _rider.get_node_or_null("LegR") as Node3D
		if ll and lr:  # w strzemionach, okrakiem na grzbiecie
			ll.rotation = Vector3(-0.9, 0.0, 0.6)
			lr.rotation = Vector3(-0.9, 0.0, -0.6)


func _animate(delta: float) -> void:
	super._animate(delta)
	if not _arm_r:
		return
	var k := clampf(8.0 * delta, 0.0, 1.0)
	var r := -0.25
	if mode == Mode.ATTACK:
		r = -1.45  # kopia do przodu
	elif mode == Mode.FLEE:
		r = PI * 0.8  # przerażony — ręka w górze
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, r, k)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.5, k)  # wodze / tarcza
