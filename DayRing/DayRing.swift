//  DayRing.swift
//  Target membership: Widget Extension only.
//  The circular complication. DayRingBundle.swift is the entry point.

import SwiftUI
import WidgetKit

struct DayEntry: TimelineEntry {
    let date: Date
    let events: [DayEvent]
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), events: SampleData.events(on: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        let events = context.isPreview ? SampleData.events(on: Date()) : CalendarStore.events()
        completion(DayEntry(date: Date(), events: events))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let events = CalendarStore.events(on: now)
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)

        // Pre-build one entry every 10 minutes for the rest of the day. These
        // cost nothing from the refresh budget, and they move the "now" dot
        // and dim finished events on their own.
        var dates = [now]
        var next = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 600).rounded(.up) * 600)
        while next < midnight {
            if next > now { dates.append(next) }
            next = next.addingTimeInterval(600)
        }
        let entries = dates.map { DayEntry(date: $0, events: events) }

        // Ask for a fresh read of the calendar about once an hour.
        completion(Timeline(entries: entries, policy: .after(min(midnight, now.addingTimeInterval(3600)))))
    }
}

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

#Preview(as: .accessoryCircular) {
    DayRing()
} timeline: {
    DayEntry(date: Date(), events: SampleData.events(on: Date()))
}
