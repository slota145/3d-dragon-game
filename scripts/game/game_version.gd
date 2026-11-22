class_name GameVersion
extends RefCounted
## Wersja gry: wbudowana (application/config/version) lub wersja łatki pobranej z GitHuba.

const PATCH_PATH := "user://update.pck"
const PATCH_VERSION_PATH := "user://update_version.txt"

static var patched_version := ""


static func builtin() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func current() -> String:
	return patched_version if patched_version != "" else builtin()


## Porównanie wersji "1.2.3" / "v1.2.3": >0 gdy a nowsza, <0 gdy starsza, 0 gdy równe.
static func compare(a: String, b: String) -> int:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0
