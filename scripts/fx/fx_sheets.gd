class_name FxSheets
extends RefCounted
## pixelfx 烘焙的序列帧特效（见 tools/art/bake_fx.py）。按名字取贴图和帧信息。

const META := preload("res://assets/fx/fx_sheets_meta.gd")

static var _cache: Dictionary = {}


static func get_sheet(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	if not META.SHEETS.has(name):
		return {}
	var d: Dictionary = META.SHEETS[name].duplicate()
	d["tex"] = load("res://assets/fx/%s.png" % name)
	_cache[name] = d
	return d
