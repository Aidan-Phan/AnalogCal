//  FaceView.swift
//  The v5 face, drawn in one Canvas in a 396 x 484 design space that is then
//  scaled to the watch screen. Coordinates match the design canvas.

import SwiftUI

struct FaceSnapshot {
    var heartRate: Int?
    var move: Double?
    var moveGoal: Double?
    var exercise: Double?
    var exerciseGoal: Double?
    var stand: Double?
    var standGoal: Double?
    var battery: Float?
    var freeToday: TimeInterval
}

struct FaceView: View {
    let theme: FaceTheme
    let now: Date
    let segments: [RingSegment]
    let next: DayEvent?
    /// Calendar names in the order they first appear today; sets event colours.
    let calendars: [String]
    let data: FaceSnapshot
    var showSeconds = true

    // Design-space constants (same numbers as the v5 artboards).
    static let width: CGFloat = 396
    static let height: CGFloat = 484
    static let center = CGPoint(x: 198, y: 242)
    static let dialScale: CGFloat = 0.92
    static let outerR: CGFloat = 176
    static let innerR: CGFloat = 158
    static let outerW: CGFloat = 13
    static let innerW: CGFloat = 9

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.bg))
            let s = min(size.width / Self.width, size.height / Self.height)
            var ctx = context
            ctx.translateBy(x: (size.width - Self.width * s) / 2, y: (size.height - Self.height * s) / 2)
            ctx.scaleBy(x: s, y: s)

            ctx.fill(
                Path(CGRect(x: -40, y: -40, width: Self.width + 80, height: Self.height + 80)),
                with: .radialGradient(
                    Gradient(colors: [theme.dialIn, theme.dialOut]),
                    center: CGPoint(x: 198, y: 203), startRadius: 0, endRadius: 300))

            var dial = ctx
            dial.translateBy(x: Self.center.x, y: Self.center.y)
            dial.scaleBy(x: Self.dialScale, y: Self.dialScale)
            dial.translateBy(x: -Self.center.x, y: -Self.center.y)

            drawTracks(dial)
            drawEvents(dial)
            drawTicks(dial)
            drawNumerals(dial)
            drawDate(dial)
            drawNowDot(dial)
            drawHands(dial)
            drawCorners(ctx)
        }
    }

    // MARK: Geometry helpers

    private var nowHour: Double {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        return Double((c.hour ?? 0) % 12) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    private var isAfternoon: Bool { Calendar.current.component(.hour, from: now) >= 12 }

    private func point(_ r: CGFloat, _ hour: Double) -> CGPoint {
        let a = hour / 12 * 2 * Double.pi
        return CGPoint(x: Self.center.x + r * CGFloat(sin(a)), y: Self.center.y - r * CGFloat(cos(a)))
    }

    private func arc(_ r: CGFloat, from h1: Double, to h2: Double) -> Path {
        var p = Path()
        p.addArc(
            center: Self.center, radius: r,
            startAngle: .radians(h1 / 12 * 2 * Double.pi - Double.pi / 2),
            endAngle: .radians(h2 / 12 * 2 * Double.pi - Double.pi / 2),
            clockwise: false)
        return p
    }

    /// Pulls an arc's ends in so its rounded caps do not overstate the event.
    private func trimmed(_ r: CGFloat, _ w: CGFloat, _ h1: Double, _ h2: Double) -> (Double, Double) {
        let t = Double(w / 2 / (2 * CGFloat.pi * r)) * 12
        let a = h1 + t
        return (a, max(h2 - t, a + 0.01))
    }

    private func colorIndex(_ event: DayEvent) -> Int {
        calendars.firstIndex(of: event.calendarName) ?? 0
    }

    private func color(for event: DayEvent) -> Color {
        theme.events[colorIndex(event) % theme.events.count]
    }

    private func onColor(for event: DayEvent) -> Color {
        theme.onEvents[colorIndex(event) % theme.onEvents.count]
    }

    private var nextSegment: RingSegment? {
        guard let next else { return nil }
        return segments
            .filter { $0.event.id == next.id && $0.segmentEnd > now }
            .min { $0.segmentEnd < $1.segmentEnd }
    }

    // MARK: Dial

    private func drawTracks(_ ctx: GraphicsContext) {
        ctx.stroke(Circle().path(in: CGRect(x: 198 - Self.outerR, y: 242 - Self.outerR, width: Self.outerR * 2, height: Self.outerR * 2)),
                   with: .color(theme.track), lineWidth: Self.outerW)
        ctx.stroke(Circle().path(in: CGRect(x: 198 - Self.innerR, y: 242 - Self.innerR, width: Self.innerR * 2, height: Self.innerR * 2)),
                   with: .color(theme.track2), lineWidth: Self.innerW)
    }

    private func drawEvents(_ ctx: GraphicsContext) {
        let nextSeg = nextSegment
        for seg in segments where seg.id != nextSeg?.id {
            let r = seg.isPM ? Self.innerR : Self.outerR
            let w = seg.isPM ? Self.innerW : Self.outerW
            let (a, b) = trimmed(r, w, seg.startHour, seg.endHour)
            var c = ctx
            if seg.segmentEnd <= now {
                c.opacity = theme.pastOpacity
            } else if seg.isPM != isAfternoon {
                c.opacity = theme.dullOpacity
            }
            c.stroke(arc(r, from: a, to: b), with: .color(color(for: seg.event)),
                     style: StrokeStyle(lineWidth: w, lineCap: .round))
        }

        guard let seg = nextSeg, let next else { return }
        let r = seg.isPM ? Self.innerR : Self.outerR
        let tabW: CGFloat = seg.isPM ? 18 : 24
        let col = color(for: next)

        // Dotted lead-in from "now" to the start of the next event.
        if next.start > now, seg.isPM == isAfternoon, seg.startHour > nowHour, seg.startHour - nowHour < 3 {
            let (a, b) = trimmed(r, 14, nowHour, seg.startHour)
            if b > a + 0.02 {
                ctx.stroke(arc(r, from: a, to: b), with: .color(col),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 5]))
            }
        }

        let (a, b) = trimmed(r, tabW, seg.startHour, seg.endHour)
        var glow = ctx
        glow.opacity = 0.18
        glow.stroke(arc(r, from: a, to: b), with: .color(col), style: StrokeStyle(lineWidth: tabW + 10, lineCap: .round))
        ctx.stroke(arc(r, from: a, to: b), with: .color(col), style: StrokeStyle(lineWidth: tabW, lineCap: .round))

        drawArcLabel(ctx, title: next.title.uppercased(), suffix: Self.countdown(to: next, now: now),
                     r: r, from: a, to: b, size: seg.isPM ? 11 : 14, color: onColor(for: next))
    }

    /// Writes the next event's name and countdown along its arc, upright on
    /// both the top and bottom halves of the dial.
    private func drawArcLabel(_ ctx: GraphicsContext, title: String, suffix: String,
                              r: CGFloat, from h1: Double, to h2: Double, size: CGFloat, color: Color) {
        let font = Font.system(size: size, weight: .bold)
        let spacing: CGFloat = 0.8
        let available = CGFloat((h2 - h1) / 12 * 2 * Double.pi) * r - size * 0.6

        func glyphs(_ s: String) -> [(GraphicsContext.ResolvedText, CGFloat)] {
            s.map { ch in
                let t = ctx.resolve(Text(String(ch)).font(font).foregroundColor(color))
                let w = t.measure(in: CGSize(width: 200, height: 200)).width
                return (t, (ch == " " ? max(w, size * 0.3) : w) + spacing)
            }
        }
        func width(_ g: [(GraphicsContext.ResolvedText, CGFloat)]) -> CGFloat { g.reduce(0) { $0 + $1.1 } }

        var name = Array(title)
        var items = glyphs(String(name) + " · " + suffix)
        while width(items) > available && name.count > 1 {
            name.removeLast()
            items = glyphs(String(name) + "… · " + suffix)
        }
        if width(items) > available {
            items = glyphs(suffix)
            if width(items) > available { return }
        }

        let total = width(items)
        let mid = (h1 + h2) / 2 / 12 * 2 * Double.pi
        let bottom = cos(mid) < 0
        var angle = bottom ? mid + Double(total / 2 / r) : mid - Double(total / 2 / r)
        for (glyph, w) in items {
            let step = Double(w / r)
            let at = bottom ? angle - step / 2 : angle + step / 2
            var c = ctx
            c.translateBy(x: Self.center.x + r * CGFloat(sin(at)), y: Self.center.y - r * CGFloat(cos(at)))
            c.rotate(by: .radians(bottom ? at + Double.pi : at))
            c.draw(glyph, at: .zero, anchor: .center)
            angle = bottom ? angle - step : angle + step
        }
    }

    static func countdown(to event: DayEvent, now: Date) -> String {
        if event.start <= now { return "NOW" }
        let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
        if minutes < 60 { return "\(minutes)M" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)H" : "\(h)H \(m)M"
    }

    private func drawTicks(_ ctx: GraphicsContext) {
        var minor = Path()
        var major = Path()
        for i in 0..<60 {
            let h = Double(i) / 5
            if i % 5 == 0 {
                major.move(to: point(147, h)); major.addLine(to: point(133, h))
            } else {
                minor.move(to: point(147, h)); minor.addLine(to: point(142, h))
            }
        }
        ctx.stroke(minor, with: .color(theme.minTick), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        ctx.stroke(major, with: .color(theme.index), style: StrokeStyle(lineWidth: theme.indexWidth, lineCap: .round))
    }

    private func drawNumerals(_ ctx: GraphicsContext) {
        let hours = theme.numeralMode == .all ? Array(0..<12) : [0, 3, 6, 9]
        for h in hours {
            let text = Text(h == 0 ? "12" : "\(h)").font(theme.numeralFont).foregroundColor(theme.numeral)
            ctx.draw(theme.numeralMode == .quarters ? text.tracking(-1) : text,
                     at: point(theme.numeralRadius, Double(h)), anchor: .center)
        }
    }

    private func drawDate(_ ctx: GraphicsContext) {
        let rect = CGRect(x: 156, y: 166, width: 84, height: 30)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 11), with: .color(theme.dateBg))
        let label = now.formatted(.dateTime.weekday(.abbreviated).day()).uppercased()
        ctx.draw(Text(label).font(.system(size: 16, weight: .bold)).tracking(1.2).foregroundColor(theme.dateText),
                 at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    private func drawNowDot(_ ctx: GraphicsContext) {
        let p = point(isAfternoon ? Self.innerR : Self.outerR, nowHour)
        let dot = Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
        ctx.fill(dot, with: .color(theme.nowFill))
        ctx.stroke(dot, with: .color(theme.nowStroke), lineWidth: 3)
    }

    private func handPath(width w: CGFloat, length l: CGFloat) -> Path {
        let tip = 242 - l, shoulder = tip + w * 1.3
        var p = Path()
        p.move(to: CGPoint(x: 198, y: tip))
        p.addLine(to: CGPoint(x: 198 + w / 2, y: shoulder))
        p.addLine(to: CGPoint(x: 198 + w / 2, y: 250))
        p.addQuadCurve(to: CGPoint(x: 198 - w / 2, y: 250), control: CGPoint(x: 198, y: 250 + w * 0.6))
        p.addLine(to: CGPoint(x: 198 - w / 2, y: shoulder))
        p.closeSubpath()
        return p
    }

    private func drawHand(_ ctx: GraphicsContext, degrees: Double, width w: CGFloat, length l: CGFloat) {
        var c = ctx
        c.translateBy(x: 198, y: 242)
        c.rotate(by: .degrees(degrees))
        c.translateBy(x: -198, y: -242)
        c.fill(handPath(width: w, length: l), with: .color(theme.hand))
        let lw = max(2, (w * 0.32).rounded())
        let lume = CGRect(x: 198 - lw / 2, y: 242 - l + w * 1.3 + 4, width: lw, height: (l * 0.62).rounded())
        c.fill(Path(roundedRect: lume, cornerRadius: 1.5), with: .color(theme.lume))
    }

    private func drawHands(_ ctx: GraphicsContext) {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let minute = Double(comps.minute ?? 0), second = Double(comps.second ?? 0)
        let hour = Double((comps.hour ?? 0) % 12) + minute / 60
        let (hw, hl, mw, ml): (CGFloat, CGFloat, CGFloat, CGFloat) = theme.slimHands ? (7, 90, 5, 142) : (19, 84, 15, 130)

        drawHand(ctx, degrees: hour * 30, width: hw, length: hl)
        drawHand(ctx, degrees: (minute + (showSeconds ? second / 60 : 0)) * 6, width: mw, length: ml)

        if showSeconds {
            var c = ctx
            c.translateBy(x: 198, y: 242)
            c.rotate(by: .degrees(second * 6))
            c.translateBy(x: -198, y: -242)
            var line = Path()
            line.move(to: CGPoint(x: 198, y: 274))
            line.addLine(to: CGPoint(x: 198, y: 96))
            c.stroke(line, with: .color(theme.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            c.fill(Path(ellipseIn: CGRect(x: 193.5, y: 259.5, width: 9, height: 9)), with: .color(theme.accent))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: 190.5, y: 234.5, width: 15, height: 15)), with: .color(theme.hand))
        ctx.fill(Path(ellipseIn: CGRect(x: 194.5, y: 238.5, width: 7, height: 7)), with: .color(theme.accent))
    }

    // MARK: Corners

    private func value(_ s: String) -> Text {
        Text(s).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(theme.text)
    }

    private func label(_ s: String) -> Text {
        Text(s).font(.system(size: 14, weight: .bold)).tracking(1).foregroundColor(theme.label)
    }

    private func ring(_ ctx: GraphicsContext, r: CGFloat, fraction: Double?, color: Color) {
        let c = CGPoint(x: 52, y: 46)
        let track = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        var t = ctx
        t.opacity = 0.25
        t.stroke(track, with: .color(color), lineWidth: 4.5)
        let f = min(max(fraction ?? 0, 0), 1)
        guard f > 0 else { return }
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * f), clockwise: false)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
    }

    private func ratio(_ v: Double?, _ goal: Double?) -> Double? {
        guard let v, let goal, goal > 0 else { return nil }
        return v / goal
    }

    private func drawCorners(_ ctx: GraphicsContext) {
        // Top left: activity rings.
        ring(ctx, r: 15, fraction: ratio(data.move, data.moveGoal), color: theme.ring1)
        ring(ctx, r: 10, fraction: ratio(data.exercise, data.exerciseGoal), color: theme.ring2)
        ring(ctx, r: 5, fraction: ratio(data.stand, data.standGoal), color: theme.ring3)
        ctx.draw(value(data.move.map { "\(Int($0))" } ?? "--"), at: CGPoint(x: 74, y: 46), anchor: .leading)
        ctx.draw(label("MOVE"), at: CGPoint(x: 36, y: 80), anchor: .leading)

        // Top right: battery.
        let body = CGRect(x: 330, y: 38, width: 28, height: 16)
        ctx.stroke(Path(roundedRect: body, cornerRadius: 4.5), with: .color(theme.label), lineWidth: 2)
        ctx.fill(Path(roundedRect: CGRect(x: 359.5, y: 43, width: 3, height: 6), cornerRadius: 1), with: .color(theme.label))
        let level = CGFloat(max(0, min(1, data.battery ?? 0)))
        if level > 0 {
            ctx.fill(Path(roundedRect: CGRect(x: 332.5, y: 40.5, width: 23 * level, height: 11), cornerRadius: 2.5),
                     with: .color(theme.battery))
        }
        ctx.draw(value(data.battery.map { "\(Int(($0 * 100).rounded()))%" } ?? "--"), at: CGPoint(x: 322, y: 46), anchor: .trailing)
        ctx.draw(label("BATTERY"), at: CGPoint(x: 360, y: 80), anchor: .trailing)

        // Bottom left: heart rate.
        ctx.draw(label("BPM"), at: CGPoint(x: 36, y: 404), anchor: .leading)
        let h = CGPoint(x: 47, y: 434), k: CGFloat = 1.3
        var heart = Path()
        heart.move(to: CGPoint(x: h.x - 7 * k, y: h.y - 1 * k))
        heart.addCurve(to: CGPoint(x: h.x, y: h.y - 5 * k), control1: CGPoint(x: h.x - 7 * k, y: h.y - 5.5 * k), control2: CGPoint(x: h.x - 3 * k, y: h.y - 8 * k))
        heart.addCurve(to: CGPoint(x: h.x + 7 * k, y: h.y - 1 * k), control1: CGPoint(x: h.x + 3 * k, y: h.y - 8 * k), control2: CGPoint(x: h.x + 7 * k, y: h.y - 5.5 * k))
        heart.addCurve(to: CGPoint(x: h.x, y: h.y + 8 * k), control1: CGPoint(x: h.x + 7 * k, y: h.y + 3.5 * k), control2: CGPoint(x: h.x, y: h.y + 8 * k))
        heart.addCurve(to: CGPoint(x: h.x - 7 * k, y: h.y - 1 * k), control1: CGPoint(x: h.x, y: h.y + 8 * k), control2: CGPoint(x: h.x - 7 * k, y: h.y + 3.5 * k))
        heart.closeSubpath()
        ctx.fill(heart, with: .color(theme.heart))
        ctx.draw(value(data.heartRate.map { "\($0)" } ?? "--"), at: CGPoint(x: 62, y: 434), anchor: .leading)

        // Bottom right: free time left today.
        ctx.draw(label("FREE TODAY"), at: CGPoint(x: 360, y: 404), anchor: .trailing)
        let cc = CGPoint(x: 350, y: 434)
        ctx.stroke(Path(ellipseIn: CGRect(x: cc.x - 9, y: cc.y - 9, width: 18, height: 18)), with: .color(theme.free), lineWidth: 2.2)
        var hands = Path()
        hands.move(to: CGPoint(x: cc.x, y: cc.y - 5.5))
        hands.addLine(to: cc)
        hands.addLine(to: CGPoint(x: cc.x + 4, y: cc.y + 2.5))
        ctx.stroke(hands, with: .color(theme.free), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        ctx.draw(value(Self.duration(data.freeToday)), at: CGPoint(x: 334, y: 434), anchor: .trailing)
    }

    static func duration(_ t: TimeInterval) -> String {
        let minutes = max(0, Int(t / 60))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
