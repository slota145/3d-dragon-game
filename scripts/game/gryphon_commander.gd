class_name GryphonCommander
extends GryphonRider
## Boss: dowódca jeźdźców gryfów na wielkim gryfie. Siedzi na wieży-gnieździe zamku (Castle.eyrie_top),
## startuje, gdy smok zbliży się do zamku, i walczy do końca (bez ucieczki). Pancerz: smok
## mniejszy niż pradawny zadaje mu ułamek obrażeń (ARMOR_FACTOR). Faza 2 (poniżej połowy
## zdrowia): szybsze i mocniejsze szarże, z wież wylatują posiłki (sygnał phase_two).

signal phase_two(boss: GryphonCommander)
signal armor_blocked(boss: GryphonCommander)

## Od tego stadium smok przebija pancerz.
const ARMOR_STAGE := DragonStats.Stage.ANCIENT
const ARMOR_FACTOR := 0.15

var phase: int = 1


## Ugryzienie / ogień: przez pancerz przechodzi tylko siła pradawnego smoka.
func take_bite(damage: float) -> bool:
	var dc := dragon as DragonController
	if dc and dc.stats.stage < ARMOR_STAGE:
		damage *= ARMOR_FACTOR
		armor_blocked.emit(self)
	var died := super.take_bite(damage)
	if not died and phase == 1 and health < max_health * 0.5:
		phase = 2
		attack_speed *= 1.2
		attack_damage *= 1.3
		phase_two.emit(self)
	return died
