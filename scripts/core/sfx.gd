extends Node
## 音效（Autoload: Sfx）。音效文件在 assets/sfx/*.wav，由 tools/audio/gen_sfx.py 用代码合成。
##   Sfx.play(名字, 音高随机幅度, 音量 dB, 基础音高)
## 每个名字一个 AudioStreamPlayer（最多同时 4 个声部），走 SFX 总线；暂停时照常播放（菜单音效）。
## 玩家的动作音效在 bind_player 里接信号，不改 Player / PlayerVisual。

const DIR := "res://assets/sfx/%s.wav"
const MIN_GAP := 0.035          ## 同一个音效两次触发的最短间隔（秒），防止叠成噪音

var _players := {}
var _last := {}
var _weapon_sig := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(sfx: String, jitter := 0.0, db := 0.0, pitch := 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sfx, -1.0)) < MIN_GAP:
		return
	_last[sfx] = now
	var pl := _player(sfx)
	if pl == null:
		return
	pl.pitch_scale = maxf(pitch * (1.0 + randf_range(-jitter, jitter)), 0.05)
	pl.volume_db = db
	pl.play()


func _player(sfx: String) -> AudioStreamPlayer:
	if _players.has(sfx):
		return _players[sfx]
	var path := DIR % sfx
	var pl: AudioStreamPlayer = null
	if ResourceLoader.exists(path):
		pl = AudioStreamPlayer.new()
		pl.stream = load(path)
		pl.bus = "SFX"
		pl.max_polyphony = 4
		add_child(pl)
	else:
		push_warning("Sfx：缺少音效 " + path)
	_players[sfx] = pl
	return pl

# ======================= 玩家动作 =======================

func bind_player(p: Player) -> void:
	_weapon_sig = _sig(p)
	p.jumped.connect(_on_jumped)
	p.landed.connect(_on_landed)
	p.shot.connect(_on_shot)
	p.thrown.connect(_on_thrown)
	p.teleported.connect(func(_a, _b): play("blink", 0.05, -2.0))
	p.thrust.connect(func(_d): play("rapier", 0.05))
	p.deflected.connect(func(_f): play("deflect", 0.06))
	p.died.connect(_on_died.bind(p))
	p.weapons_changed.connect(_on_weapons_changed.bind(p))


func _on_jumped(kind: int, _dir: int) -> void:
	match kind:
		Player.JumpKind.GROUND:
			play("jump", 0.06, -4.0)
		Player.JumpKind.AIR:
			play("jump_air", 0.04, -3.0)
		Player.JumpKind.SUPER, Player.JumpKind.HYPER:
			play("jump_super", 0.04, -2.0)
		_:
			play("jump_wall", 0.06, -3.0)


func _on_landed(fall_speed: float) -> void:
	if fall_speed < 50.0:
		return
	var k := clampf(inverse_lerp(50.0, 160.0, fall_speed), 0.0, 1.0)
	play("land", 0.08, lerpf(-14.0, -4.0, k), lerpf(1.15, 0.9, k))


func _on_shot(type: int, _from: Vector2, _dir: Vector2, _res: Dictionary) -> void:
	if type == WeaponDefs.Type.AIR_GUN:
		play("airgun", 0.05)
	else:
		play("dart", 0.06, -2.0)


func _on_thrown(type: int, _dir: Vector2) -> void:
	if type == WeaponDefs.Type.HEAVY_BOOMERANG:
		play("throw", 0.05, 0.0, 0.8)
	else:
		play("throw", 0.06, -2.0)


func _on_died(p: Player) -> void:
	match p.death_cause:
		"electric":
			play("zap")
		"timeout":
			play("timeout")
		_:
			play("death")


## 拿到新武器（队列变长或主武器换了）响一声；开火扣弹药不响
func _on_weapons_changed(p: Player) -> void:
	var sig := _sig(p)
	var old := _weapon_sig
	_weapon_sig = sig
	if sig == old or p.dead:
		return
	var parts := old.split("|")
	var grew := p.weapon_queue.size() > int(parts[1]) if parts.size() > 1 else true
	var main_changed := parts[0] != str(p.initial_weapon)
	if grew or main_changed:
		play("pickup", 0.03)


func _sig(p: Player) -> String:
	return "%d|%d|%s" % [p.initial_weapon, p.weapon_queue.size(), str(p.weapon_queue)]
