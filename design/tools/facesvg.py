"""SVG renderer for the AnalogCal v6 faces (Amethyst, Chalk), mirroring the
Swift FaceView. Coordinates are the 396 x 484 design space of the watch screen.
Used for the repo's design exports and the demo video."""
import math
from dataclasses import dataclass, field
from functools import lru_cache
from PIL import ImageFont

W, H = 396, 484
CX, CY = 198, 242
DIAL = 0.92
OUTER_R, INNER_R, OUTER_W, INNER_W = 176, 158, 13, 9
FONT = "Inter"
BOLD = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"


@lru_cache(maxsize=4096)
def advance(ch, size):
    return ImageFont.truetype(BOLD, int(size * 8)).getlength(ch) / 8

THEMES = {
    "amethyst": dict(
        bg="#120E26", dialIn="#2E2766", dialOut="#120E26", track="#262052", track2="#1D1840",
        minTick="#5F58A8", index="#E9C46A", numeral="#E9C46A", hand="#F0CF7A", lume="#999FFF",
        accent="#999FFF", dateBg="#262052", dateText="#E9C46A", label="#B8B5F0", text="#F5F3FF",
        nowFill="#E9C46A", nowStroke="#120E26", heart="#F29E5B", battery="#999FFF", free="#999FFF",
        events=["#999FFF", "#E9C46A", "#D3B4FF", "#F29E5B", "#6B74F5"],
        onEvents=["#120E26", "#120E26", "#120E26", "#120E26", "#FFFFFF"],
        indexW=4, mode="all", numSize=26, numWeight=500, numR=112, slim=True,
        case="#3A3360", stage="#DCD9F2"),
    "chalk": dict(
        bg="#FFFFFF", dialIn="#FFFFFF", dialOut="#F1F2F4", track="#ECEEF1", track2="#F3F4F6",
        minTick="#C2C6CC", index="#111316", numeral="#111316", hand="#111316", lume="#FF5A1F",
        accent="#FF5A1F", dateBg="#111316", dateText="#FFFFFF", label="#5B616B", text="#111316",
        nowFill="#FF5A1F", nowStroke="#FFFFFF", heart="#F43F7A", battery="#12B76A", free="#1F6FEB",
        events=["#1F6FEB", "#FF8A00", "#8B5CF6", "#12B76A", "#F43F7A"],
        onEvents=["#FFFFFF", "#111316", "#FFFFFF", "#111316", "#FFFFFF"],
        indexW=5, mode="quarters", numSize=46, numWeight=700, numR=106, slim=False,
        case="#E6E6E3", stage="#DADDE0"),
}


@dataclass
class Event:
    title: str
    start: float  # hours since midnight
    end: float
    cal: int
    place: str = ""


EVENTS = [
    Event("Lecture", 8.5, 9.5, 0, "Price Center"),
    Event("Section", 10.0, 11.5, 0, "Center Hall 105"),
    Event("Lunch", 12.5, 13.25, 1, "Sixth College"),
    Event("Study group", 14.0, 15.5, 2, "Geisel Library"),
    Event("Gym", 17.0, 18.0, 3, "RIMAC"),
    Event("Dinner", 19.0, 20.0, 4, ""),
]


def fmt_time(h, ampm=True):
    hh = int(h) % 24
    mm = int(round((h - int(h)) * 60))
    if mm == 60:
        hh, mm = (hh + 1) % 24, 0
    suffix = " AM" if hh < 12 else " PM"
    d = hh % 12 or 12
    return f"{d}:{mm:02d}" + (suffix if ampm else "")


def countdown(e, now):
    if e.start > now:
        m = max(1, math.ceil((e.start - now) * 60 - 1e-9))
        if m < 60:
            return f"{m}M"
        h, mm = divmod(m, 60)
        return f"{h}H" if mm == 0 else f"{h}H {mm}M"
    if e.end > now:
        return "NOW"
    m = max(1, math.ceil((now - e.end) * 60 - 1e-9))
    if m < 60:
        return f"{m}M AGO"
    h, mm = divmod(m, 60)
    return (f"{h}H" if mm == 0 else f"{h}H {mm}M") + " AGO"


def low_power(t):
    t = dict(t)
    ink = "#B9BEC6" if t["case"] == "#E6E6E3" else t["numeral"]
    t.update(bg="#000000", dialIn="#000000", dialOut="#000000", track="rgba(255,255,255,0.07)",
             track2="rgba(255,255,255,0.05)", minTick="none", index=ink, numeral=ink, hand=ink,
             dateBg="none", dateText=ink, label="rgba(255,255,255,0.35)", text="rgba(255,255,255,0.6)",
             nowFill=ink, nowStroke="#000000")
    t["inkOp"] = 0.55
    t["dim"] = True
    return t


def pt(r, h):
    a = h / 12 * 2 * math.pi
    return CX + r * math.sin(a), CY - r * math.cos(a)


def arc_d(r, h1, h2, reverse=False):
    x1, y1 = pt(r, h1)
    x2, y2 = pt(r, h2)
    large = 1 if (h2 - h1) * 30 > 180 else 0
    if reverse:
        return f"M {x2:.2f} {y2:.2f} A {r} {r} 0 {large} 0 {x1:.2f} {y1:.2f}"
    return f"M {x1:.2f} {y1:.2f} A {r} {r} 0 {large} 1 {x2:.2f} {y2:.2f}"


def trim(r, w, h1, h2):
    t = (w / 2) / (2 * math.pi * r) * 12
    a = h1 + t
    return a, max(h2 - t, a + 0.01)


def segments(events):
    segs = []
    for i, e in enumerate(events):
        if e.start < 12:
            segs.append((i, False, e.start, min(e.end, 12), min(e.end, 12)))
        if e.end > 12:
            s = max(e.start, 12)
            segs.append((i, True, s - 12, e.end - 12, e.end))
    return segs


@dataclass
class State:
    theme: str = "amethyst"
    now: float = 9.75          # hours, may include seconds
    highlight: int | None = 1  # event index
    dim: bool = False
    battery: int = 82
    bpm: int = 72
    date: str = "WED 19"
    seconds: bool = True
    clock: bool = True         # draw watchOS's own clock in the top-right
    glow_pulse: float = 0.0    # extra glow 0..1
    events: list = field(default_factory=lambda: EVENTS)


def free_today(events, now):
    busy, cursor = 0.0, now
    for e in sorted(events, key=lambda e: e.start):
        s, f = max(e.start, cursor), min(e.end, 24)
        if f > s:
            busy += f - s
            cursor = f
    m = int(round(max(0, 24 - now - busy) * 60))
    h, mm = divmod(m, 60)
    return f"{mm}m" if h == 0 else (f"{h}h" if mm == 0 else f"{h}h {mm}m")


def date_at_bottom(now):
    hh = int(now) % 12
    minute = (now - int(now)) * 60
    hour_deg = (hh + minute / 60) * 30
    min_deg = minute * 6

    def cov(spot):
        n = 0
        for d in (hour_deg, min_deg):
            x = abs((d - spot) % 360)
            if min(x, 360 - x) < 40:
                n += 1
        return n
    return cov(180) < cov(0)


def face(s: State) -> str:
    """Return the inner SVG (no <svg> wrapper) of the watch screen, 396 x 484."""
    t = THEMES[s.theme]
    dim = s.dim
    if dim:
        t = low_power(t)
    ink_op = t.get("inkOp", 1)
    ev_op = 0.5 if dim else 1
    out = []
    gid = f"g{s.theme}{int(dim)}"
    out.append(f'<defs><radialGradient id="{gid}" cx="50%" cy="42%" r="62%">'
               f'<stop offset="0%" stop-color="{t["dialIn"]}"/><stop offset="100%" stop-color="{t["dialOut"]}"/>'
               f'</radialGradient></defs>')
    out.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="url(#{gid})"/>')

    out.append(f'<g transform="translate({CX} {CY}) scale({DIAL}) translate({-CX} {-CY})">')
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{OUTER_R}" fill="none" stroke="{t["track"]}" stroke-width="{OUTER_W}"/>')
    out.append(f'<circle cx="{CX}" cy="{CY}" r="{INNER_R}" fill="none" stroke="{t["track2"]}" stroke-width="{INNER_W}"/>')

    now = s.now
    pm_now = now >= 12
    now_hour = now % 12
    segs = segments(s.events)
    hl = s.highlight
    hl_seg = None
    if hl is not None:
        mine = [g for g in segs if g[0] == hl]
        future = [g for g in mine if g[4] > now]
        hl_seg = min(future, key=lambda g: g[4]) if future else (max(mine, key=lambda g: g[4]) if mine else None)

    for g in segs:
        if g is hl_seg:
            continue
        i, is_pm, a, b, seg_end = g
        r, w = (INNER_R, INNER_W) if is_pm else (OUTER_R, OUTER_W)
        a2, b2 = trim(r, w, a, b)
        op = 0.3 if seg_end <= now else (0.5 if is_pm != pm_now else 1)
        col = t["events"][s.events[i].cal % 5]
        out.append(f'<path d="{arc_d(r, a2, b2)}" fill="none" stroke="{col}" stroke-width="{w}" '
                   f'stroke-linecap="round" opacity="{op * ev_op:.2f}"/>')

    if hl_seg:
        i, is_pm, a, b, seg_end = hl_seg
        e = s.events[i]
        r = INNER_R if is_pm else OUTER_R
        tab = 18 if is_pm else 24
        col = t["events"][e.cal % 5]
        on = "rgba(255,255,255,0.85)" if dim else t["onEvents"][e.cal % 5]
        if e.start > now and is_pm == pm_now and a > now_hour and a - now_hour < 3:
            a2, b2 = trim(r, 14, now_hour, a)
            if b2 > a2 + 0.02:
                out.append(f'<path d="{arc_d(r, a2, b2)}" fill="none" stroke="{col}" stroke-width="3" '
                           f'stroke-dasharray="1 5" stroke-linecap="round" opacity="{ev_op}"/>')
        a2, b2 = trim(r, tab, a, b)
        if not dim:
            gop = 0.18 + 0.2 * s.glow_pulse
            out.append(f'<path d="{arc_d(r, a2, b2)}" fill="none" stroke="{col}" stroke-width="{tab + 10 + 8 * s.glow_pulse:.1f}" '
                       f'stroke-linecap="round" opacity="{gop:.2f}"/>')
        out.append(f'<path d="{arc_d(r, a2, b2)}" fill="none" stroke="{col}" stroke-width="{tab}" '
                   f'stroke-linecap="round" opacity="{ev_op}"/>')
        size = 11 if is_pm else 14
        mid = (a2 + b2) / 2 / 12 * 2 * math.pi
        bottom = math.cos(mid) < 0
        avail = (b2 - a2) / 12 * 2 * math.pi * r - size * 0.6
        suffix = countdown(e, now)
        name = e.title.upper()
        sp = 0.8

        def width(txt):
            return sum(advance(ch, size) + sp for ch in txt)
        label = f"{name} · {suffix}"
        while width(label) > avail and len(name) > 1:
            name = name[:-1]
            label = f"{name}… · {suffix}"
        if width(label) > avail:
            label = suffix
        total = width(label)
        ang = mid + (total / 2 / r if bottom else -total / 2 / r)
        glyphs = []
        for ch in label:
            step = (advance(ch, size) + sp) / r
            at = ang - step / 2 if bottom else ang + step / 2
            gx, gy = CX + r * math.sin(at), CY - r * math.cos(at)
            rot = math.degrees(at + (math.pi if bottom else 0))
            glyphs.append(f'<text transform="translate({gx:.2f} {gy:.2f}) rotate({rot:.2f})" y="{size * 0.36:.2f}" '
                          f'text-anchor="middle">{ch}</text>')
            ang = ang - step if bottom else ang + step
        out.append(f'<g font-family="{FONT}" font-size="{size}" font-weight="700" fill="{on}">{"".join(glyphs)}</g>')

    # Ticks and indices.
    minor, major = [], []
    for k in range(60):
        h = k / 5
        x1, y1 = pt(147, h)
        if k % 5 == 0:
            x2, y2 = pt(133, h)
            major.append(f"M{x1:.1f} {y1:.1f}L{x2:.1f} {y2:.1f}")
        else:
            x2, y2 = pt(142, h)
            minor.append(f"M{x1:.1f} {y1:.1f}L{x2:.1f} {y2:.1f}")
    if t["minTick"] != "none":
        out.append(f'<path d="{"".join(minor)}" stroke="{t["minTick"]}" stroke-width="1.5" stroke-linecap="round"/>')
    out.append(f'<path d="{"".join(major)}" stroke="{t["index"]}" stroke-width="{t["indexW"]}" stroke-linecap="round" opacity="{ink_op}"/>')

    hours = range(12) if t["mode"] == "all" else (0, 3, 6, 9)
    for h in hours:
        x, y = pt(t["numR"], h)
        out.append(f'<text x="{x:.1f}" y="{y + t["numSize"] * 0.36:.1f}" font-family="{FONT}" font-size="{t["numSize"]}" '
                   f'font-weight="{t["numWeight"]}" fill="{t["numeral"]}" text-anchor="middle" opacity="{ink_op}" '
                   f'letter-spacing="{-1 if t["mode"] == "quarters" else 0}">{12 if h == 0 else h}</text>')

    # Date window: top, or 6 o'clock when the hands would cover the top.
    dy = 288 if date_at_bottom(now) else 166
    if t["dateBg"] != "none":
        out.append(f'<rect x="156" y="{dy}" width="84" height="30" rx="11" fill="{t["dateBg"]}"/>')
    out.append(f'<text x="198" y="{dy + 21}" font-family="{FONT}" font-size="16" font-weight="700" letter-spacing="1.2" '
               f'fill="{t["dateText"]}" text-anchor="middle" opacity="{ink_op}">{s.date}</text>')

    # Now dot.
    nx, ny = pt(INNER_R if pm_now else OUTER_R, now_hour)
    out.append(f'<circle cx="{nx:.1f}" cy="{ny:.1f}" r="7" fill="{t["nowFill"]}" stroke="{t["nowStroke"]}" stroke-width="3" opacity="{0.7 if dim else 1}"/>')

    # Hands.
    hw, hlen, mw, mlen = (7, 90, 5, 142) if t["slim"] else (19, 84, 15, 130)
    minute = (now - int(now)) * 60
    hour_deg = ((int(now) % 12) + minute / 60) * 30
    min_deg = minute * 6
    for deg, w, l in ((hour_deg, hw, hlen), (min_deg, mw, mlen)):
        tip = CY - l
        sh = tip + w * 1.3
        d = (f"M {CX} {tip} L {CX + w / 2} {sh} L {CX + w / 2} 250 Q {CX} {250 + w * 0.6} {CX - w / 2} 250 "
             f"L {CX - w / 2} {sh} Z")
        lw = max(2, round(w * 0.32))
        out.append(f'<g transform="rotate({deg:.2f} {CX} {CY})" opacity="{0.8 if dim else 1}">'
                   f'<path d="{d}" fill="{t["hand"]}"/>'
                   f'<rect x="{CX - lw / 2}" y="{tip + w * 1.3 + 4}" width="{lw}" height="{round(l * 0.62)}" rx="1.5" '
                   f'fill="{t["lume"]}" opacity="{0.5 if dim else 1}"/></g>')
    if s.seconds and not dim:
        sec_deg = ((now * 3600) % 60) * 6
        out.append(f'<g transform="rotate({sec_deg:.2f} {CX} {CY})"><line x1="{CX}" y1="274" x2="{CX}" y2="96" '
                   f'stroke="{t["accent"]}" stroke-width="2" stroke-linecap="round"/>'
                   f'<circle cx="{CX}" cy="264" r="4.5" fill="{t["accent"]}"/></g>')
    out.append(f'<circle cx="{CX}" cy="{CY}" r="7.5" fill="{t["hand"]}"/>')
    out.append(f'<circle cx="{CX}" cy="{CY}" r="3.5" fill="{t["accent"]}" opacity="{0.5 if dim else 1}"/>')
    out.append('</g>')

    # Corners (design units match the Swift code).
    cop = 0.5 if dim else 1
    val = f'font-family="{FONT}" font-size="24" font-weight="700" fill="{t["text"]}"'
    lab = f'font-family="{FONT}" font-size="14" font-weight="700" letter-spacing="1" fill="{t["label"]}"'
    lvl = max(0, min(1, s.battery / 100))
    out.append(f'<rect x="36" y="38" width="28" height="16" rx="4.5" fill="none" stroke="{t["label"]}" stroke-width="2"/>'
               f'<rect x="65.5" y="43" width="3" height="6" rx="1" fill="{t["label"]}"/>'
               f'<rect x="38.5" y="40.5" width="{23 * lvl:.1f}" height="11" rx="2.5" fill="{t["battery"]}" opacity="{cop}"/>'
               f'<text x="78" y="55" {val}>{s.battery}%</text><text x="36" y="85" {lab}>BATTERY</text>')
    hx, hy, k = 47, 434, 1.3
    heart = (f"M {hx - 7 * k} {hy - k} C {hx - 7 * k} {hy - 5.5 * k} {hx - 3 * k} {hy - 8 * k} {hx} {hy - 5 * k} "
             f"C {hx + 3 * k} {hy - 8 * k} {hx + 7 * k} {hy - 5.5 * k} {hx + 7 * k} {hy - k} "
             f"C {hx + 7 * k} {hy + 3.5 * k} {hx} {hy + 8 * k} {hx} {hy + 8 * k} "
             f"C {hx} {hy + 8 * k} {hx - 7 * k} {hy + 3.5 * k} {hx - 7 * k} {hy - k} Z")
    out.append(f'<text x="36" y="409" {lab}>BPM</text><path d="{heart}" fill="{t["heart"]}" opacity="{cop}"/>'
               f'<text x="62" y="443" {val}>{s.bpm}</text>')
    out.append(f'<text x="360" y="409" {lab} text-anchor="end">FREE TODAY</text>'
               f'<circle cx="350" cy="434" r="9" fill="none" stroke="{t["free"]}" stroke-width="2.2" opacity="{cop}"/>'
               f'<path d="M 350 428.5 L 350 434 L 354 436.5" fill="none" stroke="{t["free"]}" stroke-width="2.2" '
               f'stroke-linecap="round" stroke-linejoin="round" opacity="{cop}"/>'
               f'<text x="334" y="443" {val} text-anchor="end">{free_today(s.events, now)}</text>')
    if s.clock:
        out.append(system_clock(now, dim, light=(s.theme == "chalk" and not dim)))
    return "".join(out)


def system_clock(now, dim=False, light=False):
    """watchOS draws its own digital clock in the top-right of every app."""
    hh = int(now) % 12 or 12
    mm = int((now - int(now)) * 60)
    col = "rgba(255,255,255,0.55)" if dim else ("#111316" if light else "#FFFFFF")
    return (f'<text x="362" y="54" font-family="{FONT}" font-size="26" font-weight="600" text-anchor="end" '
            f'fill="{col}">{hh}:{mm:02d}</text>')


def watch(screen_svg: str, theme: str, x: float, y: float, scale: float, crown_glow: float = 0.0,
          case_color: str | None = None) -> str:
    """Place a screen (396 x 484) inside a simple watch case at (x, y) top-left."""
    t = THEMES[theme]
    case = case_color or t["case"]
    cw, ch = 436, 524
    crown = (f'<rect x="{cw - 4}" y="150" width="20" height="58" rx="7" fill="{case}" stroke="rgba(0,0,0,0.25)" stroke-width="1.5"/>'
             f'<rect x="{cw + 8}" y="156" width="5" height="46" rx="2" fill="rgba(255,255,255,0.18)"/>'
             f'<rect x="{cw - 4}" y="250" width="10" height="70" rx="4" fill="{case}" stroke="rgba(0,0,0,0.2)" stroke-width="1.5"/>')
    if crown_glow > 0:
        crown += (f'<rect x="{cw - 8}" y="142" width="34" height="74" rx="12" fill="none" stroke="#FFFFFF" '
                  f'stroke-width="3" opacity="{crown_glow:.2f}"/>')
    cid = f"clip{abs(hash((x, y, theme))) % 100000}"
    return (f'<g transform="translate({x:.1f} {y:.1f}) scale({scale:.4f})">'
            f'<rect x="6" y="18" width="{cw}" height="{ch}" rx="112" fill="rgba(0,0,0,0.28)" filter="url(#shadow)"/>'
            f'{crown}'
            f'<rect x="0" y="0" width="{cw}" height="{ch}" rx="112" fill="{case}"/>'
            f'<rect x="1.5" y="1.5" width="{cw - 3}" height="{ch - 3}" rx="110" fill="none" stroke="rgba(255,255,255,0.18)" stroke-width="2"/>'
            f'<clipPath id="{cid}"><rect x="20" y="20" width="{W}" height="{H}" rx="92"/></clipPath>'
            f'<g clip-path="url(#{cid})"><g transform="translate(20 20)">{screen_svg}</g></g>'
            f'</g>')


def doc(w, h, body, bg="#ffffff"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}"><defs><filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">'
            f'<feGaussianBlur stdDeviation="14"/></filter></defs>'
            f'<rect width="{w}" height="{h}" fill="{bg}"/>{body}</svg>')
