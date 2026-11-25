"""用代码合成全部音效 → assets/sfx/*.wav（44.1kHz / 16bit / 单声道）。

用法：python3 tools/audio/gen_sfx.py        （只依赖 numpy）
风格：暗色合成器 + 少量芯片音色。UI 音短、干净、偏高频；动作音有低频冲击；
      收尾统一过一层短混响，让所有声音像在同一个空间里。
每个音效是一个函数，返回浮点波形；末尾 SOUNDS 表登记名字和响度（dBFS 峰值）。
"""
import math, os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "sfx")
RNG = np.random.default_rng(1985)


# ---------------------------------------------------------------- 基础件
def T(sec):
    return np.arange(int(SR * sec)) / SR


def osc(freq, n, shape="sine", duty=0.5):
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, float)
    ph = np.cumsum(f) / SR
    x = ph % 1.0
    if shape == "sine":
        return np.sin(2 * np.pi * ph)
    if shape == "square":
        return np.where(x < duty, 1.0, -1.0)
    if shape == "saw":
        return 2.0 * x - 1.0
    if shape == "tri":
        return 4.0 * np.abs(x - 0.5) - 1.0
    raise ValueError(shape)


def sweep(f0, f1, n, curve="exp"):
    """n 个样本内从 f0 滑到 f1；exp 按对数（听感均匀）"""
    u = np.linspace(0.0, 1.0, n)
    if curve == "exp":
        return f0 * (f1 / f0) ** u
    return f0 + (f1 - f0) * u


def noise(n):
    return RNG.uniform(-1.0, 1.0, n)


def env(n, attack=0.002, decay=0.1, curve=1.0):
    """快起、指数衰减的包络；decay 是衰减到 1/e 的时间"""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    return a * np.exp(-t / max(decay, 1e-5)) ** curve


def fade(x, out=0.01, inn=0.001):
    """首尾淡入淡出，避免爆音"""
    x = x.copy()
    ni, no = max(int(SR * inn), 1), max(int(SR * out), 1)
    x[:ni] *= np.linspace(0, 1, ni)
    x[-no:] *= np.linspace(1, 0, no)
    return x


def lowpass(x, cutoff):
    """一阶低通，cutoff 可以是逐样本数组（扫频）"""
    c = np.broadcast_to(np.asarray(cutoff, float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    z = 0.0
    for i in range(len(x)):
        z += a[i] * (x[i] - z)
        y[i] = z
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, center, q=2.0):
    """二阶带通（RBJ），center 可以逐样本变化"""
    c = np.broadcast_to(np.asarray(center, float), x.shape)
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        w = 2 * np.pi * min(c[i], SR * 0.45) / SR
        al = math.sin(w) / (2 * q)
        a0 = 1 + al
        b0, b2 = al / a0, -al / a0
        a1, a2 = -2 * math.cos(w) / a0, (1 - al) / a0
        yi = b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x[i]
        y2, y1 = y1, yi
        y[i] = yi
    return y


def crush(x, bits=6, hold=1):
    """位深压缩 + 采样保持：芯片味"""
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    if hold > 1:
        y = np.repeat(y[::hold], hold)[: len(x)]
    return y


def drive(x, k=2.0):
    return np.tanh(x * k) / np.tanh(k)


def _fftconv(a, b):
    n = len(a) + len(b) - 1
    m = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, m) * np.fft.rfft(b, m), m)[:n]


_IR = {}


def reverb(x, wet=0.18, size=0.6, tone=5000.0):
    """短混响：指数衰减的噪声做脉冲响应（卷积），size 是衰减到 -60dB 的秒数"""
    key = (size, tone)
    if key not in _IR:
        r = np.random.default_rng(7)
        n = int(SR * size)
        ir = r.uniform(-1, 1, n) * np.exp(-6.9 * np.arange(n) / n)
        ir[: int(SR * 0.008)] = 0.0                    # 8ms 预延迟
        ir = lowpass(ir, tone)
        _IR[key] = ir / np.sqrt(np.sum(ir ** 2))
    y = _fftconv(x, _IR[key])
    out = np.zeros(len(y))
    out[: len(x)] += x
    return out + y * wet


def mix(*parts):
    """把若干 (起点秒, 波形) 叠到一条轨上"""
    n = max(int(SR * at) + len(w) for at, w in parts)
    out = np.zeros(n)
    for at, w in parts:
        i = int(SR * at)
        out[i: i + len(w)] += w
    return out


def tone(freq, sec, shape="sine", decay=0.1, attack=0.002, duty=0.5, gain=1.0):
    n = int(SR * sec)
    return osc(freq, n, shape, duty) * env(n, attack, decay) * gain


def click(sec=0.004, center=4000.0, gain=1.0):
    n = int(SR * sec)
    return bandpass(noise(n), center, 1.2) * env(n, 0.0002, sec / 3) * gain * 3.0


def note(name):
    """'A4' → 频率"""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    k = names[name[0]]
    i = 1
    if name[1] in "#b":
        k += 1 if name[1] == "#" else -1
        i = 2
    return 440.0 * 2 ** ((k + 12 * (int(name[i:]) - 4)) / 12)


# ================================================================ UI
def ui_move():
    # 轻快的电子拨片：方波短音 + 一点高频咔哒
    a = tone(1568, 0.05, "square", 0.012, duty=0.25, gain=0.5)
    b = tone(3136, 0.03, "sine", 0.006, gain=0.25)
    return reverb(mix((0, a), (0, b), (0, click(0.003, 6000, 0.4))), 0.10, 0.35)


def ui_confirm():
    # 上行两音（E6 → B6），三角 + 方波叠出一点亮度，尾巴带空间感
    e = tone(note("E6"), 0.09, "tri", 0.05, gain=0.7) + tone(note("E6"), 0.09, "square", 0.02, duty=0.125, gain=0.18)
    b = tone(note("B6"), 0.22, "tri", 0.09, gain=0.7) + tone(note("B6"), 0.22, "square", 0.03, duty=0.125, gain=0.18)
    return reverb(mix((0, click(0.004, 5000, 0.5)), (0, e), (0.045, b)), 0.22, 0.6)


def ui_back():
    a = tone(note("B5"), 0.06, "tri", 0.03, gain=0.6)
    b = tone(note("E5"), 0.12, "tri", 0.05, gain=0.6)
    return reverb(mix((0, a), (0.04, b), (0, click(0.003, 3000, 0.3))), 0.15, 0.4)


def ui_deny():
    # 两下低沉嗡鸣：失谐方波 + 压位
    n = int(SR * 0.08)
    buzz = (osc(98, n, "square") + osc(104, n, "square")) * 0.35 * env(n, 0.002, 0.05)
    buzz = crush(lowpass(buzz, 1800), 5, 2)
    return reverb(mix((0, buzz), (0.1, buzz * 0.8)), 0.12, 0.3)


def ui_toggle():
    n = int(SR * 0.05)
    pip = osc(sweep(1400, 900, n), n, "sine") * env(n, 0.001, 0.015) * 0.5
    return mix((0, click(0.006, 2500, 0.9)), (0.004, pip), (0.03, click(0.003, 5000, 0.3)))


def ui_tick():
    return mix((0, tone(2350, 0.025, "square", 0.006, duty=0.25, gain=0.35)), (0, click(0.002, 7000, 0.25)))


def ui_tab():
    n = int(SR * 0.09)
    wh = bandpass(noise(n), sweep(1500, 5000, n), 1.5) * env(n, 0.02, 0.03) * 0.7
    return reverb(mix((0, wh), (0.05, tone(2093, 0.04, "tri", 0.015, gain=0.4))), 0.1, 0.3)


def ui_type():
    # 打字机式的细碎咔哒（标题逐字出现）
    return mix((0, click(0.003, 5500, 0.7)), (0, tone(3800, 0.012, "sine", 0.003, gain=0.15)))


def ui_channel():
    # 监控换台：一小段带通静电 + 结尾一个同步音
    n = int(SR * 0.15)
    st = bandpass(noise(n), 3200, 0.8) * (0.6 + 0.4 * (RNG.uniform(0, 1, n // 300 + 1).repeat(300)[:n]))
    st *= np.minimum(1.0, np.linspace(1.4, 0.0, n)) * 0.55
    return mix((0, crush(st, 6, 2)), (0.12, tone(1975, 0.05, "sine", 0.015, gain=0.3)))


def pause():
    # 磁带停转：和弦音高往下掉、低通关上，最后一下低沉的「咚」
    n = int(SR * 0.32)
    drop = sweep(1.0, 0.28, n) ** 1.4
    ch = sum(osc(note(k) * drop, n, "saw") for k in ("A3", "E4", "C5")) * 0.22
    ch = lowpass(ch, sweep(5000, 300, n)) * env(n, 0.003, 0.25)
    thump = tone(sweep(90, 45, int(SR * 0.12)), 0.12, "sine", 0.05, gain=0.6)
    return reverb(mix((0, ch), (0.2, thump)), 0.15, 0.5, 3000)


def resume():
    n = int(SR * 0.2)
    rise = sweep(0.45, 1.0, n) ** 1.2
    ch = sum(osc(note(k) * rise, n, "saw") for k in ("A3", "E4", "C5")) * 0.2
    ch = lowpass(ch, sweep(500, 6000, n)) * np.minimum(1.0, np.linspace(0.3, 1.6, n)) * env(n, 0.03, 0.15)
    return reverb(mix((0, ch), (0.17, click(0.004, 4000, 0.4))), 0.15, 0.4)


def start():
    # 开始游戏：噪声上扬 → 冲击（低频 + 碎响）→ 小调九和弦长尾
    nr = int(SR * 0.28)
    riser = bandpass(noise(nr), sweep(600, 7000, nr), 1.2) * np.linspace(0.0, 1.0, nr) ** 2 * 0.8
    ni = int(SR * 0.5)
    sub = osc(sweep(110, 38, ni), ni, "sine") * env(ni, 0.001, 0.18) * 0.9
    crash = lowpass(noise(ni), 6000) * env(ni, 0.001, 0.09) * 0.5
    nc = int(SR * 1.4)
    chord = np.zeros(nc)
    for k in ("A2", "E3", "G3", "B3", "C4", "E4"):
        f = note(k)
        chord += (osc(f * 1.003, nc, "saw") + osc(f * 0.997, nc, "saw")) * 0.08
    chord = lowpass(chord, sweep(5000, 900, nc)) * env(nc, 0.004, 0.55)
    return reverb(mix((0, riser), (0.28, sub), (0.28, crash), (0.28, chord)), 0.3, 1.2, 4000)


def boot():
    # 显像管开机：继电器「咔」、电源嗡鸣爬升、一阵静电，再一个高音稳定下来
    nh = int(SR * 0.7)
    hum = (osc(sweep(40, 100, nh), nh, "saw") * 0.25)
    hum = lowpass(hum, 900) * np.minimum(1.0, np.linspace(0, 3, nh)) * env(nh, 0.01, 0.35)
    ns = int(SR * 0.25)
    st = highpass(noise(ns), 2000) * env(ns, 0.001, 0.08) * 0.35
    whine = tone(7800, 0.5, "sine", 0.25, attack=0.05, gain=0.04)
    return reverb(mix((0, click(0.006, 1500, 1.2)), (0.02, hum), (0.12, st), (0.18, whine)), 0.15, 0.5)


def power_off():
    # 关机：一声下滑的「啾——」+ 劈啪，尾音只剩一点残余
    n = int(SR * 0.42)
    z = osc(sweep(2400, 60, n), n, "sine") * env(n, 0.001, 0.16) * 0.6
    cr = highpass(noise(n), 3000) * (RNG.uniform(0, 1, n) > 0.985) * 0.8 * env(n, 0.001, 0.12)
    return reverb(mix((0, click(0.005, 2000, 1.0)), (0, z), (0, cr)), 0.2, 0.6, 3500)


def wipe_in():
    n = int(SR * 0.4)
    w = bandpass(noise(n), sweep(400, 2600, n), 0.9) * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.5
    return reverb(w, 0.1, 0.4)


# ================================================================ 移动
def _puff(sec, lo, hi, gain):
    n = int(SR * sec)
    return bandpass(noise(n), sweep(lo, hi, n), 1.0) * env(n, 0.002, sec / 3) * gain


def jump():
    n = int(SR * 0.08)
    ch = osc(sweep(280, 620, n), n, "square", 0.5) * env(n, 0.001, 0.03) * 0.35
    return reverb(mix((0, lowpass(ch, 3500)), (0, _puff(0.06, 800, 2500, 0.5))), 0.06, 0.3)


def jump_air():
    n = int(SR * 0.12)
    ch = osc(sweep(560, 1250, n), n, "tri") * env(n, 0.002, 0.05) * 0.5
    sh = tone(2500, 0.1, "sine", 0.04, gain=0.12)
    return reverb(mix((0, ch), (0.02, sh), (0, _puff(0.1, 1500, 5000, 0.4))), 0.12, 0.4)


def jump_wall():
    scuff = bandpass(noise(int(SR * 0.05)), 1800, 0.8) * env(int(SR * 0.05), 0.001, 0.015) * 0.8
    n = int(SR * 0.08)
    ch = osc(sweep(330, 700, n), n, "square", 0.25) * env(n, 0.001, 0.03) * 0.3
    return reverb(mix((0, scuff), (0.01, lowpass(ch, 3000))), 0.06, 0.3)


def jump_super():
    n = int(SR * 0.18)
    ch = drive(osc(sweep(380, 950, n), n, "saw") * env(n, 0.002, 0.07), 2.5) * 0.35
    return reverb(mix((0, lowpass(ch, 4000)), (0, _puff(0.18, 600, 6000, 0.6))), 0.12, 0.4)


def land():
    n = int(SR * 0.1)
    th = osc(sweep(140, 48, n), n, "sine") * env(n, 0.001, 0.035) * 0.9
    du = lowpass(noise(n), 900) * env(n, 0.001, 0.025) * 0.6
    return mix((0, th), (0, du))


# ================================================================ 武器
def dart():
    n = int(SR * 0.07)
    th = osc(sweep(2600, 500, n), n, "sine") * env(n, 0.001, 0.025) * 0.6
    hi = highpass(noise(n), 4000) * env(n, 0.001, 0.012) * 0.5
    return reverb(mix((0, th), (0, hi)), 0.1, 0.35)


def blink():
    n = int(SR * 0.09)
    z = osc(sweep(500, 3000, n), n, "tri") * env(n, 0.003, 0.04) * 0.45
    sh = tone(4186, 0.14, "sine", 0.05, gain=0.12) + tone(5274, 0.14, "sine", 0.04, gain=0.08)
    return reverb(mix((0, z), (0.05, sh), (0, _puff(0.08, 3000, 9000, 0.25))), 0.2, 0.5)


def airgun():
    n = int(SR * 0.22)
    body = lowpass(noise(n), sweep(3000, 400, n)) * env(n, 0.0005, 0.04) * 1.0
    kick = osc(sweep(120, 38, n), n, "sine") * env(n, 0.001, 0.06) * 0.9
    return reverb(drive(mix((0, click(0.003, 3000, 1.0)), (0, body), (0, kick)), 1.6), 0.12, 0.5)


def throw():
    n = int(SR * 0.22)
    wh = bandpass(noise(n), 900 + 1300 * np.sin(np.linspace(0, np.pi, n)), 1.8) * np.sin(np.linspace(0, np.pi, n)) * 0.7
    whir = osc(240, n, "square", 0.3) * (0.5 + 0.5 * osc(32, n, "sine")) * env(n, 0.01, 0.08) * 0.12
    return reverb(mix((0, wh), (0, lowpass(whir, 2000))), 0.08, 0.3)


def _metal(freqs, sec, decay, gain):
    n = int(SR * sec)
    return sum(osc(f, n, "sine") * env(n, 0.0005, decay * (1.0 - 0.15 * i)) for i, f in enumerate(freqs)) * gain


def catch():
    return reverb(mix((0, click(0.003, 5000, 0.8)), (0, _metal([2093, 3170, 4410], 0.16, 0.05, 0.22))), 0.12, 0.35)


def rapier():
    n = int(SR * 0.16)
    swish = bandpass(noise(n), sweep(2500, 9000, n), 1.4) * env(n, 0.004, 0.05) * 0.8
    ring = _metal([3520, 5230, 7040, 8890], 0.35, 0.09, 0.14)
    return reverb(mix((0, swish), (0.03, ring)), 0.15, 0.5)


def deflect():
    ring = _metal([880, 1420, 2230, 3410, 4630], 0.4, 0.09, 0.2)
    return reverb(drive(mix((0, click(0.005, 2500, 1.2)), (0, ring)), 1.3), 0.2, 0.5)


# ================================================================ 击杀 / 死亡
def kill():
    # 金属外壳碎裂：重击 + 压位方波下坠 + 一串细碎零件
    n = int(SR * 0.3)
    hit = lowpass(noise(n), sweep(7000, 600, n)) * env(n, 0.0005, 0.05) * 0.9
    low = crush(osc(sweep(150, 40, n), n, "square") * env(n, 0.001, 0.07) * 0.4, 5, 3)
    bits = [(0.03 + 0.022 * i, _metal([2400 + 700 * i, 3900 + 500 * i], 0.05, 0.012, 0.18)) for i in range(5)]
    return reverb(drive(mix((0, hit), (0, lowpass(low, 2500)), *bits), 1.5), 0.15, 0.55)


def zap():
    # 高压电：锯齿嗡鸣（频率乱跳）+ 劈啪
    n = int(SR * 0.45)
    f = 70 + 40 * RNG.uniform(0, 1, n // 400 + 1).repeat(400)[:n]
    buzz = drive(osc(f, n, "saw") * 0.6, 3.0) * env(n, 0.001, 0.2) * 0.5
    cr = highpass(noise(n), 2500) * (RNG.uniform(0, 1, n) > 0.97) * env(n, 0.001, 0.15) * 1.2
    return reverb(mix((0, lowpass(buzz, 3500)), (0, cr), (0, click(0.004, 3000, 1.0))), 0.12, 0.45)


def death():
    # 玩家倒下：一记闷响 + 颤音下坠
    n = int(SR * 0.5)
    f = sweep(620, 70, n) * (1 + 0.03 * osc(18, n, "sine"))
    fall = crush(osc(f, n, "square", 0.4) * env(n, 0.002, 0.22) * 0.35, 6, 2)
    hit = lowpass(noise(int(SR * 0.12)), 2500) * env(int(SR * 0.12), 0.0005, 0.03) * 0.9
    return reverb(mix((0, hit), (0.01, lowpass(fall, 3000))), 0.18, 0.6)


def timeout():
    beeps = [(i * 0.13, tone(f, 0.11, "square", 0.06, duty=0.5, gain=0.3)) for i, f in enumerate((880, 660, 440))]
    return reverb(mix(*[(a, lowpass(b, 3000)) for a, b in beeps]), 0.15, 0.4)


def rewind():
    # 录像带倒带：带子嘶声 + 一串快速乱跳的高音
    n = int(SR * 0.75)
    hiss = bandpass(noise(n), 3500, 0.7) * 0.25
    f = 900 + 1600 * RNG.uniform(0, 1, n // 900 + 1).repeat(900)[:n]
    war = osc(f * sweep(1.0, 1.6, n), n, "square", 0.3) * 0.12
    shape = np.minimum(1.0, np.linspace(0, 6, n)) * np.minimum(1.0, np.linspace(5, 0, n))
    return lowpass(hiss + war, 6000) * shape


# ================================================================ 守卫
def spot():
    # 被发现：两下又短又高的警示音
    a = tone(note("E6"), 0.07, "square", 0.03, duty=0.25, gain=0.32)
    b = tone(note("A6"), 0.16, "square", 0.06, duty=0.25, gain=0.32)
    return reverb(mix((0, lowpass(a, 6000)), (0.06, lowpass(b, 6000))), 0.2, 0.5)


def gunshot():
    n = int(SR * 0.35)
    crack = highpass(noise(int(SR * 0.01)), 3000) * 1.2
    body = lowpass(noise(n), sweep(5000, 300, n)) * env(n, 0.0005, 0.05)
    boom = osc(sweep(90, 35, n), n, "sine") * env(n, 0.001, 0.09) * 0.9
    return reverb(drive(mix((0, crack), (0, body), (0, boom)), 2.0), 0.25, 0.7, 3500)


def alarm():
    n = int(SR * 0.7)
    lfo = 0.5 - 0.5 * np.cos(np.linspace(0, 4 * np.pi, n))
    s = osc(700 + 420 * lfo, n, "square", 0.5) * 0.25 * np.minimum(1, np.linspace(0, 20, n)) * np.minimum(1, np.linspace(6, 0, n))
    return reverb(lowpass(s, 2800), 0.2, 0.5)


def laser():
    n = int(SR * 0.2)
    b = osc(sweep(1800, 260, n), n, "saw") * (0.6 + 0.4 * osc(60, n, "square")) * env(n, 0.001, 0.07) * 0.4
    return reverb(mix((0, lowpass(b, 5000)), (0, click(0.004, 5000, 0.8))), 0.15, 0.4)


# ================================================================ 道具 / 关卡
def pickup():
    seq = [(i * 0.035, mix((0, tone(note(k), 0.12, "tri", 0.05, gain=0.5)), (0, tone(note(k) * 2, 0.08, "sine", 0.03, gain=0.12))))
           for i, k in enumerate(("C6", "E6", "G6", "C7"))]
    return reverb(mix(*seq), 0.22, 0.6)


def timer_start():
    tick = lambda f: mix((0, click(0.003, 4500, 0.8)), (0, tone(f, 0.05, "sine", 0.015, gain=0.5)))
    n = int(SR * 0.3)
    rise = osc(sweep(400, 1200, n), n, "tri") * env(n, 0.03, 0.15) * 0.25
    return reverb(mix((0, tick(1500)), (0.1, tick(1100)), (0.16, rise)), 0.15, 0.45)


def timer_tick():
    return mix((0, click(0.002, 5000, 0.6)), (0, tone(1480, 0.06, "sine", 0.018, gain=0.55)))


def clear_all():
    # 最后一个守卫倒下（慢动作）：低频冲击 + 明亮的大和弦慢慢展开
    ni = int(SR * 0.6)
    sub = osc(sweep(80, 32, ni), ni, "sine") * env(ni, 0.001, 0.25) * 0.8
    nc = int(SR * 1.3)
    ch = np.zeros(nc)
    for k in ("D4", "A4", "D5", "F#5", "A5"):
        ch += (osc(note(k), nc, "tri") + osc(note(k) * 1.004, nc, "saw") * 0.25) * 0.12
    ch *= env(nc, 0.08, 0.5)
    return reverb(mix((0, sub), (0, click(0.006, 2500, 1.0)), (0.02, ch)), 0.35, 1.3, 6000)


def level_clear():
    # 通关小曲：上行琶音落到一个长和弦
    arp = [(i * 0.075, tone(note(k), 0.16, "square", 0.06, duty=0.25, gain=0.22)) for i, k in
           enumerate(("A4", "C5", "E5", "A5", "C6"))]
    nc = int(SR * 1.0)
    ch = sum(osc(note(k), nc, "tri") for k in ("A4", "E5", "A5", "C#6")) * 0.14 * env(nc, 0.01, 0.4)
    return reverb(mix(*[(a, lowpass(b, 5000)) for a, b in arp], (0.4, ch)), 0.3, 1.1)


# ================================================================ 输出
SOUNDS = {   # 名字: (函数, 峰值 dBFS)
    "ui_move": (ui_move, -9), "ui_confirm": (ui_confirm, -6), "ui_back": (ui_back, -8),
    "ui_deny": (ui_deny, -7), "ui_toggle": (ui_toggle, -8), "ui_tick": (ui_tick, -12),
    "ui_tab": (ui_tab, -9), "ui_type": (ui_type, -14), "ui_channel": (ui_channel, -10),
    "pause": (pause, -6), "resume": (resume, -7), "start": (start, -3), "boot": (boot, -6),
    "power_off": (power_off, -5), "wipe_in": (wipe_in, -14),
    "jump": (jump, -10), "jump_air": (jump_air, -9), "jump_wall": (jump_wall, -9),
    "jump_super": (jump_super, -7), "land": (land, -6),
    "dart": (dart, -7), "blink": (blink, -9), "airgun": (airgun, -3), "throw": (throw, -8),
    "catch": (catch, -10), "rapier": (rapier, -6), "deflect": (deflect, -5),
    "kill": (kill, -3), "zap": (zap, -4), "death": (death, -4), "timeout": (timeout, -6),
    "rewind": (rewind, -9),
    "spot": (spot, -6), "gunshot": (gunshot, -2), "alarm": (alarm, -8), "laser": (laser, -5),
    "pickup": (pickup, -7), "timer_start": (timer_start, -7), "timer_tick": (timer_tick, -9),
    "clear_all": (clear_all, -4), "level_clear": (level_clear, -5),
}


def write(name, x, peak_db):
    x = x - np.mean(x)
    # 去掉尾部的静音（低于 -70dB）
    thr = np.max(np.abs(x)) * 10 ** (-70 / 20)
    nz = np.nonzero(np.abs(x) > thr)[0]
    x = x[: nz[-1] + 1] if len(nz) else x
    x = fade(x, 0.006)
    x = x / max(np.max(np.abs(x)), 1e-9) * 10 ** (peak_db / 20)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return len(x) / SR


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, (fn, db) in SOUNDS.items():
        print("%-12s %.2fs" % (name, write(name, fn(), db)))
