extends Node
## 进度存档（Autoload: Progress）。存在 user://save.cfg。
##   unlocked：已解锁的关卡数（至少 1）。通关第 i 关解锁第 i+1 关
##   best：每关最佳用时（按关卡路径存，关卡表调整顺序后记录不会错位）
## 设置里打开「解锁全部关卡」时 is_unlocked 恒为真，但不改存档。

const PATH := "user://save.cfg"

var unlocked := 1
var best := {}            ## 路径 → 最佳用时（秒）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		unlocked = clampi(int(cf.get_value("progress", "unlocked", 1)), 1, Levels.count())
		best = cf.get_value("progress", "best", {})


func is_unlocked(i: int) -> bool:
	return i >= 0 and i < Levels.count() and (i < unlocked or bool(Settings.get_value("unlock_all")))


func is_cleared(i: int) -> bool:
	return best.has(Levels.path(i))


func best_time(i: int) -> float:
	return float(best.get(Levels.path(i), -1.0))


## 通关记录。返回 true 表示刷新了最佳用时（含首次通关）
func record_clear(i: int, t: float) -> bool:
	if i < 0:
		return false
	var p := Levels.path(i)
	var is_best := not best.has(p) or t < float(best[p])
	if is_best:
		best[p] = t
	unlocked = clampi(maxi(unlocked, i + 2), 1, Levels.count())
	_save()
	return is_best


## 「开始游戏」去哪一关：第一个已解锁但没通关的；全通了就回第一关
func resume_index() -> int:
	for i in mini(unlocked, Levels.count()):
		if not is_cleared(i):
			return i
	return 0


## 是否有任何进度（主菜单「开始游戏」旁显示继续的关卡编号）
func has_progress() -> bool:
	return not best.is_empty()


## 有没有可清空的东西（设置页「清空游戏存档」据此决定能不能点）
func has_save() -> bool:
	return unlocked > 1 or not best.is_empty()


## 清空存档：解锁进度回到第一关，最佳用时全部删除。设置不受影响（另存在 settings.cfg）
func clear() -> void:
	unlocked = 1
	best = {}
	_save()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "best", best)
	cf.save(PATH)
