//
//  AnalogCalApp.swift
//  AnalogCal Watch App
//
//  Created by Aidan Phan on 2026-11-12.
//

import SwiftUI
import UserNotifications

@main
struct AnalogCal_Watch_AppApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
