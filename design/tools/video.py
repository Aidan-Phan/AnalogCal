"""Demo video for AnalogCal, animated from the app's design (facesvg.py).
Usage: python3 video.py frames SCENE T   -> writes check frame PNG
       python3 video.py render           -> renders all scenes and joins them"""
import math
import os
import subprocess
import sys
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from facesvg import (CX, CY, EVENTS, FONT, THEMES, State, W as SW, H as SH, doc, face, fmt_time,
                     system_clock, watch, countdown, segments, trim, arc_d, pt)

VW, VH, FPS = 1280, 720, 30
CASE = "#2E2C35"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def bg():
    return ('<defs><radialGradient id="vbg" cx="30%" cy="45%" r="85%">'
            '<stop offset="0%" stop-color="#231C46"/><stop offset="100%" stop-color="#0B0918"/></radialGradient></defs>'
            f'<rect width="{VW}" height="{VH}" fill="url(#vbg)"/>')


def caption(title, body, x=700, op=1.0):
    lines = body.split("\n")
    total = 54 + 38 * len(lines)
    y0 = VH / 2 - total / 2 + 36
    parts = [f'<g opacity="{op:.2f}">',
             f'<text x="{x}" y="{y0:.0f}" font-family="{FONT}" font-size="42" font-weight="600" fill="#FFFFFF">{title}</text>']
    for i, ln in enumerate(lines):
        parts.append(f'<text x="{x}" y="{y0 + 54 + 38 * i:.0f}" font-family="{FONT}" font-size="25" fill="#C9C6EE">{ln}</text>')
    parts.append('</g>')
    return "".join(parts)


WX, WY, WS = 120, 70, 1.105   # watch position and scale in the frame


def place(screen, crown_glow=0.0):
    return watch(screen, "amethyst", WX, WY, WS, crown_glow=crown_glow, case_color=CASE)


def screen_to_frame(x, y):
    return WX + (20 + x) * WS, WY + (20 + y) * WS


def fade(t, dur, inn=0.3, out=0.3):
    a = 0.0
    if t < inn:
        a = 1 - t / inn
    elif t > dur - out:
        a = (t - (dur - out)) / out
    return f'<rect width="{VW}" height="{VH}" fill="#000" opacity="{max(0, min(1, a)):.3f}"/>' if a > 0 else ""


def mix(a, b, k):
    """Crossfade two screens (396x484 inner SVG strings)."""
    if k <= 0:
        return a
    if k >= 1:
        return b
    return f'<g>{a}</g><g opacity="{k:.3f}">{b}</g>'


# ---------- other screens ----------

def detail_screen(theme, now, e):
    t = THEMES[theme]
    col = t["events"][e.cal % 5]
    status = "IN " + countdown(e, now).replace("M", " MIN").replace("H", " HR") if e.start > now else "NOW"
    nxt = EVENTS[EVENTS.index(e) + 1] if EVENTS.index(e) + 1 < len(EVENTS) else None
    s = [f'<rect width="{SW}" height="{SH}" fill="{t["bg"]}"/>',
         f'<text x="40" y="58" font-family="{FONT}" font-size="22" font-weight="600" fill="{t["accent"]}">‹ Today</text>',
         system_clock(now, light=theme == "chalk"),
         f'<rect x="40" y="96" width="6" height="104" rx="3" fill="{col}"/>',
         f'<text x="62" y="118" font-family="{FONT}" font-size="15" font-weight="700" letter-spacing="1" fill="{col}">{status}</text>',
         f'<text x="62" y="156" font-family="{FONT}" font-size="34" font-weight="700" fill="{t["text"]}">{e.title}</text>',
         f'<text x="62" y="192" font-family="{FONT}" font-size="20" fill="{t["label"]}">{fmt_time(e.start, False)} – {fmt_time(e.end)}</text>',
         f'<rect x="32" y="222" width="332" height="104" rx="20" fill="{t["track"]}"/>',
         f'<circle cx="62" cy="256" r="7" fill="none" stroke="{t["label"]}" stroke-width="2"/>',
         f'<text x="82" y="263" font-family="{FONT}" font-size="19" fill="{t["text"]}">{e.place or "No location"}</text>',
         f'<rect x="55" y="286" width="14" height="13" rx="3" fill="none" stroke="{t["label"]}" stroke-width="2"/>',
         f'<text x="82" y="300" font-family="{FONT}" font-size="19" fill="{t["text"]}">Google · Classes</text>']
    if nxt:
        nc = t["events"][nxt.cal % 5]
        s.append(f'<rect x="40" y="364" width="5" height="40" rx="2.5" fill="{nc}"/>'
                 f'<text x="58" y="380" font-family="{FONT}" font-size="14" font-weight="700" letter-spacing="1" fill="{t["label"]}">THEN</text>'
                 f'<text x="58" y="402" font-family="{FONT}" font-size="19" font-weight="600" fill="{t["text"]}">{nxt.title} · {fmt_time(nxt.start)}</text>')
    return "".join(s)


def settings_screen(theme, now, row_hl=0.0):
    t = THEMES[theme]
    row = "#22202C"
    s = [f'<rect width="{SW}" height="{SH}" fill="#000"/>',
         f'<text x="40" y="58" font-family="{FONT}" font-size="24" font-weight="700" fill="#FFFFFF">Settings</text>',
         system_clock(now),
         f'<rect x="24" y="92" width="348" height="74" rx="22" fill="{row}"/>',
         f'<rect x="24" y="92" width="348" height="74" rx="22" fill="#FFFFFF" opacity="{0.18 * row_hl:.2f}"/>',
         f'<text x="48" y="124" font-family="{FONT}" font-size="21" font-weight="600" fill="#FFFFFF">Face</text>',
         f'<text x="48" y="151" font-family="{FONT}" font-size="18" fill="#999FFF">{"Amethyst" if theme == "amethyst" else "Chalk"}</text>',
         f'<text x="350" y="138" font-family="{FONT}" font-size="22" fill="#8E8C99" text-anchor="end">›</text>',
         f'<rect x="24" y="176" width="348" height="74" rx="22" fill="{row}"/>',
         f'<text x="48" y="208" font-family="{FONT}" font-size="21" font-weight="600" fill="#FFFFFF">Reminders</text>',
         f'<text x="48" y="235" font-family="{FONT}" font-size="18" fill="#999FFF">10 min before</text>',
         f'<text x="350" y="222" font-family="{FONT}" font-size="22" fill="#8E8C99" text-anchor="end">›</text>',
         f'<text x="40" y="292" font-family="{FONT}" font-size="16" fill="#8E8C99">Turn the Digital Crown to move</text>',
         f'<text x="40" y="314" font-family="{FONT}" font-size="16" fill="#8E8C99">between events. Double tap or</text>',
         f'<text x="40" y="336" font-family="{FONT}" font-size="16" fill="#8E8C99">tap an arc to open one.</text>']
    return "".join(s)


def picker_screen(now, chalk_k):
    """Face picker; chalk_k moves the checkmark from Amethyst (0) to Chalk (1)."""
    row = "#22202C"
    s = [f'<rect width="{SW}" height="{SH}" fill="#000"/>',
         f'<text x="40" y="58" font-family="{FONT}" font-size="22" font-weight="600" fill="#999FFF">‹ Face</text>',
         system_clock(now)]
    for i, name in enumerate(("Amethyst", "Chalk")):
        y = 92 + i * 84
        on = (1 - chalk_k) if i == 0 else chalk_k
        s.append(f'<rect x="24" y="{y}" width="348" height="72" rx="22" fill="{row}"/>'
                 f'<text x="48" y="{y + 45}" font-family="{FONT}" font-size="22" font-weight="600" fill="#FFFFFF">{name}</text>'
                 f'<path d="M 326 {y + 37} l 8 8 l 16 -18" fill="none" stroke="#999FFF" stroke-width="4" '
                 f'stroke-linecap="round" stroke-linejoin="round" opacity="{on:.2f}"/>')
    return "".join(s)


def banner(k, now):
    """Reminder notification sliding down from the top; k in 0..1."""
    y = -170 + 188 * ease(k)
    return (f'<g transform="translate(0 {y:.1f})">'
            f'<rect x="16" y="0" width="364" height="150" rx="30" fill="#1D1B24" opacity="0.97"/>'
            f'<circle cx="54" cy="38" r="17" fill="#2E2766"/><circle cx="54" cy="38" r="11" fill="none" stroke="#E9C46A" stroke-width="2.5"/>'
            f'<path d="M 54 38 L 54 30 M 54 38 L 60 41" stroke="#999FFF" stroke-width="2.5" stroke-linecap="round"/>'
            f'<text x="82" y="44" font-family="{FONT}" font-size="15" font-weight="700" letter-spacing="1" fill="#8E8C99">ANALOGCAL · NOW</text>'
            f'<text x="36" y="92" font-family="{FONT}" font-size="26" font-weight="700" fill="#FFFFFF">Section</text>'
            f'<text x="36" y="124" font-family="{FONT}" font-size="18" fill="#C9C6EE">In 10 min · 10:00 AM · Center Hall 105</text>'
            f'</g>')


def mini_ring(cx, cy, r, now):
    """Day Ring complication: today's events around a small dial."""
    s = [f'<circle cx="{cx}" cy="{cy}" r="{r + 4}" fill="#16131F"/>']
    pal = THEMES["amethyst"]["events"]
    ro, ri = r - 4, r - 12
    for i, is_pm, a, b, end in segments(EVENTS):
        rr, w = (ri, 5) if is_pm else (ro, 7)
        a2, b2 = trim(rr, w, a, b)
        x1, y1 = cx + rr * math.sin(a2 / 6 * math.pi), cy - rr * math.cos(a2 / 6 * math.pi)
        x2, y2 = cx + rr * math.sin(b2 / 6 * math.pi), cy - rr * math.cos(b2 / 6 * math.pi)
        op = 0.3 if end <= now else (0.5 if is_pm != (now >= 12) else 1)
        s.append(f'<path d="M {x1:.1f} {y1:.1f} A {rr} {rr} 0 0 1 {x2:.1f} {y2:.1f}" fill="none" stroke="{pal[EVENTS[i].cal % 5]}" '
                 f'stroke-width="{w}" stroke-linecap="round" opacity="{op}"/>')
    s.append(f'<text x="{cx}" y="{cy + 7}" font-family="{FONT}" font-size="19" font-weight="700" fill="#FFFFFF" text-anchor="middle">10:00</text>')
    return "".join(s)


def complication_face(now):
    hh = int(now) % 12 or 12
    mm = int((now - int(now)) * 60)
    return (f'<rect width="{SW}" height="{SH}" fill="#000"/>'
            f'<text x="40" y="70" font-family="{FONT}" font-size="22" font-weight="700" letter-spacing="1.5" fill="#E9C46A">WED 19</text>'
            f'<text x="36" y="168" font-family="{FONT}" font-size="104" font-weight="600" fill="#FFFFFF" letter-spacing="-3">{hh}:{mm:02d}</text>'
            f'<rect x="28" y="196" width="340" height="128" rx="24" fill="#16131F"/>'
            f'<rect x="46" y="216" width="6" height="88" rx="3" fill="#999FFF"/>'
            f'<text x="66" y="240" font-family="{FONT}" font-size="17" font-weight="700" letter-spacing="0.8" fill="#999FFF">IN 10 MIN</text>'
            f'<text x="66" y="274" font-family="{FONT}" font-size="28" font-weight="700" fill="#FFFFFF">Section</text>'
            f'<text x="66" y="302" font-family="{FONT}" font-size="18" fill="#8E8C99">10:00 – 11:30 · Center Hall</text>'
            f'{mini_ring(96, 400, 52, now)}'
            f'<circle cx="198" cy="400" r="56" fill="#16131F"/><text x="198" y="392" font-family="{FONT}" font-size="15" font-weight="700" '
            f'fill="#F29E5B" text-anchor="middle">BPM</text><text x="198" y="420" font-family="{FONT}" font-size="26" font-weight="700" '
            f'fill="#FFFFFF" text-anchor="middle">72</text>'
            f'<circle cx="300" cy="400" r="56" fill="#16131F"/><text x="300" y="392" font-family="{FONT}" font-size="15" font-weight="700" '
            f'fill="#999FFF" text-anchor="middle">FREE</text><text x="300" y="420" font-family="{FONT}" font-size="24" font-weight="700" '
            f'fill="#FFFFFF" text-anchor="middle">8h 25m</text>')


def labels_tag(text, x, y, op):
    w = 16 + len(text) * 12.5
    return (f'<g opacity="{op:.2f}"><rect x="{x}" y="{y}" width="{w:.0f}" height="40" rx="20" fill="#FFFFFF" opacity="0.12"/>'
            f'<text x="{x + w / 2:.0f}" y="{y + 27}" font-family="{FONT}" font-size="20" font-weight="600" fill="#FFFFFF" '
            f'text-anchor="middle">{text}</text></g>')


def ripple(cx, cy, k, color="#FFFFFF"):
    if k <= 0 or k >= 1:
        return ""
    return (f'<circle cx="{cx}" cy="{cy}" r="{10 + 40 * k:.1f}" fill="none" stroke="{color}" stroke-width="3" opacity="{(1 - k) * 0.9:.2f}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{6 + 22 * k:.1f}" fill="{color}" opacity="{(1 - k) * 0.25:.2f}"/>')


# ---------- scenes ----------

BASE = 9.75  # 9:45


def s_title(t, d):
    now = BASE + t / 3600
    a = watch(face(State(theme="amethyst", now=now)), "amethyst", 600, 150, 0.72, case_color=CASE)
    c = watch(face(State(theme="chalk", now=now)), "chalk", 930, 150, 0.72, case_color=CASE)
    k = ease(t / 1.2)
    txt = (f'<g opacity="{k:.2f}"><text x="80" y="330" font-family="{FONT}" font-size="76" font-weight="700" fill="#FFFFFF">AnalogCal</text>'
           f'<text x="82" y="378" font-family="{FONT}" font-size="26" fill="#C9C6EE">Your calendar on an analog</text>'
           f'<text x="82" y="412" font-family="{FONT}" font-size="26" fill="#C9C6EE">Apple Watch dial.</text></g>')
    return bg() + a + c + txt + fade(t, d)


def s_dial(t, d):
    now = BASE + t / 3600
    pulse = 0.5 + 0.5 * math.sin(t * 2.4)
    scr = face(State(theme="amethyst", now=now, glow_pulse=pulse * ease((t - 2) / 1)))
    return bg() + place(scr) + caption("Your day, around the dial",
                                       "Morning events on the outer ring,\nafternoon on the inner.\nThe next one is labelled on its arc.") + fade(t, d)


CROWN_STEPS = [(0.9, 1), (1.9, 1), (2.9, 1), (3.9, 1), (5.4, -4)]


def s_crown(t, d):
    now = BASE + (5 + t) / 3600
    off = sum(st for at, st in CROWN_STEPS if t >= at)
    glow = max([0.0] + [max(0, 1 - (t - at) / 0.45) for at, _ in CROWN_STEPS if t >= at])
    scr = face(State(theme="amethyst", now=now, highlight=1 + off))
    cx, cy = screen_to_frame(452, 160)
    arrow = (f'<g opacity="{0.35 + 0.65 * glow:.2f}"><path d="M {cx + 34:.0f} {cy - 30:.0f} A 36 36 0 0 1 {cx + 34:.0f} {cy + 30:.0f}" '
             f'fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>'
             f'<path d="M {cx + 24:.0f} {cy + 26:.0f} l 10 6 l 2 -12" fill="none" stroke="#FFFFFF" stroke-width="4" '
             f'stroke-linecap="round" stroke-linejoin="round"/></g>')
    return (bg() + place(scr, crown_glow=glow) + arrow +
            caption("Turn the Digital Crown", "Each click steps to the next event.\nAfter a few seconds, it returns\nto what's next.") + fade(t, d))


def s_doubletap(t, d):
    now = BASE + (12 + t) / 3600
    e = EVENTS[1]
    k = ease((t - 1.3) / 0.45)
    scr = mix(face(State(theme="amethyst", now=now)), detail_screen("amethyst", now, e), k)
    cx, cy = screen_to_frame(198, 242)
    rip = ripple(cx, cy, (t - 0.7) / 0.5) + ripple(cx, cy, (t - 0.95) / 0.5)
    tag = labels_tag("Double tap", 380, 640, 1 - ease((t - 1.6) / 0.4) if t > 0.5 else ease((t - 0.3) / 0.3))
    return (bg() + place(scr) + rip + tag +
            caption("Double tap to open it", "Pinch your fingers, or tap an arc,\nfor time, place and calendar.") + fade(t, d))


def s_settings(t, d):
    now = BASE + (20 + t) / 3600
    if t < 1.0:
        scr = face(State(theme="amethyst", now=now))
    elif t < 1.4:
        scr = mix(face(State(theme="amethyst", now=now)), settings_screen("amethyst", now), ease((t - 1.0) / 0.4))
    elif t < 2.2:
        scr = settings_screen("amethyst", now, row_hl=ease((t - 1.8) / 0.2))
    elif t < 2.5:
        scr = mix(settings_screen("amethyst", now, 1), picker_screen(now, 0), ease((t - 2.2) / 0.3))
    elif t < 3.6:
        scr = picker_screen(now, ease((t - 2.9) / 0.25))
    else:
        scr = mix(picker_screen(now, 1), face(State(theme="chalk", now=now)), ease((t - 3.6) / 0.5))
    cx, cy = screen_to_frame(198, 300)
    press = ""
    if 0.2 < t < 1.1:
        k = ease((t - 0.2) / 0.75)
        press = (f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="34" fill="#FFFFFF" opacity="0.18"/>'
                 f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="34" fill="none" stroke="#FFFFFF" stroke-width="5" '
                 f'stroke-dasharray="{213.6 * k:.1f} 300" transform="rotate(-90 {cx:.0f} {cy:.0f})"/>')
    tap = ""
    if 1.7 < t < 2.2:
        px, py = screen_to_frame(198, 129)
        tap = ripple(px, py, (t - 1.7) / 0.45)
    if 2.75 < t < 3.25:
        px, py = screen_to_frame(198, 212)
        tap = ripple(px, py, (t - 2.75) / 0.45)
    return (bg() + place(scr) + press + tap +
            caption("Long-press for settings", "Switch between Amethyst and Chalk,\nand choose when reminders arrive.") + fade(t, d))


def s_always_on(t, d):
    now = BASE + (30 + t) / 3600
    k = ease((t - 1.5) / 0.6)
    scr = mix(face(State(theme="chalk", now=now)), face(State(theme="chalk", now=now, dim=True)), k)
    tag = labels_tag("Wrist down", 395, 640, ease((t - 1.3) / 0.3))
    return (bg() + place(scr) + tag +
            caption("Wrist down, it goes dark", "A black low-power face saves\nbattery on the OLED screen.") + fade(t, d))


def s_date(t, d):
    k = ease((t - 0.4) / 3.4)
    now = 10.25 + k * (11.33 - 10.25)
    hl = next(i for i, e in enumerate(EVENTS) if e.end > now)
    scr = face(State(theme="amethyst", now=now, highlight=hl, seconds=False))
    return (bg() + place(scr) +
            caption("The date stays clear", "When the hands reach the top,\nthe date hops down to 6 o'clock.") + fade(t, d))


def s_reminder(t, d):
    now = 9 + 50 / 60 + t / 3600
    scr = face(State(theme="amethyst", now=now)) + banner((t - 0.6) / 0.5, now)
    return (bg() + place(scr) +
            caption("A tap before every event", "Reminders 10 minutes ahead,\neven while the app is open.") + fade(t, d))


def s_complications(t, d):
    now = 9 + 50 / 60 + t / 3600
    return (bg() + place(complication_face(now)) +
            caption("On any watch face", "Up Next and Day Ring complications\nkeep your schedule a glance away.") + fade(t, d))


def s_end(t, d):
    now = BASE + (40 + t) / 3600
    a = watch(face(State(theme="amethyst", now=now)), "amethyst", 600, 150, 0.72, case_color=CASE)
    c = watch(face(State(theme="chalk", now=now, dim=True)), "chalk", 930, 150, 0.72, case_color=CASE)
    txt = ('<text x="80" y="320" font-family="Inter" font-size="64" font-weight="700" fill="#FFFFFF">AnalogCal</text>'
           '<text x="82" y="372" font-family="Inter" font-size="26" font-weight="600" fill="#999FFF">github.com/Aidan-Phan/AnalogCal</text>'
           '<text x="82" y="414" font-family="Inter" font-size="19" fill="#8E8C99">Animated from the app\'s design.</text>')
    return bg() + a + c + txt + fade(t, d, out=0.6)


SCENES = [
    ("01_title", s_title, 3.0), ("02_dial", s_dial, 5.0), ("03_crown", s_crown, 6.5),
    ("04_doubletap", s_doubletap, 4.5), ("05_settings", s_settings, 5.5), ("06_always_on", s_always_on, 4.5),
    ("07_date", s_date, 4.5), ("08_reminder", s_reminder, 4.0), ("09_complications", s_complications, 4.5),
    ("10_end", s_end, 3.5),
]


def render_png(svg):
    return subprocess.run(["rsvg-convert", "-w", str(VW), "-h", str(VH)], input=svg.encode(),
                          capture_output=True, check=True).stdout


def frame_png(args):
    name, i = args
    fn, dur = {n: (f, d) for n, f, d in SCENES}[name]
    return render_png(doc(VW, VH, fn(i / FPS, dur), bg="#0B0918"))


def render_scene(name, pool):
    dur = {n: d for n, _, d in SCENES}[name]
    n = int(round(dur * FPS))
    tmp = os.path.join(OUT, f"{name}.part.mp4")
    final = os.path.join(OUT, f"{name}.mp4")
    enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(FPS), "-c:v", "png",
                            "-i", "-", "-c:v", "libx264", "-crf", "18", "-preset", "veryfast", "-pix_fmt", "yuv420p",
                            "-r", str(FPS), "-f", "mp4", tmp], stdin=subprocess.PIPE)
    for png in pool.imap(frame_png, [(name, i) for i in range(n)], chunksize=4):
        enc.stdin.write(png)
    enc.stdin.close()
    if enc.wait() == 0:
        os.replace(tmp, final)
        print("done", name, flush=True)
    else:
        print("FAILED", name, flush=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1] == "frames":
        name, t = sys.argv[2], float(sys.argv[3])
        fn, dur = {n: (f, d) for n, f, d in SCENES}[name]
        with open(os.path.join(OUT, f"check_{name}_{t}.png"), "wb") as f:
            f.write(render_png(doc(VW, VH, fn(t, dur), bg="#0B0918")))
    elif sys.argv[1] == "render":
        names = sys.argv[2:] or [n for n, _, _ in SCENES]
        with Pool(2) as pool:
            for nm in names:
                render_scene(nm, pool)
