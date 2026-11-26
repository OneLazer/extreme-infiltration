extends Node
## 设置（Autoload: Settings）。存在 user://settings.cfg，改动立即生效并保存。
## 其他脚本读 Settings.get_value(key)，或者用下面的便捷属性（shake_mult 等）。
## 键：
##   fullscreen  全屏（否则窗口）        window_scale  窗口整数倍 2..6
##   vsync       垂直同步               post_fx       后期（暗角、扫描线、颗粒、色差）
##   shake       屏幕震动 0..10 档      flash         闪光强度 0..10 档（闪白、色差脉冲）
##   glow        辉光强度 0..10 档（乘在场景 WorldEnvironment 的辉光上，0 = 关闭）
##   show_timer  HUD 计时               music / sfx   音乐、音效开关
##   unlock_all  解锁全部关卡（测试用）

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"fullscreen": false, "window_scale": 4, "vsync": true, "post_fx": true,
	"shake": 10, "flash": 10, "glow": 10, "show_timer": true,
	"music": true, "sfx": true, "unlock_all": false,
}
const BASE := Vector2i(320, 180)

var _v := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_v = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	var had_file := cf.load(PATH) == OK
	if had_file:
		for k in DEFAULTS:
			_v[k] = cf.get_value("settings", k, DEFAULTS[k])
	_apply_all(had_file)
	# 辉光：每个进树的 WorldEnvironment（关卡、主菜单）都乘上辉光档位
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_on_node_added(n)


func get_value(key: String) -> Variant:
	return _v.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if _v.get(key) == value:
		return
	_v[key] = value
	_apply(key)
	_save()
	changed.emit(key)


## 把一组键恢复默认（设置页每个分页的「恢复默认」）
func reset(keys: Array) -> void:
	for k in keys:
		set_value(k, DEFAULTS[k])


var shake_mult: float:
	get:
		return float(get_value("shake")) / 10.0

var flash_mult: float:
	get:
		return float(get_value("flash")) / 10.0

var glow_mult: float:
	get:
		return float(get_value("glow")) / 10.0


## 当前屏幕放得下的最大窗口倍数（留出任务栏和标题栏）
func max_scale() -> int:
	var scr := DisplayServer.window_get_current_screen()
	var r := DisplayServer.screen_get_usable_rect(scr).size
	if r.x <= 0 or r.y <= 0:
		return 6
	return clampi(mini(r.x / BASE.x, (r.y - 40) / BASE.y), 2, 6)


func _save() -> void:
	var cf := ConfigFile.new()
	for k in _v:
		cf.set_value("settings", k, _v[k])
	cf.save(PATH)


## 启动时：没有设置文件就不动窗口（保持项目默认的 1280×720）
func _apply_all(had_file: bool) -> void:
	for k in ["vsync", "music", "sfx"]:
		_apply(k)
	if had_file:
		_apply("fullscreen")
	# ScreenFx 在本节点之前加载完；后期开关晚一帧写，保证它已 _ready
	_apply.call_deferred("post_fx")


func _apply(key: String) -> void:
	match key:
		"fullscreen", "window_scale":
			_apply_window()
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)
		"post_fx":
			ScreenFx.enabled = bool(get_value("post_fx"))
		"music":
			_mute("Music", not get_value("music"))
		"sfx":
			_mute("SFX", not get_value("sfx"))
		"glow":
			for n in get_tree().get_nodes_in_group(GLOW_GROUP):
				_apply_glow(n as WorldEnvironment)


const GLOW_GROUP := &"settings_glow_env"
const GLOW_BASE := &"_glow_base"     ## Environment 上记的原始值 [enabled, intensity, bloom]


func _on_node_added(n: Node) -> void:
	if n is WorldEnvironment:
		n.add_to_group(GLOW_GROUP)
		# 代码里创建的 WorldEnvironment 可能先进树、后赋 environment，晚一拍再读
		_apply_glow.call_deferred(n)


## 按档位缩放辉光强度和泛光。原始值记在 Environment 资源的 meta 上：
## 同一关卡场景重开时实例共用这份资源，不能每次把已经缩放过的值当成原始值
func _apply_glow(we: WorldEnvironment) -> void:
	if not is_instance_valid(we) or we.environment == null:
		return
	var env := we.environment
	if not env.has_meta(GLOW_BASE):
		env.set_meta(GLOW_BASE, [env.glow_enabled, env.glow_intensity, env.glow_bloom])
	var base: Array = env.get_meta(GLOW_BASE)
	var m := glow_mult
	env.glow_enabled = bool(base[0]) and m > 0.0
	env.glow_intensity = float(base[1]) * m
	env.glow_bloom = float(base[2]) * m


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if get_value("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var s := clampi(int(get_value("window_scale")), 2, max_scale())
	var size := BASE * s
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _mute(bus: String, on: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_mute(i, on)


## 音频总线：Music、SFX 都接到 Master。项目里没有 default_bus_layout.tres，就在运行时补上
func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
