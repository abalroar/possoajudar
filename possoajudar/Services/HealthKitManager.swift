import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {

    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: String?

    // MARK: - HealthKit Types

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        // Tier 1 — critical
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        // Tier 2 — workout context
        types.insert(HKObjectType.workoutType())
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let vo2 = HKObjectType.quantityType(forIdentifier: .vo2Max) { types.insert(vo2) }
        if let cal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(cal) }
        // Tier 3 — complementary
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(weight) }
        if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(spo2) }
        if let rr = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { types.insert(rr) }
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "HealthKit não disponível neste dispositivo"
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            authorizationError = "Erro ao autorizar HealthKit: \(error.localizedDescription)"
        }
    }

    // MARK: - Full Snapshot

    func fetchHealthSnapshot() async -> HealthSnapshot {
        async let hrv = fetchLatestHRV()
        async let rhr = fetchLatestRestingHR()
        async let sleep = fetchLastNightSleep()
        async let vo2 = fetchLatestVO2Max()
        async let weight = fetchLatestWeight()
        async let workouts = fetchRecentWorkouts(days: 30)
        async let hrv7d = fetchHRV7dHistory()
        async let rhr7d = fetchRestingHR7dHistory()

        let (sleepHours, sleepQuality, sleepDeep) = await sleep

        return HealthSnapshot(
            hrv: await hrv,
            restingHR: await rhr,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            sleepDeepMin: sleepDeep,
            vo2max: await vo2,
            weight: await weight,
            recentWorkouts: await workouts,
            hrv7dHistory: await hrv7d,
            restingHR7dHistory: await rhr7d
        )
    }

    // MARK: - HRV

    func fetchLatestHRV() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
        return await fetchLatestQuantity(type: type, unit: HKUnit.secondUnit(with: .milli))
    }

    func fetchHRV7dHistory() async -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return [] }
        return await fetchDailyAverages(type: type, unit: HKUnit.secondUnit(with: .milli), days: 7)
    }

    // MARK: - Resting HR

    func fetchLatestRestingHR() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        return await fetchLatestQuantity(type: type, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    func fetchRestingHR7dHistory() async -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return [] }
        return await fetchDailyAverages(type: type, unit: HKUnit.count().unitDivided(by: .minute()), days: 7)
    }

    // MARK: - Sleep

    func fetchLastNightSleep() async -> (hours: Double?, quality: SleepQuality?, deepMin: Double?) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (nil, nil, nil)
        }
        let calendar = Calendar.current
        let now = Date()
        // Look at sleep from the past 18 hours (captures last night's sleep regardless of wake time)
        guard let start = calendar.date(byAdding: .hour, value: -18, to: now) else {
            return (nil, nil, nil)
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }

                var totalAsleepSeconds: Double = 0
                var deepSeconds: Double = 0

                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)

                    if #available(iOS 16.0, *) {
                        switch value {
                        case .asleepDeep:
                            deepSeconds += duration
                            totalAsleepSeconds += duration
                        case .asleepCore, .asleepREM, .asleepUnspecified:
                            totalAsleepSeconds += duration
                        default:
                            break
                        }
                    } else {
                        if value == .asleep {
                            totalAsleepSeconds += duration
                        }
                    }
                }

                let hours = totalAsleepSeconds / 3600
                let deepMin = deepSeconds / 60

                let quality: SleepQuality
                if hours >= 7 && deepMin >= 60 { quality = .good }
                else if hours >= 6 { quality = .fair }
                else { quality = .poor }

                continuation.resume(returning: (
                    hours > 0 ? hours : nil,
                    hours > 0 ? quality : nil,
                    deepMin > 0 ? deepMin : nil
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - VO2 Max

    func fetchLatestVO2Max() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return nil }
        // VO2 max is in mL/kg/min
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        return await fetchLatestQuantity(type: type, unit: unit)
    }

    // MARK: - Weight

    func fetchLatestWeight() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await fetchLatestQuantity(type: type, unit: .gramUnit(with: .kilo))
    }

    // MARK: - Workouts

    func fetchRecentWorkouts(days: Int) async -> [WorkoutEntry] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, _ in
                guard let self, let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                let entries = workouts.compactMap { self.workoutEntry(from: $0) }
                continuation.resume(returning: entries)
            }
            store.execute(query)
        }
    }

    private func workoutEntry(from workout: HKWorkout) -> WorkoutEntry? {
        let type = workoutType(from: workout.workoutActivityType)
        let durationMin = Int(workout.duration / 60)
        guard durationMin > 0 else { return nil }

        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        var avgHr: Double?
        var peakHr: Double?

        // Try to get HR statistics from workout
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            if let stats = workout.statistics(for: hrType) {
                avgHr = stats.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                peakHr = stats.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
        }

        let intensity: WorkoutIntensity
        if let avg = avgHr {
            if avg >= 165 { intensity = .high }
            else if avg >= 145 { intensity = .moderate }
            else { intensity = .low }
        } else {
            intensity = .moderate
        }

        return WorkoutEntry(
            date: workout.startDate,
            type: type,
            durationMin: durationMin,
            avgHr: avgHr,
            peakHr: peakHr,
            hrZones: hrZones(avgHr: avgHr, peakHr: peakHr),
            rpe: nil,
            caloriesEstimated: calories,
            notes: nil,
            intensity: intensity
        )
    }

    private func workoutType(from activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .cycling: return .outdoorCycling
        case .walking: return .walk
        case .elliptical: return .elliptical
        default: return .other
        }
    }

    /// Estimate HR zone distribution given avg and peak HR (FCmáx = 190)
    private func hrZones(avgHr: Double?, peakHr: Double?) -> HRZones? {
        guard let avg = avgHr else { return nil }
        let maxHR = 190.0
        // Approximate zone % based on avg HR relative to max
        let pctOfMax = avg / maxHR
        if pctOfMax >= 0.90 {
            return HRZones(z1Pct: 2, z2Pct: 5, z3Pct: 10, z4Pct: 30, z5Pct: 53)
        } else if pctOfMax >= 0.80 {
            return HRZones(z1Pct: 5, z2Pct: 10, z3Pct: 20, z4Pct: 55, z5Pct: 10)
        } else if pctOfMax >= 0.70 {
            return HRZones(z1Pct: 10, z2Pct: 20, z3Pct: 40, z4Pct: 25, z5Pct: 5)
        } else if pctOfMax >= 0.60 {
            return HRZones(z1Pct: 15, z2Pct: 50, z3Pct: 25, z4Pct: 8, z5Pct: 2)
        } else {
            return HRZones(z1Pct: 60, z2Pct: 30, z3Pct: 8, z4Pct: 2, z5Pct: 0)
        }
    }

    // MARK: - Generic Helpers

    private func fetchLatestQuantity(type: HKQuantityType, unit: HKUnit) async -> Double? {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1,
                                      sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchDailyAverages(type: HKQuantityType, unit: HKUnit, days: Int) async -> [Double] {
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: startDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }
                var values: [Double] = []
                results.enumerateStatistics(from: startDate, to: Date()) { stats, _ in
                    if let avg = stats.averageQuantity()?.doubleValue(for: unit) {
                        values.append(avg)
                    }
                }
                continuation.resume(returning: values.reversed()) // most recent first
            }
            store.execute(query)
        }
    }

    // MARK: - Build TrainerContext from snapshot

    func buildContext(from snapshot: HealthSnapshot,
                      timeOfDay: TimeOfDay,
                      workout: WorkoutData? = nil,
                      userMessage: String? = nil) -> TrainerContext {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())

        let trends = Trends(
            restingHr7d: snapshot.restingHR7dTrend,
            hrv7d: snapshot.hrv7dTrend,
            vo2maxTrend: .stable,  // VO2 max updates infrequently
            vo2maxLatest: snapshot.vo2max
        )

        return TrainerContext(
            date: dateStr,
            timeOfDay: timeOfDay,
            hrvMs: snapshot.hrv,
            restingHrBpm: snapshot.restingHR,
            sleepHours: snapshot.sleepHours,
            sleepQuality: snapshot.sleepQuality,
            sleepDeepMin: snapshot.sleepDeepMin,
            daysSinceLastWorkout: snapshot.daysSinceLastWorkout,
            consecutiveTrainingDays: snapshot.consecutiveTrainingDays,
            lastWorkoutIntensity: snapshot.lastWorkoutIntensity,
            workout: workout,
            weeklyLoad: snapshot.weeklyLoad,
            trends: trends,
            weightKg: snapshot.weight,
            userMessage: userMessage
        )
    }
}
