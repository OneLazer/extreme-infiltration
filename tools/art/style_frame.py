"""风格样张：用正式素材把 level_01 左半段合成成一张 320×180 的游戏画面（再放大 4 倍）。

只用于定美术方向；游戏里的实际画面由 Godot 节点实时组合，逻辑与这里一致。
用法：python3 style_frame.py <输出.png>
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageFilter, ImageChops
from pal import N, C, P, W, V, GD as _GD, hx
from px import Cv, BAYER4, alpha, lerp, sprite
import gen_tiles, gen_bg, gen_chars, gen_props

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VW, VH = 320, 180
CAM = (0, 4)                       # 视口左上角在关卡中的位置
FLOOR = 168


def wpos(x, y):
    return int(x - CAM[0]), int(y - CAM[1])


def load_map():
    rows = open(os.path.join(os.path.dirname(__file__), "map_level01.txt")).read().split()
    return [[c == "#" for c in r] for r in rows]


def layer_bg(frame):
    sky = gen_bg.sky().im
    frame.alpha_composite(sky)
    for name, k in (("city_far", 0.1), ("city_mid", 0.25), ("city_near", 0.45)):
        cv = Image.open(os.path.join(ROOT, "assets", "bg", name + ".png"))
        ox = int(CAM[0] * k) % gen_bg.BW
        frame.alpha_composite(cv.crop((ox, 0, ox + VW, VH)), (0, 6))
def layer_backwall(frame):
    """玻璃幕墙：窗格竖梃、横档、窗台护墙、吊顶。比实心地形亮、但没有青色描边，避免被误读成平台。"""
    cv = Cv(VW, VH)
    x0, x1, y0, y1 = 8, 632, 8, FLOOR
    for wy in range(y0, y1):
        for wx in range(x0, x1):
            x, y = wpos(wx, wy)
            if not (0 <= x < VW and 0 <= y < VH):
                continue
            c = alpha(N[2], 110)                                 # 玻璃色调
            pane = (wx - 32) // 48
            if pane % 3 == 0 and 0 <= (wx - wy * 0.6 - pane * 31) % 70 < 5:
                c = alpha(C[1], 40)                              # 斜向反光，只在部分窗格
            cv.put(x, y, c)
    for mx in range(32, x1, 48):                                 # 竖梃
        for wy in range(y0, 152):
            for i, k in enumerate((N[1], N[3], N[4])):
                cv.put(*wpos(mx + i, wy), k)
    for ty in (62, 110):                                         # 横档
        for wx in range(x0, x1):
            cv.put(*wpos(wx, ty), N[4]); cv.put(*wpos(wx, ty + 1), N[1])
    for wy in range(150, FLOOR):                                 # 窗台护墙
        for wx in range(x0, x1):
            k = N[3]
            if wy == 150: k = N[5]
            elif wy == 151: k = N[4]
            elif wy >= 165: k = N[2]
            elif wx % 32 == 0: k = N[2]
            cv.put(*wpos(wx, wy), k)
    for wy in range(8, 13):                                      # 吊顶
        for wx in range(x0, x1):
            cv.put(*wpos(wx, wy), N[2] if wy < 12 else N[4])
    frame.alpha_composite(cv.im)


def layer_tiles(frame, grid):
    sheet, meta = gen_tiles.build("/tmp/_tiles")
    look = {}
    for e in meta:
        look.setdefault(e["mask"], []).append(e)
    for (tx, ty), m in gen_tiles.autotile(grid).items():
        opts = look[m]
        h = (tx * 73856093 ^ ty * 19349663) % 1000 / 1000
        pick = opts[0]
        acc = 0
        for e in opts[1:]:                  # 按概率挑变体（确定性哈希）
            acc += e["prob"]
            if h < acc:
                pick = e; break
        x, y = wpos(tx * 8, ty * 8)
        if -8 < x < VW and -8 < y < VH:
            comp(frame, sheet.im.crop((pick["x"] * 8, pick["y"] * 8, pick["x"] * 8 + 8, pick["y"] * 8 + 8)), x, y)
def comp(dst, img, x, y):
    """带负坐标裁剪的 alpha 合成。"""
    if isinstance(img, Cv):
        img = img.im
    l, t = max(0, -x), max(0, -y)
    r, b = min(img.width, dst.width - x), min(img.height, dst.height - y)
    if r <= l or b <= t:
        return
    dst.alpha_composite(img.crop((l, t, r, b)), (x + l, y + t))


PROPS_AT = [   # 名称, 世界 x（底边中心）, 底边 y
    ("plant", 15, FLOOR), ("desk", 82, FLOOR), ("chair", 98, FLOOR), ("trash", 58, FLOOR),
    ("vending", 198, FLOOR), ("cooler", 232, FLOOR), ("server", 300, FLOOR), ("server", 313, FLOOR),
    ("lamp", 56, 15), ("lamp", 120, 15), ("lamp", 232, 15), ("lamp", 296, 15),
    ("neon_ye", 258, 92),
]


def layer_props(frame, emit):
    sheet = gen_props.build("/tmp/_props")
    col, emi, rects = sheet
    for name, wx, wy in PROPS_AT:
        rx, ry, w, h = rects[name]
        x, y = wpos(wx - w // 2, wy - h)
        comp(frame, col.im.crop((rx, ry, rx + w, ry + h)), x, y)
        comp(emit, emi.im.crop((rx, ry, rx + w, ry + h)), x, y)
    return rects


def add_light(light, cx, cy, poly_fn, col, a):
    """往加色光层画一块像素化的光（3 级硬色阶，不做平滑渐变）。"""
    for y in range(VH):
        for x in range(VW):
            k = poly_fn(x, y)
            if k > 0:
                lvl = 1 if k < 0.34 else (2 if k < 0.67 else 3)
                c = light.getpixel((x, y))
                light.putpixel((x, y), tuple(min(255, c[i] + int(col[i] * a * lvl / 3)) for i in range(3)) + (255,))


def lamp_cone(lx, ly, top_w=7, bot_w=34, bottom=FLOOR):
    def f(x, y):
        wx, wy = x + CAM[0], y + CAM[1]
        if not (ly <= wy < bottom):
            return 0
        t = (wy - ly) / (bottom - ly)
        half = top_w + (bot_w - top_w) * t
        dx = abs(wx - lx)
        if dx > half:
            return 0
        edge = 1 - dx / half
        return min(1, edge * 1.3) * (1 - 0.55 * t)
    return f


def glow_disc(cx, cy, r, squash=1.0):
    def f(x, y):
        d = math.hypot(x + CAM[0] - cx, (y + CAM[1] - cy) / squash)
        return max(0, 1 - d / r)
    return f
def frame_of(name, anim, i=0, fw=16, fh=16):
    meta = json.load(open(os.path.join(ROOT, "assets", "chars", name + ".json")))
    sheet = Image.open(os.path.join(ROOT, "assets", "chars", name + ".png"))
    f = meta["anims"][anim]["from"] + i
    return sheet.crop((f * fw, 0, f * fw + fw, fh))


def solid_at(grid, wx, wy):
    tx, ty = int(wx // 8), int(wy // 8)
    return not (0 <= ty < len(grid) and 0 <= tx < len(grid[0])) or grid[ty][tx]


def vision_cone(frame, grid, ex, ey, facing, rng_=96, half=35):
    """守卫视野：琥珀色加色光（Godot 里用 add 混合），亮边弧线，被墙裁切。"""
    light = Image.new("RGB", (VW, VH))
    lp = light.load()
    a0 = 0 if facing > 0 else math.pi
    for y in range(VH):
        for x in range(VW):
            wx, wy = x + CAM[0], y + CAM[1]
            dx, dy = wx - ex, wy - ey
            d = math.hypot(dx, dy)
            if d < 3 or d > rng_:
                continue
            ang = abs((math.atan2(dy, dx) - a0 + math.pi) % (2 * math.pi) - math.pi)
            if ang > math.radians(half):
                continue
            steps = int(d / 2)
            if any(solid_at(grid, ex + dx * s / steps, ey + dy * s / steps) for s in range(1, steps + 1)):
                continue
            t = d / rng_
            edge = d > rng_ - 1.5 or ang > math.radians(half) - 0.9 / max(d, 1)
            if edge:
                k = 0.55 * (1 - t * 0.5)
            elif (y + int(t * 3)) % 3 == 0 and BAYER4[y & 3][x & 3] < 8:
                k = 0.32 * (1 - t)          # 传感扫描线：稀疏的亮点行
            else:
                k = 0.05 * (1 - t)
            c = _GD["V"]
            lp[x, y] = (int(c[0] * k), int(c[1] * k), int(c[2] * k))
    rgb = ImageChops.add(frame.convert("RGB"), light)
    frame.paste(Image.merge("RGBA", (*rgb.split(), frame.split()[3])))


def scarf(frame, emit, pts):
    """围巾尾巴：洋红，根部 2px 粗、末端 1px，上缘亮色。Godot 里是 verlet 绳。"""
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(n + 1):
            x = round(x0 + (x1 - x0) * s / n); y = round(y0 + (y1 - y0) * s / n)
            for img in (frame, emit):
                img.putpixel((x, y), P[3])
                if i < 2:
                    img.putpixel((x, y + 1), P[2])
def pickup(frame, emit, rects, sheet, wx, wy, icon, col):
    x, y = wpos(wx, wy)
    br = alpha(col, 230)
    for (cx, cy, dx, dy) in ((-6, -6, 1, 1), (5, -6, -1, 1), (-6, 5, 1, -1), (5, 5, -1, -1)):   # 角括号
        for img in (frame, emit):
            for k in range(3):
                img.putpixel((x + cx + dx * k, y + cy), br); img.putpixel((x + cx, y + cy + dy * k), br)
    rx, ry, w, h = rects["icon_" + icon]
    ic = sheet.crop((rx, ry, rx + w, ry + h))
    comp(frame, ic, x - 4, y - 4); comp(emit, ic, x - 4, y - 4)
    for yy in range(y - 5, y + 5, 2):      # 全息扫描线
        for xx in range(x - 5, x + 5):
            if frame.getpixel((xx, yy))[3]:
                frame.putpixel((xx, yy), lerp(frame.getpixel((xx, yy)), col, 0.12))


def hud(frame, rects, sheet):
    """左上角：当前武器 + 守卫数 + 计时。半透明底条，8px 缝合像素体。"""
    from gen_bg import glyphs
    bar = Cv(VW, 13)
    bar.rect(0, 0, 118, 12, alpha(N[0], 170)); bar.hline(0, 117, 12, alpha(C[1], 160))
    frame.alpha_composite(bar.im)
    rx, ry, w, h = rects["icon_dart"]
    comp(frame, sheet.crop((rx, ry, rx + w, ry + h)), 3, 2)

    def text(s, x, y, c):
        for j, row in enumerate(glyphs(s)):
            for i, on in enumerate(row):
                if on:
                    frame.putpixel((x + i, y + j), c)
        return x + len(glyphs(s)[0]) + 1
    x = text("∞", 13, 3, C[4])
    x = text("守卫", x + 8, 2, N[6]); x = text("7", x + 2, 2, W[3])
    text("00:01.4", x + 8, 2, C[3])


def crosshair(frame, emit, x, y, col):
    for d in (2, 3):
        for (dx, dy) in ((d, 0), (-d, 0), (0, d), (0, -d)):
            frame.putpixel((x + dx, y + dy), col); emit.putpixel((x + dx, y + dy), col)
    frame.putpixel((x, y), col)


def bloom(frame, emit):
    """模拟 Godot 的 HDR 辉光：只对发光层模糊后加色叠加。"""
    e = emit.convert("RGB")
    small = e.filter(ImageFilter.GaussianBlur(2))
    wide = e.filter(ImageFilter.GaussianBlur(7))
    out = frame.convert("RGB")
    out = ImageChops.add(out, small.point(lambda v: int(v * 0.55)))
    out = ImageChops.add(out, wide.point(lambda v: int(v * 0.45)))
    return out.convert("RGBA")
def emissive(img, keys):
    out = Image.new("RGBA", img.size)
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y)) in keys:
                out.putpixel((x, y), img.getpixel((x, y)))
    return out


def actor(frame, emit, img, wx, feet_y, keys, flip=False):
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    x, y = wpos(wx - 8, feet_y - img.height)
    comp(frame, img, x, y); comp(emit, emissive(img, keys), x, y)
    return x, y


def render(out_path):
    grid = load_map()
    frame = Image.new("RGBA", (VW, VH), N[0])
    emit = Image.new("RGBA", (VW, VH), (0, 0, 0, 0))
    layer_bg(frame)
    layer_backwall(frame)
    rects = layer_props(frame, emit)
    layer_tiles(frame, grid)
    psheet = Image.open("/tmp/_props/props.png")
    # 灯光（加色）
    light = Image.new("RGBA", (VW, VH), (0, 0, 0, 255))
    for lx in (56, 120, 232, 296):
        add_light(light, 0, 0, lamp_cone(lx, 15), C[3], 0.16)
    add_light(light, 0, 0, glow_disc(198, 160, 22, 0.8), P[3], 0.22)
    add_light(light, 0, 0, glow_disc(82, 157, 14, 0.8), P[3], 0.16)
    add_light(light, 0, 0, glow_disc(258, 78, 20), P[3], 0.14)
    frame = Image.merge("RGBA", (*ImageChops.add(frame.convert("RGB"), light.convert("RGB")).split(), frame.split()[3]))
    # 实体
    vision_cone(frame, grid, 126, 159, 1)
    actor(frame, emit, frame_of("guard", "idle"), 124, 168, {_GD["v"], _GD["V"]})
    actor(frame, emit, frame_of("guard", "alert"), 330, 168, {(255, 42, 61, 255)}, flip=True)
    for dx, dy in ((84, 124), (244, 68)):
        actor(frame, emit, frame_of("drone", "hover", 0, 16, 12), dx, dy + 6, {(255, 224, 74, 255), (255, 246, 184, 255)})
    from pal import WPN
    pickup(frame, emit, rects, psheet, 52, 160, "boomerang", WPN["boomerang"])
    pickup(frame, emit, rects, psheet, 212, 160, "heavy", WPN["heavy"])
    # 玩家：起跳中，瞄准无人机
    px_, feet = 38, 152
    x, y = actor(frame, emit, frame_of("player", "jump"), px_, feet, {P[3], P[2], C[2]})
    scarf(frame, emit, [(x + 5, y + 9), (x + 3, y + 9), (x + 1, y + 10), (x - 2, y + 10), (x - 4, y + 12)])
    rx, ry, w, h = rects["gun_dart"]
    gun = psheet.crop((rx, ry, rx + w, ry + h)).rotate(20, expand=True, resample=Image.NEAREST)
    comp(frame, gun, x + 8, y + 6)
    for i in range(14, 44, 3):                       # 瞄准虚线
        ax, ay = x + 9 + int(i * 0.9), y + 9 - int(i * 0.42)
        frame.putpixel((ax, ay), alpha(WPN["dart"], 255))
    crosshair(frame, emit, 84 - CAM[0], 121 - CAM[1], WPN["dart"])
    for dx, dy, c in ((-3, 0, N[6]), (-5, -1, N[5]), (3, 0, N[6]), (5, -1, N[5]), (-1, -1, N[6]), (1, -2, N[5])):
        frame.putpixel(wpos(px_ + dx, FLOOR - 1 + dy), c)  # 起跳灰尘
    frame = bloom(frame, emit)
    hud(frame, rects, psheet)
    big = frame.resize((VW * 4, VH * 4), Image.NEAREST)
    big = post(big)
    big.save(out_path)
def post(img):
    """轻后期：暗角 + 每 4 行一条极淡扫描线。色差只在 Godot 里做径向的、边缘才有。"""
    w, h = img.size
    mask = Image.new("L", (w, h), 255)
    mp = mask.load()
    for y in range(h):
        for x in range(0, w):
            dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            v = 1 - 0.3 * max(0, (dx * dx + dy * dy) - 0.45)
            if y % 4 == 3:
                v *= 0.92
            mp[x, y] = max(0, min(255, int(v * 255)))
    black = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    return Image.composite(img, black, mask)


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "/tmp/style_frame.png")
