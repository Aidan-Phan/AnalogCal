//  ContentView.swift
//  Watch App only. The full-screen v5 face (Amethyst or Chalk), with the next
//  event labelled on its arc. Turn the Digital Crown to move the label from
//  event to event (it returns to "now" after a few seconds). Tap an arc for
//  its details; long-press the dial to switch between the two looks.

import EventKit
import SwiftUI
import WatchKit
import WidgetKit

struct ContentView: View {
    @State private var events: [DayEvent] = []
    @State private var authorized = CalendarStore.hasAccess
    @State private var path: [DayEvent] = []
    /// Digital Crown position: each whole step moves the highlight one event.
    @State private var crown: Double = 0
    @State private var crownMoves = 0
    @StateObject private var health = HealthData()
    @AppStorage("faceTheme") private var themeID = FaceTheme.amethyst.id
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var dimmed

    private var theme: FaceTheme { FaceTheme.named(themeID) }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if authorized {
                    face
                } else {
                    VStack(spacing: 8) {
                        Text("Calendar access is off")
                            .font(.headline)
                        Text("Allow it in Settings > Privacy & Security > Calendars on your watch.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationDestination(for: DayEvent.self) { EventDetailView(event: $0) }
        }
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task { await load() }
        }
    }

    private func load() async {
        if !authorized { authorized = await CalendarStore.requestAccess() }
        events = CalendarStore.events()
        WidgetCenter.shared.reloadAllTimelines()   // keep the complication in step
        await health.refresh()
    }

    // MARK: Face

    private var face: some View {
        TimelineView(.periodic(from: .now, by: dimmed ? 60 : 1)) { context in
            let now = context.date
            let segments = RingSegment.make(from: events, day: now)
            let base = events.firstIndex { $0.end > now } ?? events.count
            let picked = base + Int(crown.rounded())
            let lower = -Double(base)
            let upper = Double(max(events.count - 1 - base, 0))
            GeometryReader { geo in
                FaceView(
                    theme: dimmed ? theme.lowPower() : theme,
                    now: now,
                    segments: segments,
                    next: events.indices.contains(picked) ? events[picked] : nil,
                    calendars: calendarOrder,
                    data: FaceSnapshot(
                        heartRate: health.heartRate,
                        battery: health.battery,
                        freeToday: freeTime(after: now)),
                    showSeconds: !dimmed,
                    lowPower: dimmed)
                .contentShape(Rectangle())
                .onTapGesture { point in
                    if let hit = hitTest(point, in: geo.size, segments: segments) { path.append(hit) }
                }
                .onLongPressGesture(minimumDuration: 0.6) {
                    themeID = theme.next.id
                    WKInterfaceDevice.current().play(.click)
                }
            }
            .focusable()
            .digitalCrownRotation(
                $crown, from: lower, through: upper > lower ? upper : lower + 1, by: 1,
                sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crown) { _, _ in returnToNowSoon() }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    /// After a few seconds without turning, the highlight goes back to the next event.
    private func returnToNowSoon() {
        crownMoves += 1
        let move = crownMoves
        Task {
            try? await Task.sleep(for: .seconds(4))
            if move == crownMoves, crown != 0 {
                withAnimation { crown = 0 }
            }
        }
    }

    /// Calendars get theme colours in the order they first appear today.
    private var calendarOrder: [String] {
        var names: [String] = []
        for e in events where !names.contains(e.calendarName) { names.append(e.calendarName) }
        return names
    }

    /// Unscheduled time from now until midnight.
    private func freeTime(after now: Date) -> TimeInterval {
        let end = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)
        var busy: TimeInterval = 0
        var cursor = now
        for e in events.sorted(by: { $0.start < $1.start }) {
            let s = max(e.start, cursor), f = min(e.end, end)
            if f > s { busy += f.timeIntervalSince(s); cursor = f }
        }
        return max(0, end.timeIntervalSince(now) - busy)
    }

    /// Maps a tap on screen back into the face's design space and finds the arc under it.
    private func hitTest(_ point: CGPoint, in size: CGSize, segments: [RingSegment]) -> DayEvent? {
        let s = min(size.width / FaceView.width, size.height / FaceView.height)
        let x = (point.x - (size.width - FaceView.width * s) / 2) / s
        let y = (point.y - (size.height - FaceView.height * s) / 2) / s
        let dx = (x - FaceView.center.x) / FaceView.dialScale
        let dy = (y - FaceView.center.y) / FaceView.dialScale
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 140, distance < 200 else { return nil }
        let isPM = abs(distance - FaceView.innerR) < abs(distance - FaceView.outerR)
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let hour = Double(angle / (2 * .pi)) * 12
        return segments.last {
            $0.isPM == isPM && hour >= $0.startHour - 0.15 && hour <= $0.endHour + 0.15
        }?.event
    }
}

// MARK: - Detail

struct EventDetailView: View {
    let event: DayEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Capsule().fill(event.color).frame(width: 4, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).font(.headline)
                        Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse").font(.footnote)
                }
                if !event.calendarName.isEmpty {
                    Label(event.calendarName, systemImage: "calendar").font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }
}

#Preview {
    ContentView()
}
