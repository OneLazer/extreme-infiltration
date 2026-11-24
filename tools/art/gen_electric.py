"""生成高压电块的编辑器预览瓦片（8×8）：暗红底 + 两条斜向亮纹，刷关卡时一眼能认出来。

游戏运行时这层瓦片会被隐藏，改由 scripts/hazards/electric_renderer.gd 整体渲染（内部噪声 + 边缘电弧），
所以这张图只用于编辑器。输出 assets/tiles/electric_tile.png。
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pal import ELECTRIC, hx
from px import Cv, lerp

BASE = hx("#2a0718")
MID = hx("#5a0e2c")


def build(out):
    c = Cv(8, 8)
    for y in range(8):
        for x in range(8):
            d = (x + y) % 8
            col = ELECTRIC if d in (0, 4) else (lerp(ELECTRIC, BASE, 0.55) if d in (1, 5) else BASE)
            c.put(x, y, col)
    for i in range(8):   # 外圈一道暗边，相邻格拼起来能看出格子
        c.put(i, 7, MID); c.put(7, i, MID)
    c.save(out)


if __name__ == "__main__":
    build(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tiles", "electric_tile.png"))
