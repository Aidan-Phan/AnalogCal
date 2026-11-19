//  HealthData.swift
//  Reads the latest heart rate and today's activity rings from Apple Health,
//  plus the watch battery level, for the corners of the face.

import Combine
import HealthKit
import SwiftUI
import WatchKit

final class HealthData: ObservableObject {
    @Published var heartRate: Int?
    @Published var move: Double?
    @Published var moveGoal: Double?
    @Published var exercise: Double?
    @Published var exerciseGoal: Double?
    @Published var stand: Double?
    @Published var standGoal: Double?
    @Published var battery: Float?

    private let store = HKHealthStore()
    private var authorized = false

    @MainActor
    func refresh() async {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        battery = device.batteryLevel >= 0 ? device.batteryLevel : nil

        #if targetEnvironment(simulator)
        heartRate = 72
        move = 420; moveGoal = 600
        exercise = 14; exerciseGoal = 30
        stand = 8; standGoal = 12
        if battery == nil { battery = 0.82 }
        #else
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let heartType = HKQuantityType(.heartRate)
        if !authorized {
            let types: Set<HKObjectType> = [heartType, HKObjectType.activitySummaryType()]
            do {
                try await store.requestAuthorization(toShare: [], read: types)
                authorized = true
            } catch {
                return
            }
        }
        heartRate = await latestHeartRate(heartType)
        if let summary = await todaySummary() {
            move = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
            moveGoal = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
            exercise = summary.appleExerciseTime.doubleValue(for: .minute())
            exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: .minute())
            stand = summary.appleStandHours.doubleValue(for: .count())
            standGoal = summary.appleStandHoursGoal.doubleValue(for: .count())
        }
        #endif
    }

    private func latestHeartRate(_ type: HKQuantityType) async -> Int? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { @Sendable _, samples, _ in
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: bpm.map { Int($0.rounded()) })
            }
            store.execute(query)
        }
    }

    private func todaySummary() async -> HKActivitySummary? {
        await withCheckedContinuation { continuation in
            var day = Calendar.current.dateComponents([.era, .year, .month, .day], from: Date())
            day.calendar = Calendar.current
            let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: day, end: day)
            let query = HKActivitySummaryQuery(predicate: predicate) { @Sendable _, summaries, _ in
                continuation.resume(returning: summaries?.first)
            }
            store.execute(query)
        }
    }
}
