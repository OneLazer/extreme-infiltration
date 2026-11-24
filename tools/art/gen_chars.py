"""生成角色精灵表：玩家、地面守卫、无人机。

所有帧 16×16（无人机 16×12），朝右绘制，脚底在第 15 行、水平中心在 x=8。
围巾尾巴、手臂与武器不在精灵里，由 Godot 运行时绘制（围巾是绳模拟，武器跟随鼠标）。
输出 assets/chars/<name>.png（帧横排）+ <name>.json（动画 → 帧号、fps）。
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pal import PL, GD, DR, C, hx
from px import Cv, sprite

PL = dict(PL, h=hx("#2a2250"), H=hx("#5a4c9a"), r=C[2], p=hx("#3d3470"), P=hx("#28214c"), b=hx("#120d22"))

HEAD = [   # 第 4~9 行：头 + 颈部围巾
    ".......HHHr.....",
    ".....hHHHhhr....",
    ".....hhhhhssr...",
    ".....hhhhsos....",
    "......hhssss....",
    ".....MmmmmmM....",
]
HEAD_BLINK = HEAD[:3] + [".....hhhhsSs...."] + HEAD[4:]
TORSO = [  # 第 10~12 行
    ".....kjjjjjJ....",
    ".....kjjjjJJ....",
    ".....kJJJJk.....",
]
TORSO_CROUCH = [".....kjjjjjJ....", "....kJJJJJJk...."]
LEGS = {
    "stand": ["......pp.pp.....", "......Pp.Pp.....", ".....bbb.bbbb..."],
    "run0": [".....pp..pp.....", "....Pp....pp....", "...bbb....bbbb.."],
    "run1": ["......ppppp.....", "......PpPp......", "......bbbbb....."],
    "run2": [".....ppp.pp.....", "....bb....Pp....", "..........bbb..."],
    "run3": ["......pppp......", ".......Ppp......", "......bbbb......"],
    "jump": [".....pp.ppp.....", "....bb...Pp.....", "..........bb...."],
    "fall": [".....pp..pp.....", ".....Pp...Pp....", "....bbb...bbb..."],
    "crouch": [".....pp..pp.....", "....bbb..bbbb..."],
    "wall": ["......pp.pp.....", ".......Pp.Pp....", ".......bbb.bbb.."],
}
FW, FH = 16, 16


def compose(head, torso, legs, keys, head_dx=0, bob=0):
    """自下而上拼：腿贴底，躯干接腿，头接躯干。bob>0 让上半身下沉（落地/呼吸）。"""
    cv = Cv(FW, FH)
    y = FH - len(legs)
    cv.blit(sprite(legs, keys), 0, y)
    y = y - len(torso) + bob
    cv.blit(sprite(torso, keys), 0, y)
    y -= len(head)
    cv.blit(sprite(head, keys), head_dx, y)
    return cv


def player_frames():
    L, H, T = LEGS, HEAD, TORSO
    k = PL
    anims = {
        "idle": ([compose(H, T, L["stand"], k), compose(H, T, L["stand"], k),
                  compose(H, T, L["stand"], k, bob=1), compose(HEAD_BLINK, T, L["stand"], k)], 5, True),
        "run": ([compose(H, T, L["run0"], k, bob=1), compose(H, T, L["run1"], k),
                 compose(H, T, L["run2"], k, bob=1), compose(H, T, L["run3"], k)], 12, True),
        "jump": ([compose(H, T, L["jump"], k)], 1, False),
        "fall": ([compose(H, T, L["fall"], k)], 1, False),
        "land": ([compose(H, TORSO_CROUCH, L["crouch"], k)], 1, False),
        "wall": ([compose(H, T, L["wall"], k)], 1, False),
        "dash": ([compose(H, T, L["jump"], k, head_dx=1)], 1, False),
    }
    return anims


def write_sheet(name, anims, out_dir, fw=FW, fh=FH):
    frames, meta = [], {}
    for an, (fr, fps, loop) in anims.items():
        meta[an] = {"from": len(frames), "count": len(fr), "fps": fps, "loop": loop}
        frames += fr
    sheet = Cv(fw * len(frames), fh)
    for i, f in enumerate(frames):
        sheet.blit(f, i * fw, 0)
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, name + ".png"))
    sil = sheet.im.copy()                      # 白色剪影：残影、受击闪白用
    px = sil.load()
    for y in range(sil.height):
        for x in range(sil.width):
            if px[x, y][3] > 0:
                px[x, y] = (255, 255, 255, 255)
    sil.save(os.path.join(out_dir, name + "_sil.png"))
    with open(os.path.join(out_dir, name + ".json"), "w") as f:
        json.dump({"frame": [fw, fh], "anims": meta}, f, indent=1)
    return sheet
GD = dict(GD, a=hx("#262540"), A=hx("#55577a"), B=hx("#73759a"), Q=hx("#aeb0d0"), w=hx("#14131e"))
GUARD = [
    "................",
    "................",
    "......BQQB......",
    ".....BAAAAQ.....",
    "....aAAAAAAQ....",
    "....aAvvvVVQ....",
    "....aaAAAAAa....",
    "...BQBaAAAQB....",
    "..aBBBaAAvABwwww",
    "..aaBaAAAABwwwQw",
    "...aaaAAAAaw....",
    "....aaaaaaa.....",
    "....aAB..aAB....",
    "....aAB..aAB....",
    "....aaa..aaa....",
    "...oooo..oooo...",
]
GUARD_AIM = GUARD[:6] + [
    "....aaAAAAAawwww",
    "...BQBaAAAQBwwQw",
    "..aBBBaAAvAB....",
    "..aaBaAAAAB.....",
    "...aaaAAAAa.....",
] + GUARD[11:]


def guard_frames():
    alert = dict(GD, v=GD["r"], V=GD["R"])
    breath = ["................"] + GUARD[:-5] + GUARD[-4:]   # 上半身下沉 1px
    return {
        "idle": ([sprite(GUARD, GD), sprite(GUARD, GD), sprite(breath, GD), sprite(breath, GD)], 3, True),
        "alert": ([sprite(GUARD_AIM, alert)], 1, False),
    }


DR = dict(DR, a=hx("#2e2c48"), A=hx("#55547a"), B=hx("#8a88b0"))
DRONE = [
    "................",
    ".AAAA......AAAA.",
    "...B...aa...B...",
    "...BBaAAAAaBB...",
    "....aAAAAAAa....",
    "....aAyYYyAa....",
    "....aaAAAAaa....",
    ".....a.aa.a.....",
]
ROTOR = [["oooooo....oooooo", "..oo........oo.."], ["..oooo....oooo..", "................"]]


def drone_frames():
    fr = []
    for r in ROTOR:
        rows = [r[0]] + DRONE[1:]
        fr.append(sprite(rows + ["................"] * 4, DR))
    return {"hover": (fr, 16, True)}


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "chars")
    write_sheet("player", player_frames(), out)
    write_sheet("guard", guard_frames(), out)
    write_sheet("drone", drone_frames(), out, fh=12)
