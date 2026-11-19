//  RingsView.swift
//  An identical copy of this file lives in both the Watch App and DayRing folders.
//  If you change one, change the other.
//  The two-ring dial: AM events on the outer ring, PM events on the thinner
//  inner ring, rounded ends, past events dimmed, white dot at the current time.

import SwiftUI

nonisolated struct RingGeometry {
    let size: CGFloat
    let compact: Bool   // true inside the small complication

    var outerWidth: CGFloat { size * (compact ? 0.11 : 0.075) }
    var innerWidth: CGFloat { size * (compact ? 0.08 : 0.052) }
    var gap: CGFloat { size * (compact ? 0.025 : 0.02) }
    var outerRadius: CGFloat { size / 2 - outerWidth / 2 - 2 }
    var innerRadius: CGFloat { outerRadius - outerWidth / 2 - gap - innerWidth / 2 }
    /// Everything inside this radius is free for hands, ticks or text.
    var clearRadius: CGFloat { innerRadius - innerWidth / 2 }

    func radius(isPM: Bool) -> CGFloat { isPM ? innerRadius : outerRadius }
    func width(isPM: Bool) -> CGFloat { isPM ? innerWidth : outerWidth }

    /// Which segment (if any) is under a tap. `point` is in the dial's own
    /// coordinate space, where the dial is a size x size square.
    func segment(at point: CGPoint, in segments: [RingSegment]) -> RingSegment? {
        let dx = point.x - size / 2
        let dy = point.y - size / 2
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > clearRadius - 10 else { return nil }
        let isPM = abs(distance - innerRadius) < abs(distance - outerRadius)
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * CGFloat.pi }
        let hour = Double(angle / (2 * CGFloat.pi)) * 12
        return segments.last {
            $0.isPM == isPM && hour >= $0.startHour - 0.15 && hour <= $0.endHour + 0.15
        }
    }
}

struct RingsView: View {
    let segments: [RingSegment]
    let now: Date
    var compact = false

    var body: some View {
        GeometryReader { geo in
            let g = RingGeometry(size: min(geo.size.width, geo.size.height), compact: compact)
            ZStack {
                track(isPM: false, g)
                track(isPM: true, g)
                ForEach(segments) { arc($0, g) }
                nowDot(g)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var isAfternoon: Bool {
        Calendar.current.component(.hour, from: now) >= 12
    }

    private func track(isPM: Bool, _ g: RingGeometry) -> some View {
        Circle()
            .stroke(Color.white.opacity(isPM ? 0.08 : 0.12), lineWidth: g.width(isPM: isPM))
            .frame(width: g.radius(isPM: isPM) * 2, height: g.radius(isPM: isPM) * 2)
    }

    private func arc(_ segment: RingSegment, _ g: RingGeometry) -> some View {
        let radius = g.radius(isPM: segment.isPM)
        let width = g.width(isPM: segment.isPM)
        // Pull each end in by half the line width so the rounded caps
        // do not make the event look longer than it is.
        let cap = Double((width / 2) / (2 * CGFloat.pi * radius))
        let from = segment.startHour / 12 + cap
        let to = max(segment.endHour / 12 - cap, from + 0.001)
        return Circle()
            .trim(from: from, to: to)
            .stroke(segment.event.color, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
            .rotationEffect(.degrees(-90))
            .opacity(opacity(for: segment))
    }

    private func opacity(for segment: RingSegment) -> Double {
        if segment.segmentEnd <= now { return DialConfig.pastOpacity }
        let emphasized = DialConfig.swapEmphasisAfterNoon ? (segment.isPM == isAfternoon) : !segment.isPM
        return emphasized ? 1 : DialConfig.dullOpacity
    }

    private func nowDot(_ g: RingGeometry) -> some View {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = Double((parts.hour ?? 0) % 12) + Double(parts.minute ?? 0) / 60
        let angle = hour / 12 * 2 * Double.pi
        let radius = g.radius(isPM: isAfternoon)
        let diameter = g.width(isPM: isAfternoon) + (compact ? 1 : 3)
        return Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black, lineWidth: compact ? 1 : 2))
            .frame(width: diameter, height: diameter)
            .offset(x: radius * CGFloat(sin(angle)), y: -radius * CGFloat(cos(angle)))
    }
}

#Preview {
    RingsView(segments: RingSegment.make(from: SampleData.events(on: Date()), day: Date()), now: Date())
        .padding()
}
