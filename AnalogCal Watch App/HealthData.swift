//  HealthData.swift
//  Reads the latest heart rate from Apple Health, plus the watch battery
//  level, for the corners of the face.

import Combine
import HealthKit
import SwiftUI
import WatchKit

final class HealthData: ObservableObject {
    @Published var heartRate: Int?
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
        if battery == nil { battery = 0.82 }
        #else
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let heartType = HKQuantityType(.heartRate)
        if !authorized {
            let types: Set<HKObjectType> = [heartType]
            do {
                try await store.requestAuthorization(toShare: [], read: types)
                authorized = true
            } catch {
                return
            }
        }
        heartRate = await latestHeartRate(heartType)
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
}
