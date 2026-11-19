//  DayModel.swift
//  An identical copy of this file lives in both the Watch App and DayRing folders.
//  If you change one, change the other.
//  Data layer: reads today's events from the watch's calendar database
//  (which already contains your Google calendars once they sync to iPhone).

import EventKit
import SwiftUI

// MARK: - Tunables

nonisolated enum DialConfig {
    /// true  = whichever half of the day you are in is bright, the other is dull.
    /// false = AM is always bright, PM is always dull.
    static let swapEmphasisAfterNoon = true
    static let dullOpacity = 0.45
    static let pastOpacity = 0.3
}

// MARK: - Model

nonisolated struct DayEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let calendarName: String
    let color: Color
}

/// One arc on the dial. An event that crosses noon becomes two segments.
nonisolated struct RingSegment: Identifiable {
    let id: String
    let event: DayEvent
    let isPM: Bool
    let startHour: Double   // 0..<12, position on the dial
    let endHour: Double     // 0...12
    let segmentEnd: Date

    static func make(from events: [DayEvent], day: Date) -> [RingSegment] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let noon = dayStart.addingTimeInterval(12 * 3600)
        let dayEnd = dayStart.addingTimeInterval(24 * 3600)
        var result: [RingSegment] = []

        for event in events {
            let amStart = max(event.start, dayStart), amEnd = min(event.end, noon)
            if amEnd > amStart {
                result.append(RingSegment(
                    id: event.id + "-am", event: event, isPM: false,
                    startHour: amStart.timeIntervalSince(dayStart) / 3600,
                    endHour: amEnd.timeIntervalSince(dayStart) / 3600,
                    segmentEnd: amEnd))
            }
            let pmStart = max(event.start, noon), pmEnd = min(event.end, dayEnd)
            if pmEnd > pmStart {
                result.append(RingSegment(
                    id: event.id + "-pm", event: event, isPM: true,
                    startHour: pmStart.timeIntervalSince(noon) / 3600,
                    endHour: pmEnd.timeIntervalSince(noon) / 3600,
                    segmentEnd: pmEnd))
            }
        }
        // Longest first, so short overlapping events are drawn on top.
        return result.sorted { ($0.endHour - $0.startHour) > ($1.endHour - $1.startHour) }
    }
}

// MARK: - Calendar access

nonisolated enum CalendarStore {
    static let store = EKEventStore()

    static var hasAccess: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        #endif
    }

    static func requestAccess() async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return (try? await store.requestFullAccessToEvents()) ?? false
        #endif
    }

    /// Timed (not all-day) events for the given day, earliest first.
    static func events(on day: Date = Date()) -> [DayEvent] {
        #if targetEnvironment(simulator)
        return SampleData.events(on: day)
        #else
        guard hasAccess else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = start.addingTimeInterval(24 * 3600)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .map { ev in
                DayEvent(
                    id: "\(ev.eventIdentifier ?? UUID().uuidString)-\(ev.startDate.timeIntervalSince1970)",
                    title: ev.title ?? "Untitled",
                    start: ev.startDate,
                    end: ev.endDate,
                    location: ev.location,
                    calendarName: ev.calendar?.title ?? "",
                    color: ev.calendar.map { Color(cgColor: $0.cgColor) } ?? .blue)
            }
            .sorted { $0.start < $1.start }
        #endif
    }
}

// MARK: - Sample data (simulator, previews, complication gallery)

nonisolated enum SampleData {
    static func events(on day: Date) -> [DayEvent] {
        let dayStart = Calendar.current.startOfDay(for: day)
        func make(_ title: String, _ from: Double, _ to: Double, _ color: Color) -> DayEvent {
            DayEvent(id: title, title: title,
                     start: dayStart.addingTimeInterval(from * 3600),
                     end: dayStart.addingTimeInterval(to * 3600),
                     location: nil, calendarName: "Sample", color: color)
        }
        return [
            make("Lecture", 8.5, 9.5, .blue),
            make("Section", 10, 11.5, .blue),
            make("Lunch", 12.5, 13.25, .orange),
            make("Study group", 14, 15.5, .purple),
            make("Gym", 17, 18, .green),
            make("Dinner", 19, 20, .pink),
        ]
    }
}
