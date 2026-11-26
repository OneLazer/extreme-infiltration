extends Node
## 背景音乐（Autoload: Music，排在 Settings 之后：Music 总线由 Settings 建好）。
## 开机后全程循环播放同一首曲子，切关、重开、暂停都不打断。
## 走 Music 总线，设置里的「音乐」开关就是给这条总线静音。

const TRACK := "res://assets/sfx/Neon-Noir Tension.mp3"
const VOLUME_DB := -14.0        ## 压在音效下面，不抢戏

var player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stream := load(TRACK) as AudioStreamMP3
	if stream == null:
		push_warning("Music：无法加载 " + TRACK)
		return
	stream.loop = true
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Music"
	player.volume_db = VOLUME_DB
	add_child(player)
	player.play()
