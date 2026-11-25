class_name Palette
extends RefCounted
## 配色。与 tools/art/pal.py 对应。
## 规则：环境色都在 0..1 之内，不进辉光；只有可交互物用 >1 的 HDR 颜色发光
## （hdr_2d + WorldEnvironment 辉光，阈值 1.0）。

# ---------------- 环境（街区主题） ----------------
const N0 := Color("#07060f")
const N1 := Color("#0d0b1e")
const N2 := Color("#141130")
const N3 := Color("#1c1842")
const N4 := Color("#262158")
const N5 := Color("#332c70")
const N6 := Color("#463d8c")
const C1 := Color("#2f6fae")
const C2 := Color("#4fb4e8")
const C3 := Color("#8fe3ff")
const C4 := Color("#d8f7ff")
const P2 := Color("#b8327f")
const P3 := Color("#ff4f9a")
const W3 := Color("#ffd27a")
const DUST := Color("#6a62a8")           ## 地面扬尘（灰紫）

# ---------------- 玩法色（HDR，会发光） ----------------
const PLAYER := Color(2.2, 0.45, 1.6)
const SCARF := Color(1.9, 0.55, 1.15)    ## 围巾：二段跳可用
const SCARF_USED := Color(0.42, 0.33, 0.75)  ## 围巾：二段跳已用（不发光）
const GUARD := Color(2.0, 0.7, 0.15)
const ALERT := Color(2.6, 0.2, 0.2)
const FLYER := Color(1.9, 1.7, 0.3)
const DART := Color(0.4, 2.2, 2.2)
const BOOMERANG := Color(0.5, 2.2, 0.8)
const HEAVY := Color(0.9, 0.6, 2.6)
const AIRGUN := Color(2.4, 1.2, 0.3)
const EXIT_OPEN := Color(0.4, 2.4, 0.6)
const EXIT_LOCKED := Color(0.5, 0.3, 0.4)
const VISION := Color(1.0, 0.82, 0.48)         ## 视野锥（加色，强度在脚本里乘）
const VISION_SEARCH := Color(1.0, 0.45, 0.16)  ## 视野锥：搜索 / 警戒
const VISION_ALERT := Color(1.0, 0.16, 0.24)
const SEARCH := Color(2.4, 0.9, 0.15)          ## 守卫搜索：面罩、「?」
const RAPIER := Color(2.1, 2.2, 2.7)           ## 刺剑：冷银白
const TIMER := Color(0.45, 0.9, 2.8)           ## 计时门 / 倒计时：钴蓝（和飞镖的青色区分开）
const ELECTRIC := Color(2.8, 0.35, 0.75)       ## 高压电（#ff2a5a 一带，HDR）
const ELECTRIC_CORE := Color(3.2, 2.2, 2.6)    ## 电弧白芯
const ELECTRIC_FILL := Color("#2a0718")        ## 电块内部底色（环境亮度，不发光）
const SPARK := Color(2.6, 2.0, 1.2)            ## 金属火花
const OIL := Color("#0a0812")                  ## 义体机油
const OIL_SHEEN := Color("#3a2f6a")
