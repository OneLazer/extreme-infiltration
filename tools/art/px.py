"""像素绘图小工具：在 PIL RGBA 图上逐像素作画。"""
from PIL import Image
import random

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


class Cv:
    def __init__(self, w, h, fill=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), fill)
        self.px = self.im.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if len(c) == 4 and c[3] < 255:
                self.px[x, y] = blend(self.px[x, y], c)
            else:
                self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < self.w and 0 <= y < self.h else (0, 0, 0, 0)

    def rect(self, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.put(i, j, c)

    def hline(self, x0, x1, y, c):
        for i in range(x0, x1 + 1):
            self.put(i, y, c)

    def vline(self, x, y0, y1, c):
        for j in range(y0, y1 + 1):
            self.put(x, j, c)

    def dither_rect(self, x, y, w, h, c, level):
        """level 0..16：Bayer 有序抖动填充，像素风的半透明。"""
        for j in range(y, y + h):
            for i in range(x, x + w):
                if BAYER4[j & 3][i & 3] < level:
                    self.put(i, j, c)

    def blit(self, src, x, y):
        self.im.alpha_composite(src.im if isinstance(src, Cv) else src, (x, y))
        self.px = self.im.load()

    def save(self, path):
        self.im.save(path)


def blend(dst, src):
    a = src[3] / 255.0
    da = dst[3] / 255.0
    oa = a + da * (1 - a)
    if oa <= 0:
        return (0, 0, 0, 0)
    rgb = [int((src[i] * a + dst[i] * da * (1 - a)) / oa + 0.5) for i in range(3)]
    return (rgb[0], rgb[1], rgb[2], int(oa * 255 + 0.5))


def alpha(c, a):
    return (c[0], c[1], c[2], int(a))


def lerp(c0, c1, t):
    return tuple(int(c0[i] + (c1[i] - c0[i]) * t + 0.5) for i in range(4))


def sprite(rows, keys, flip=False):
    """字符画 → Cv。'.' 和空格为透明。"""
    h = len(rows)
    w = max(len(r) for r in rows)
    cv = Cv(w, h)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in keys:
                cv.put(w - 1 - x if flip else x, y, keys[ch])
    return cv


def rng(seed):
    return random.Random(seed)
