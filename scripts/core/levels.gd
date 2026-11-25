class_name Levels
extends RefCounted
## 正式关卡表（按顺序）。选关界面、通关后进下一关、解锁进度都读这里。
## 关卡没有名字，只显示三位编号 001、002……；加关卡就往 PATHS 末尾追加路径。
## level_temp、test_02 之类的测试关不在表里：单独运行（F6）照常可玩，通关后按 next_level 或重开。

const MENU := "res://scenes/ui/main_menu.tscn"

const PATHS: Array[String] = [
	"res://levels/level_01.tscn",
	"res://levels/level_02.tscn",
	"res://levels/level_03.tscn",
	"res://levels/level_04.tscn",
	"res://levels/level_05.tscn",
	"res://levels/level_06.tscn",
	"res://levels/level_07.tscn",
	"res://levels/level_08.tscn",
	"res://levels/level_09.tscn",
	"res://levels/level_10.tscn",
	"res://levels/level_11.tscn",
	"res://levels/level_12.tscn",
]


static func count() -> int:
	return PATHS.size()


static func path(i: int) -> String:
	return PATHS[i] if i >= 0 and i < PATHS.size() else ""


static func index_of(p: String) -> int:
	return PATHS.find(p)


## 显示用编号：001、002……
static func label(i: int) -> String:
	return "%03d" % (i + 1)


## 计时格式：00:12.34
static func fmt_time(t: float) -> String:
	return "%02d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]
