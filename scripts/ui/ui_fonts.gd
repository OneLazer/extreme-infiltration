class_name UiFonts
extends RefCounted
## 像素字体：关闭抗锯齿与 hinting。HUD 在根视口按窗口分辨率渲染（1 画布单位 = 窗口整数倍像素），
## 所以字号取「原生像素高 ÷ 2」就能半个游戏像素一格、依然锐利：
##   text()  缝合像素 12px → 用 6（中文 HUD 文字）
##   num()   m6x11（原生 16）→ 用 8（数字，小丑牌同款，只含拉丁字符）
##   big()   粗宋像素（原生 12）→ 用 12（大标题，一格 = 一个游戏像素）
##   small() 缝合像素 8px → 用 8（和游戏像素同格的小字，备用）

static var _cache := {}


static func _font(path: String) -> FontFile:
	if _cache.has(path):
		return _cache[path]
	var f := load(path) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	_cache[path] = f
	return f


static func text() -> FontFile:
	return _font("res://fonts/fusion-pixel-12px-monospaced-zh_hans.ttf")


static func small() -> FontFile:
	return _font("res://fonts/fusion-pixel-8px-monospaced-zh_hans.ttf")


static func num() -> FontFile:
	return _font("res://fonts/m6x11.ttf")


static func big() -> FontFile:
	return _font("res://fonts/Chusung-220206.ttf")
