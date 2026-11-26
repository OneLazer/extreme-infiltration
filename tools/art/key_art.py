"""16:9 宣传主视觉：只用游戏内素材（背景层、地形瓦片、角色/物件精灵、字体、色板）合成。

世界在 240×135 像素画布上逐像素合成，再整数倍放大（8× = 1920×1080，16× = 3840×2160）。
标题和主菜单一样属于 UI 层，按输出分辨率另画：粗宋像素体，一格字形像素 = 1.5 个世界像素。
构图：标题左上 → 楼沿上的主角 → 视线 → 月亮前的天枢总部大楼；中间横着无人机探照灯和巡逻守卫。
用法：python3 key_art.py <输出目录>
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pal import N, C, P, W, V, GD, DR, hx
from px import BAYER4
import gen_tiles

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VW, VH = 240, 135
A = lambda *p: os.path.join(ROOT, "assets", *p)


def img(*p):
    return Image.open(A(*p)).convert("RGBA")


def comp(dst, src, x, y):
    """带负坐标裁剪的 alpha 合成。"""
    x, y = int(round(x)), int(round(y))
    l, t = max(0, -x), max(0, -y)
    r, b = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if r > l and b > t:
        dst.alpha_composite(src.crop((l, t, r, b)), (x + l, y + t))


def frame_of(name, anim, i=0):
    meta = json.load(open(A("chars", name + ".json")))
    fw, fh = meta["frame"]
    f = meta["anims"][anim]["from"] + i
    return img("chars", name + ".png").crop((f * fw, 0, f * fw + fw, fh))


def prop(name):
    x, y, w, h = json.load(open(A("props", "props.json")))[name]
    return img("props", "props.png").crop((x, y, x + w, y + h)), img("props", "props_emit.png").crop((x, y, x + w, y + h))


def add(dst, light):
    """加色混合（float 数组 0..255）。"""
    a = np.asarray(dst, dtype=np.float32)
    a[..., :3] = np.clip(a[..., :3] + light, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA").copy()


def dither(a, x, y, level):
    """Bayer 抖动判定：level 0..16。"""
    return BAYER4[y & 3][x & 3] < level


MOON = (186, 34, 15)


def sky():
    """天空：同 gen_bg.sky 的硬色阶 + 抖动渐变、月亮和星点，按 135 高重排色阶。"""
    im = Image.new("RGBA", (VW, VH))
    px = im.load()
    stops = [(0, N[1]), (42, V[0]), (76, V[1]), (104, V[2]), (135, V[3])]
    for y in range(VH):
        for i in range(len(stops) - 1):
            y0, c0 = stops[i]; y1, c1 = stops[i + 1]
            if y0 <= y < y1:
                t = (y - y0) / (y1 - y0)
                break
        for x in range(VW):
            px[x, y] = c1 if BAYER4[y & 3][x & 3] < int(t * 16) else c0
    mx, my, r = MOON
    for y in range(my - r - 40, my + r + 41):       # 月光：一圈很淡的大光晕（两级抖动）
        for x in range(mx - r - 40, mx + r + 41):
            d = math.hypot(x - mx, y - my)
            if 0 <= x < VW and 0 <= y < VH and r + 7 < d < r + 40:
                k = 1 - (d - r - 7) / 33
                if dither(0, x, y, int(k * k * 6)):
                    px[x, y] = V[1] if px[x, y] in (N[1], V[0]) else V[2]
    for y in range(my - r - 8, my + r + 9):
        for x in range(mx - r - 8, mx + r + 9):
            d = math.hypot(x - mx, y - my)
            if r < d <= r + 7 and BAYER4[y & 3][x & 3] < int((1 - (d - r) / 7) * 7):
                px[x, y] = V[2]
            elif d <= r:
                lit = (x - mx) * 0.6 + (y - my) * 0.8 < r * 0.45
                px[x, y] = hx("#e9b9cf") if lit else V[4]
    for band_y, h in ((my + 3, 2), (my + 9, 1)):
        for x in range(mx - r, mx + r + 1):
            for y in range(band_y, band_y + h):
                if px[x, y][0] > 180:
                    px[x, y] = V[3]
    g = np.random.default_rng(11)
    for _ in range(46):
        x, y = int(g.integers(VW)), int(g.integers(62))
        if math.hypot(x - mx, y - my) > r + 10:
            c = C[4] if g.random() < 0.25 else C[3]
            px[x, y] = lerp_px(px[x, y], c, g.choice([0.35, 0.6, 0.9]))
    return im


def lerp_px(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def strip(name, ox):
    """从可平铺的城市剪影层里截一段 VW 宽（横向循环）。"""
    src = img("bg", name + ".png")
    wide = Image.new("RGBA", (src.width * 2, src.height))
    wide.paste(src, (0, 0)); wide.paste(src, (src.width, 0))
    ox %= src.width
    return wide.crop((ox, 0, ox + VW, src.height))


TOWER = (160, 7)          # 天枢总部大楼（远景层 x 300..321，尖顶在 311）放到的位置：左上角


def haze(frame, y0, y1, c, top=0, bot=8):
    """一层抖动雾：从 y0 到 y1 浓度 top → bot（0..16）。"""
    px = frame.load()
    for y in range(max(0, y0), min(VH, y1)):
        lv = int(top + (bot - top) * (y - y0) / max(1, y1 - y0))
        for x in range(VW):
            if dither(0, x, y, lv):
                px[x, y] = c


def city(frame):
    # 远景：避开原图里的总部大楼，大楼单独摆到月亮前
    comp(frame, strip("city_far", 340), 0, -26)
    tw = img("bg", "city_far.png").crop((300, 0, 322, 180))
    comp(frame, tw, TOWER[0], TOWER[1] - 3)
    haze(frame, 52, 98, V[2], 0, 6)
    comp(frame, strip("city_mid", 60), 0, -30)
    haze(frame, 74, 112, V[1], 0, 6)
    comp(frame, strip("city_near", 20), 0, -24)
    haze(frame, 108, 135, N[1], 0, 5)


# 前景天台（8px 格）：左边主角所在的高楼（顶面 y=104，左侧再高出一截楼梯间），右下一栋矮楼（顶面 y=120）
ROOF_L, ROOF_R = 104, 120
GRID = [[(x < 14 and y >= 13) or (x < 4 and y >= 11) or (x >= 20 and y >= 15) for x in range(30)] for y in range(17)]


def tiles(frame):
    meta = json.load(open(A("tiles", "street_tiles.json")))
    sheet = img("tiles", "street_tiles.png")
    look = {}
    for e in meta["tiles"]:
        look.setdefault(e["mask"], []).append(e)
    for (tx, ty), m in gen_tiles.autotile(GRID).items():
        opts = look[m]
        h = (tx * 73856093 ^ ty * 19349663) % 1000 / 1000
        pick, acc = opts[0], 0
        for e in opts[1:]:
            acc += e["prob"]
            if h < acc:
                pick = e; break
        comp(frame, sheet.crop((pick["x"] * 8, pick["y"] * 8, pick["x"] * 8 + 8, pick["y"] * 8 + 8)), tx * 8, ty * 8)


def cone(light, ox, oy, ang, length, steps, col, clip=None):
    """扇形加色光：几层硬色阶叠加（菜单无人机探照灯 / 吊灯光锥同一画法）。"""
    ys, xs = np.mgrid[0:VH, 0:VW]
    dx, dy = xs - ox, ys - oy
    d = np.hypot(dx, dy)
    da = np.abs((np.arctan2(dy, dx) - ang + np.pi) % (2 * np.pi) - np.pi)
    for half, k in steps:
        m = (da <= half) & (d <= length) & (d > 1)
        if clip is not None:
            m &= clip
        light[m] += np.array(col[:3], np.float32) * k


def open_air():
    """非实心区域掩码（光被天台挡住）。"""
    m = np.ones((VH, VW), bool)
    for ty, row in enumerate(GRID):
        for tx, s in enumerate(row):
            if s:
                m[ty * 8:ty * 8 + 8, tx * 8:tx * 8 + 8] = False
    return m


def disc(light, cx, cy, r, col, k, squash=1.0):
    """GlowSpot：三圈同心硬边圆，加色。"""
    ys, xs = np.mgrid[0:VH, 0:VW]
    d = np.hypot(xs - cx, (ys - cy) / squash)
    for n in range(3):
        light[d <= r * (1 - n * 0.3)] += np.array(col[:3], np.float32) * (k / 3)


def emissive(src, keys):
    a = np.asarray(src).copy()
    keep = np.zeros(a.shape[:2], bool)
    for k in keys:
        keep |= np.all(a == np.array(k), axis=-1)
    a[~keep] = 0
    return Image.fromarray(a, "RGBA")


HERO = (105, ROOF_L)         # 主角脚底：左楼楼沿，面朝右边的总部大楼
GUARD = (206, ROOF_R)        # 守卫：右下矮楼，面朝左边（楼缝）巡逻
DRONE = (136, 56)            # 无人机：楼缝上空，探照灯往右下扫
HERO_KEYS = [P[1], P[2], P[3], P[4]]


def put(im, emit, src, x, y, keys=()):
    comp(im, src, x, y)
    if keys:
        comp(emit, emissive(src, keys), x, y)


def deco(frame, emit):
    """天台陈设：楼梯间天线（红灯）、空调外机、楼体正面的「夜未眠」竖招牌（主菜单同款，程序画的部分照搬）。"""
    d = ImageDraw.Draw(frame)
    de = ImageDraw.Draw(emit)
    # 楼梯间上的天线
    d.rectangle((8, 62, 8, 87), fill=N[6]); d.rectangle((9, 62, 9, 87), fill=N[4]); d.rectangle((5, 72, 11, 72), fill=N[5]); d.rectangle((6, 67, 10, 67), fill=N[5])
    for dd in (d, de):
        dd.rectangle((7, 60, 9, 61), fill=GD["r"])
    # 空调外机（风扇停在一个角度）
    ax, ay = 46, ROOF_L - 12
    d.rectangle((ax, ay, ax + 17, ay + 11), fill=N[2]); d.line((ax, ay, ax + 17, ay), fill=N[6])
    d.line((ax, ay + 11, ax + 17, ay + 11), fill=N[1])
    d.rectangle((ax + 2, ay + 2, ax + 10, ay + 10), fill=N[1])
    for k in range(3):
        a = 0.4 + k * math.tau / 3
        for r in range(1, 4):
            d.point((round(ax + 6 + math.cos(a) * r), round(ay + 6 + math.sin(a) * r)), fill=N[4])
    for y in range(4):
        d.line((ax + 12, ay + 3 + y * 2, ax + 15, ay + 3 + y * 2), fill=N[3])
    # 楼梯间的门（门缝暖光），开在高出天台的那一截楼体上
    d.rectangle((14, 91, 25, ROOF_L - 1), fill=N[4]); d.rectangle((15, 92, 24, ROOF_L - 1), fill=N[1])
    d.line((15, 92, 24, 92), fill=N[6]); d.line((20, 93, 20, ROOF_L - 1), fill=(153, 107, 51, 255))
    d.point((23, 98), fill=N[6])
    for dd, c in ((d, W[3]), (de, W[2])):
        dd.line((17, 89, 22, 89), fill=c)
    # 竖招牌挂在楼体正面，下半截出画
    sg, sge = prop("neon_ye")
    put(frame, emit, sg, 76, ROOF_L + 9)
    comp(emit, sge, 76, ROOF_L + 9)
    # 右楼楼顶的通风口
    d.rectangle((226, ROOF_R - 6, 229, ROOF_R - 1), fill=N[3]); d.line((226, ROOF_R - 6, 229, ROOF_R - 6), fill=N[6])


def scarf_pts(nx, ny):
    """围巾：风从右往左吹，整条向左后方飘，越往尾端越垂、摆幅越大（MenuHero 的形状冻结在一帧）。"""
    pts = [(nx, ny)]
    x, y = nx, ny
    for i in range(1, 7):
        k = i / 6
        ang = math.pi - 0.15 - 0.5 * k * k + math.sin(1.4 - i * 1.1) * 0.5 * k
        x += math.cos(ang) * 1.75; y += math.sin(ang) * 1.75
        pts.append((x, y))
    return pts


def scarf(frame, emit, pts):
    col, shade = P[3], P[1]
    d, de = ImageDraw.Draw(frame), ImageDraw.Draw(emit)
    for pass_i in range(2):
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            n = int(math.ceil(max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1))) * 2
            for s in range(n + 1):
                x = round(a[0] + (b[0] - a[0]) * s / n); y = round(a[1] + (b[1] - a[1]) * s / n)
                wide = i < 3
                if pass_i == 0 and wide:
                    d.rectangle((x, y + 2, x + 1, y + 2), fill=shade)
                elif pass_i == 1:
                    r = (x, y, x + 1, y + 1) if wide else (x, y, x, y)
                    d.rectangle(r, fill=col); de.rectangle(r, fill=col)


def rim(sp, col=(255, 190, 225, 255), k=0.35):
    """月光轮廓光：精灵朝月亮（右上）一侧的边缘像素提亮。"""
    a = np.asarray(sp).copy()
    on = a[..., 3] > 0
    edge = on & ~np.roll(on, -1, 1)
    edge[:, -1] |= on[:, -1]
    dark = (a[..., :3].sum(-1) < 90)                   # 黑色描边不提亮，只亮受光面
    for y, x in zip(*np.where(edge)):
        if tuple(a[y, x]) in HERO_KEYS or dark[y, x]:
            continue
        a[y, x, :3] = a[y, x, :3] + (np.array(col[:3]) - a[y, x, :3]) * k
    return Image.fromarray(a, "RGBA")


def actors(frame, emit):
    hx_, hy = HERO
    scarf(frame, emit, scarf_pts(hx_ - 3, hy - 8))
    put(frame, emit, rim(frame_of("player", "idle", 1)), hx_ - 8, hy - 16, HERO_KEYS)
    g = frame_of("guard", "idle").transpose(Image.FLIP_LEFT_RIGHT)
    put(frame, emit, g, GUARD[0] - 8, GUARD[1] - 16, [GD["v"], GD["V"]])
    dr = frame_of("drone", "hover")
    put(frame, emit, dr, DRONE[0] - 8, DRONE[1] - 6, [DR["y"], DR["Y"]])
    for dd in (ImageDraw.Draw(frame), ImageDraw.Draw(emit)):     # 探照灯口
        dd.rectangle((DRONE[0] - 1, DRONE[1] - 1, DRONE[0], DRONE[1] - 1), fill=DR["Y"])


def lights(frame):
    """加色光层：无人机探照灯、守卫视野锥、霓虹和门灯的光斑。"""
    L = np.zeros((VH, VW, 3), np.float32)
    air = open_air()
    vis = np.array([1.0, 0.82, 0.48]) * 255
    beam = math.atan2(135 - DRONE[1], 168 - DRONE[0])
    cone(L, DRONE[0], DRONE[1], beam, 110, [(0.22, 0.05), (0.15, 0.07), (0.09, 0.1)], vis)
    # 守卫视野：琥珀色，亮边 + 稀疏扫描点，被天台挡住
    ex, ey = GUARD[0] - 3, GUARD[1] - 9
    ys, xs = np.mgrid[0:VH, 0:VW]
    d = np.hypot(xs - ex, ys - ey)
    da = np.abs((np.arctan2(ys - ey, xs - ex) - math.pi + math.pi) % (2 * math.pi) - math.pi)
    half, rng_ = math.radians(28), 46
    m = (d > 3) & (d <= rng_) & (da <= half) & air
    edge = m & ((d > rng_ - 1.5) | (da > half - 0.9 / np.maximum(d, 1)))
    bay = np.array(BAYER4)[ys & 3, xs & 3]
    scan = m & ~edge & (((ys + (d / rng_ * 3).astype(int)) % 3) == 0) & (bay < 8)
    t = d / rng_
    amber = np.array(GD["V"][:3], np.float32)
    k = np.where(edge, 0.55 * (1 - t * 0.5), np.where(scan, 0.3 * (1 - t), 0.05 * (1 - t)))
    L += (m[..., None] * k[..., None]) * amber
    disc(L, 82, ROOF_L + 22, 24, P[3], 0.2, 0.8)        # 招牌映在楼体和主角身上
    disc(L, HERO[0] - 2, HERO[1] - 7, 9, P[3], 0.1)     # 围巾的一点品红光
    disc(L, HERO[0] + 2, HERO[1] - 9, 20, C[1], 0.16, 0.85)   # 主角背后一圈冷色逆光，把人从窗格里剥出来
    disc(L, 19, 92, 9, W[3], 0.12, 0.7)                  # 门灯
    return add(frame, L), air


def rain(frame, emit, beam_mask, n=76, seed=91):
    """斜雨：细线，探照灯里被照亮成暖白，其余是冷蓝。"""
    g = np.random.default_rng(seed)
    px = frame.load()
    dirv = np.array([-55.0, 300.0]); dirv /= np.linalg.norm(dirv)
    for _ in range(n):
        x0, y0 = g.random() * (VW + 20), g.random() * VH
        ln = int(g.integers(3, 7)); a = g.uniform(0.25, 0.45)
        for s in range(ln):
            x, y = int(round(x0 - dirv[0] * s)), int(round(y0 - dirv[1] * s))
            if 0 <= x < VW and 0 <= y < VH:
                lit = beam_mask[y, x]
                c = (255, 236, 190) if lit else (115, 158, 255)
                aa = min(1, a * (2.2 if lit else 1))
                px[x, y] = lerp_px(px[x, y], c, aa)


def splashes(frame, seed=5):
    """雨点打在楼顶溅起的小水花（主菜单 Splashes 的三帧，随机定格在不同帧）。"""
    g = np.random.default_rng(seed)
    px = frame.load()
    for (x0, x1, top), n in (((0, 31, 88), 3), ((32, 111, ROOF_L), 9), ((160, 239, ROOF_R), 8)):
        for _ in range(n):
            x, f = int(g.integers(x0 + 2, x1 - 2)), int(g.integers(3))
            a = 0.7 - f * 0.2
            pts = [(0, -1)] if f == 0 else ([(-1, -2), (1, -2)] if f == 1 else [(-2, -1), (2, -1)])
            for dx, dy in pts:
                px[x + dx, top + dy] = lerp_px(px[x + dx, top + dy], C[3], a)


def bloom(frame, emit, s):
    """HDR 辉光：只模糊发光层再加色叠加。在世界分辨率模糊、放大时双线性，光晕柔、精灵仍然锐利。"""
    e = emit.convert("RGB")
    out = np.asarray(frame.convert("RGB").resize((VW * s, VH * s), Image.NEAREST), np.float32)
    for r, k in ((1.2, 0.5), (4, 0.42), (10, 0.25)):
        b = e.filter(ImageFilter.GaussianBlur(r)).resize((VW * s, VH * s), Image.BILINEAR)
        out += np.asarray(b, np.float32) * k
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def world():
    frame = sky()
    city(frame)
    emit = Image.new("RGBA", (VW, VH), (0, 0, 0, 0))
    mx, my, r = MOON                                       # 月亮也进一点辉光
    ImageDraw.Draw(emit).ellipse((mx - r, my - r, mx + r, my + r), fill=(52, 30, 46, 255))
    tw = img("bg", "city_far.png").crop((300, 0, 322, 180))   # 大楼挡住的那部分月亮不发光
    emit.paste((0, 0, 0, 0), (TOWER[0], TOWER[1] - 3), tw.split()[3])
    tiles(frame)
    deco(frame, emit)
    actors(frame, emit)
    frame, air = lights(frame)
    ys, xs = np.mgrid[0:VH, 0:VW]
    beam = math.atan2(135 - DRONE[1], 168 - DRONE[0])
    da = np.abs((np.arctan2(ys - DRONE[1], xs - DRONE[0]) - beam + np.pi) % (2 * np.pi) - np.pi)
    rain(frame, emit, (da <= 0.22) & (np.hypot(xs - DRONE[0], ys - DRONE[1]) < 110))
    splashes(frame)
    return frame, emit


FONTS = os.path.join(ROOT, "fonts")
TITLE, SUB = "极限潜入行动", "EXTREME INFILTRATION"
TITLE_AT = (14, 13)          # 标题左上角（世界像素）


def glyph_mask(text, font, size, spacing=0):
    """像素字体按原生字号无抗锯齿栅格化，返回 0/1 掩码（1 格 = 1 字形像素）。"""
    f = ImageFont.truetype(os.path.join(FONTS, font), size)
    w = int(f.getlength(text)) + spacing * len(text) + 4
    m = Image.new("L", (w, size * 2), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    x = 0
    for ch in text:
        d.text((x, 0), ch, font=f, fill=255)
        x += f.getlength(ch) + spacing
    return m.crop(m.getbbox())


def stamp(dst, mask, x, y, cell, col, a=1.0):
    """把字形掩码按每格 cell 个输出像素放大后，用纯色盖到 dst 上。"""
    big = mask.resize((mask.width * cell, mask.height * cell), Image.NEAREST)
    if a < 1:
        big = big.point(lambda v: int(v * a))
    dst.paste(Image.new("RGBA", big.size, col), (int(x), int(y)), big)


def title(big, s):
    """标题字组：粗宋像素体金色字 + 品红投影（主菜单 UiKit.title 同款），下面是拉开字距、和标题等宽的英文副标题
    与「品红短条 + 青色细线」分隔线。全部按输出分辨率的整数格画。"""
    T = int(s * 1.5)                                   # 一个字形像素 = 1.5 世界像素
    x0, y0 = TITLE_AT[0] * s, TITLE_AT[1] * s
    tm = glyph_mask(TITLE, "Chusung-220206.ttf", 12)
    tw = tm.width * T
    # 标题背后一团很淡的暖光，让金字从夜空里浮出来
    glow = Image.new("L", big.size, 0)
    glow.paste(tm.resize((tw, tm.height * T), Image.NEAREST), (x0, y0))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 3)).point(lambda v: int(v * 0.45))
    big.paste(Image.new("RGBA", big.size, W[1]), (0, 0), glow)
    stamp(big, tm, x0 + T // 2, y0 + T // 2, T, P[2])            # 投影
    stamp(big, tm, x0, y0, T, W[3])                              # 字面
    # 副标题：m6x11（一格 = 半个世界像素），字距拉开到与标题等宽
    cell = s // 2
    plain = glyph_mask(SUB, "m6x11.ttf", 16)
    sp = max(1, round((tw / cell - plain.width) / (len(SUB) - 1)))
    sm = glyph_mask(SUB, "m6x11.ttf", 16, sp)
    sy = y0 + tm.height * T + 3 * s
    stamp(big, sm, x0 + (tw - sm.width * cell) // 2, sy, cell, C[2], 0.9)
    # 分隔线：左端品红短条（2 格高）+ 青色细线，和主菜单一致
    ly = sy + sm.height * cell + 3 * s
    d = ImageDraw.Draw(big)
    d.rectangle((x0, ly, x0 + tw - 1, ly + s - 1), fill=lerp_px(N[1], C[1], 0.8))
    d.rectangle((x0, ly - s, x0 + 14 * s - 1, ly + s - 1), fill=P[3])


def vignette(big, k=0.42):
    """暗角：四角压暗，底边多压一点，把视线收向中间。"""
    w, h = big.size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = (xs - w / 2) / (w / 2), (ys - h * 0.45) / (h / 2)
    v = 1 - k * np.clip(dx * dx * 0.7 + dy * dy - 0.35, 0, 1)
    a = np.asarray(big, np.float32)
    a[..., :3] *= v[..., None]
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def render(out_dir, s=8):
    frame, emit = world()
    big = bloom(frame, emit, s)
    big = vignette(big)
    title(big, s)
    big.save(os.path.join(out_dir, "key_art_%dx%d.png" % (VW * s, VH * s)))
    return big


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "art")
    for scale in (8, 16):
        render(out, scale)
