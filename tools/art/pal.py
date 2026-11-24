"""总色板（街区主题）。所有生成脚本只从这里取色，Godot 侧 scripts/palette.gd 与之对应。

规则：环境色最亮不超过 C3/W3，不参与辉光；只有可交互物在 Godot 里用 >1 的 modulate 发光。
"""


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# 夜色靛蓝：环境主体，暗 → 亮
N = [hx(c) for c in ("#07060f", "#0d0b1e", "#141130", "#1c1842", "#262158", "#332c70", "#463d8c")]
# 冷青描边：结构表面受光
C = [hx(c) for c in ("#1d3a6b", "#2f6fae", "#4fb4e8", "#8fe3ff", "#d8f7ff")]
# 品红霓虹
P = [hx(c) for c in ("#3a1446", "#6e1f6a", "#b8327f", "#ff4f9a", "#ffa3cf")]
# 暖色窗光
W = [hx(c) for c in ("#5a2f3a", "#a8584a", "#e89a5a", "#ffd27a", "#fff1c2")]
# 紫色雾霾（天空）
V = [hx(c) for c in ("#120a2a", "#2a1450", "#4a1f6e", "#7a2f86", "#b5489a")]

# 玩家：浅色战术夹克 + 洋红围巾，在暗背景上是画面里明度最高的移动物
PL = {
    "o": hx("#0b0818"),   # 轮廓/最暗
    "h": hx("#1e1838"), "H": hx("#3d3270"),            # 头发
    "s": hx("#f0c3a0"), "S": hx("#b87a6e"),            # 皮肤
    "j": hx("#e4e0f5"), "J": hx("#a7a1d0"), "k": hx("#6c66a0"),  # 夹克 亮/中/暗
    "p": hx("#2a2148"), "P": hx("#18122c"),            # 裤子
    "b": hx("#0b0818"),                                # 靴
    "m": P[3], "M": P[2], "L": P[4], "D": P[1],       # 围巾
    "g": C[3],                                         # 耳机指示灯
}
# 守卫：深色护甲 + 琥珀面罩（警觉时面罩变红）
GD = {
    "o": hx("#0b0818"),
    "a": hx("#2a2a3e"), "A": hx("#45465e"), "B": hx("#6b6d8a"), "Q": hx("#9a9cb8"),
    "v": hx("#ff9a2e"), "V": hx("#ffd27a"),
    "r": hx("#ff2a3d"), "R": hx("#ffa0a0"),
    "w": hx("#16151f"),   # 枪
}
# 无人机
DR = {
    "o": hx("#0b0818"), "a": hx("#2a2838"), "A": hx("#4a4760"), "B": hx("#77749a"),
    "y": hx("#ffe04a"), "Y": hx("#fff6b8"), "r": hx("#ff2a3d"),
}
# 武器色（与 weapon_defs 对应，基色 0..1，Godot 里再乘亮度发光）
WPN = {
    "dart": hx("#5ff2f2"), "boomerang": hx("#6cf28a"),
    "heavy": hx("#a98cff"), "airgun": hx("#ffa64a"), "rapier": hx("#e6ecff"),
}
ELECTRIC = hx("#ff2a5a")   # 高压电（Godot 里 Palette.ELECTRIC 用 HDR 版本）
EXIT_GREEN = hx("#4dff8a")
ALERT = hx("#ff2a3d")
CLEAR = (0, 0, 0, 0)
