//  DayRing.swift
//  Widget Extension only. Two complications, both in the Amethyst palette:
//  - Day Ring (circular): today's events around a 12-hour dial.
//  - Up Next (rectangular): the next event's name, time and a countdown.
//  DayRingBundle.swift is the entry point.

import SwiftUI
import WidgetKit

// MARK: - Palette

enum WidgetPalette {
    static let events: [Color] = [
        Color(red: 0x99 / 255, green: 0x9F / 255, blue: 1),          // #999FFF
        Color(red: 0xE9 / 255, green: 0xC4 / 255, blue: 0x6A / 255), // gold
        Color(red: 0xD3 / 255, green: 0xB4 / 255, blue: 1),          // lilac
        Color(red: 0xF2 / 255, green: 0x9E / 255, blue: 0x5B / 255), // amber
        Color(red: 0x6B / 255, green: 0x74 / 255, blue: 0xF5 / 255), // indigo
    ]

    /// Re-colours events by calendar, in the order calendars first appear,
    /// so the complications match the app's Amethyst face.
    static func themed(_ events: [DayEvent]) -> [DayEvent] {
        var order: [String] = []
        for e in events where !order.contains(e.calendarName) { order.append(e.calendarName) }
        return events.map { e in
            let i = order.firstIndex(of: e.calendarName) ?? 0
            return DayEvent(id: e.id, title: e.title, start: e.start, end: e.end,
                            location: e.location, calendarName: e.calendarName,
                            color: Self.events[i % Self.events.count])
        }
    }
}

// MARK: - Timeline

struct DayEntry: TimelineEntry {
    let date: Date
    /// Today's events, for the ring.
    let events: [DayEvent]
    /// Today's and tomorrow's events, for Up Next.
    var upcoming: [DayEvent] = []

    /// The event Up Next shows: the one happening now, or the next one.
    var next: DayEvent? { upcoming.first { $0.end > date } }
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        let sample = WidgetPalette.themed(SampleData.events(on: Date()))
        return DayEntry(date: Date(), events: sample, upcoming: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let (today, upcoming) = load(Date())
        completion(DayEntry(date: Date(), events: today, upcoming: upcoming))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let (today, upcoming) = load(now)
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)

        // Pre-built entries cost nothing from the refresh budget. One a minute
        // for the next two hours keeps the countdown exact; after that, one
        // every 10 minutes, plus one at every event start and end.
        var dates: Set<Date> = [now]
        let minute = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 60).rounded(.up) * 60)
        for i in 0..<120 { dates.insert(minute.addingTimeInterval(Double(i) * 60)) }
        var t = minute.addingTimeInterval(7200)
        while t < midnight {
            dates.insert(t)
            t = t.addingTimeInterval(600)
        }
        for e in upcoming where e.start > now && e.start < midnight { dates.insert(e.start) }
        for e in upcoming where e.end > now && e.end < midnight { dates.insert(e.end) }

        let entries = dates.filter { $0 >= now && $0 <= midnight }.sorted()
            .map { DayEntry(date: $0, events: today, upcoming: upcoming) }

        // Ask for a fresh read of the calendar about once an hour.
        completion(Timeline(entries: entries, policy: .after(min(midnight, now.addingTimeInterval(3600)))))
    }

    private func load(_ now: Date) -> ([DayEvent], [DayEvent]) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let today = CalendarStore.events(on: now)
        let both = WidgetPalette.themed(today + CalendarStore.events(on: tomorrow))
        let todayIDs = Set(today.map(\.id))
        return (both.filter { todayIDs.contains($0.id) }, both)
    }
}

// MARK: - Day Ring (circular)

struct DayRingWidgetView: View {
    let entry: DayEntry

    var body: some View {
        ZStack {
            RingsView(
                segments: RingSegment.make(from: entry.events, day: entry.date),
                now: entry.date,
                compact: true)
                .widgetAccentable()
            if let next = entry.events.first(where: { $0.start > entry.date }) {
                Text(next.start, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct DayRing: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayRing", provider: DayProvider()) { entry in
            DayRingWidgetView(entry: entry)
        }
        .configurationDisplayName("Day Ring")
        .description("Today's events around a 12-hour dial.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Up Next (rectangular)

struct UpNextWidgetView: View {
    let entry: DayEntry

    var body: some View {
        Group {
            if let e = entry.next {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(e.color)
                        .frame(width: 4)
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(status(e))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(e.color)
                            .widgetAccentable()
                            .lineLimit(1)
                        Text(e.title)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text(detail(e))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("UP NEXT")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Nothing else today")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private func status(_ e: DayEvent) -> String {
        let now = entry.date
        if e.start <= now { return "NOW" }
        if !Calendar.current.isDate(e.start, inSameDayAs: now) { return "TOMORROW" }
        let minutes = max(1, Int((e.start.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "IN \(minutes) MIN" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "IN \(h) HR" : "IN \(h) HR \(m) MIN"
    }

    private func detail(_ e: DayEvent) -> String {
        let range = "\(e.start.formatted(date: .omitted, time: .shortened)) – \(e.end.formatted(date: .omitted, time: .shortened))"
        if let place = e.location, !place.isEmpty { return "\(range) · \(place)" }
        return range
    }
}

struct UpNext: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpNext", provider: DayProvider()) { entry in
            UpNextWidgetView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("Your next event with a countdown.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryCircular) {
    DayRing()
} timeline: {
    DayEntry(date: Date(), events: WidgetPalette.themed(SampleData.events(on: Date())))
}

#Preview(as: .accessoryRectangular) {
    UpNext()
} timeline: {
    let sample = WidgetPalette.themed(SampleData.events(on: Date()))
    DayEntry(date: Date(), events: sample, upcoming: sample)
}
