//  Reminders.swift
//  Haptic reminders a set number of minutes before each event, as local
//  notifications. Rescheduled whenever the app opens or the calendar changes,
//  covering today and tomorrow.

import Foundation
import UserNotifications

nonisolated enum Reminders {
    static let prefix = "analogcal.reminder."
    static let choices = [0, 5, 10, 15, 30]

    static func reschedule(minutes: Int) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard minutes > 0 else { return }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let events = CalendarStore.events(on: now) + CalendarStore.events(on: tomorrow)
        let lead = TimeInterval(minutes * 60)

        // watchOS keeps at most 64 pending notifications per app.
        for event in events.filter({ $0.start.addingTimeInterval(-lead) > now }).prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = event.title
            var body = "In \(minutes) min · \(event.start.formatted(date: .omitted, time: .shortened))"
            if let place = event.location, !place.isEmpty { body += " · \(place)" }
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: event.start.addingTimeInterval(-lead).timeIntervalSince(now), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + event.id, content: content, trigger: trigger))
        }
    }
}

/// Shows reminders even while AnalogCal is the app on screen; by default
/// watchOS hides notifications from the app you are looking at.
nonisolated final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
