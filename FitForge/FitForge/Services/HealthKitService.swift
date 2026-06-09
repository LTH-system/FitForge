import Foundation
import HealthKit

struct HealthKitDailySummary: Identifiable, Hashable {
    var id = UUID()
    var lifeDayStart: Date
    var stepCount: Int
    var activeKcal: Int
    var basalKcal: Int
}

@MainActor
final class HealthKitService: ObservableObject {
    @Published var authorizationStatusText = "未連携"
    @Published var latestStepCount: Double = 0
    @Published var latestActiveEnergyKcal: Double = 0
    @Published var latestBasalEnergyKcal: Double = 0
    @Published var latestBodyMassKg: Double?
    @Published var recentDailySummaries: [HealthKitDailySummary] = []

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization(preferences: UserPreferences = .japaneseDefault) async {
        guard isAvailable else {
            authorizationStatusText = "この端末では利用不可"
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatusText = "連携済み"
            await refreshTodaySummary(preferences: preferences)
        } catch {
            authorizationStatusText = "連携エラー"
        }
    }

    func refreshTodaySummary(preferences: UserPreferences = .japaneseDefault) async {
        async let steps = todaySum(for: HKQuantityType(.stepCount), unit: .count(), preferences: preferences)
        async let active = todaySum(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), preferences: preferences)
        async let basal = todaySum(for: HKQuantityType(.basalEnergyBurned), unit: .kilocalorie(), preferences: preferences)
        async let bodyMass = latestQuantity(for: HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo))

        latestStepCount = await steps
        latestActiveEnergyKcal = await active
        latestBasalEnergyKcal = await basal
        latestBodyMassKg = await bodyMass
    }

    func refreshDailySummaries(days: Int, preferences: UserPreferences = .japaneseDefault) async {
        var summaries: [HealthKitDailySummary] = []
        let calendar = Calendar.current
        let todayStart = LifeDayService.startOfLifeDay(containing: .now, preferences: preferences)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .day, value: -offset, to: todayStart),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                continue
            }

            async let steps = sum(for: HKQuantityType(.stepCount), unit: .count(), start: start, end: end)
            async let active = sum(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), start: start, end: end)
            async let basal = sum(for: HKQuantityType(.basalEnergyBurned), unit: .kilocalorie(), start: start, end: end)

            summaries.append(HealthKitDailySummary(
                lifeDayStart: start,
                stepCount: Int(await steps),
                activeKcal: Int(await active),
                basalKcal: Int(await basal)
            ))
        }

        recentDailySummaries = summaries
    }

    private func todaySum(for type: HKQuantityType, unit: HKUnit, preferences: UserPreferences) async -> Double {
        let start = LifeDayService.startOfLifeDay(containing: .now, preferences: preferences)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func sum(for type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func latestQuantity(for type: HKQuantityType, unit: HKUnit) async -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
