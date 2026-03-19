import Foundation

// MARK: - Enums

enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "morning"
    case preWorkout = "pre_workout"
    case postWorkout = "post_workout"
    case evening = "evening"

    var displayName: String {
        switch self {
        case .morning: return "Manhã"
        case .preWorkout: return "Pré-Treino"
        case .postWorkout: return "Pós-Treino"
        case .evening: return "Noite"
        }
    }

    static func fromHour(_ hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<10: return .morning
        case 10..<14: return .preWorkout
        case 14..<20: return .postWorkout
        default: return .evening
        }
    }
}

enum SleepQuality: String, Codable {
    case poor, fair, good

    var displayName: String {
        switch self {
        case .poor: return "Ruim"
        case .fair: return "Regular"
        case .good: return "Boa"
        }
    }
}

enum WorkoutIntensity: String, Codable {
    case high, moderate, low

    var displayName: String {
        switch self {
        case .high: return "Alta"
        case .moderate: return "Moderada"
        case .low: return "Baixa"
        }
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case indoorCycling = "indoor_cycling"
    case elliptical = "elliptical"
    case outdoorCycling = "outdoor_cycling"
    case walk = "walk"
    case mobility = "mobility"
    case rest = "rest"
    case other = "other"

    var displayName: String {
        switch self {
        case .indoorCycling: return "Spinning Indoor"
        case .elliptical: return "Elíptico"
        case .outdoorCycling: return "Ciclismo ao ar livre"
        case .walk: return "Caminhada"
        case .mobility: return "Mobilidade"
        case .rest: return "Descanso"
        case .other: return "Outro"
        }
    }
}

enum TrendDirection: String, Codable {
    case stable, rising, falling

    var symbol: String {
        switch self {
        case .stable: return "→"
        case .rising: return "↑"
        case .falling: return "↓"
        }
    }
}

// MARK: - Input Context (sent to Claude)

struct HRZones: Codable {
    var z1Pct: Int
    var z2Pct: Int
    var z3Pct: Int
    var z4Pct: Int
    var z5Pct: Int

    enum CodingKeys: String, CodingKey {
        case z1Pct = "z1_pct"
        case z2Pct = "z2_pct"
        case z3Pct = "z3_pct"
        case z4Pct = "z4_pct"
        case z5Pct = "z5_pct"
    }
}

struct WorkoutData: Codable {
    var type: WorkoutType
    var durationMin: Int
    var avgHr: Double?
    var peakHr: Double?
    var hrZones: HRZones?
    var rpe: Int?
    var caloriesEstimated: Double?
    var notes: String?
    var hasScreenshot: Bool

    enum CodingKeys: String, CodingKey {
        case type
        case durationMin = "duration_min"
        case avgHr = "avg_hr"
        case peakHr = "peak_hr"
        case hrZones = "hr_zones"
        case rpe
        case caloriesEstimated = "calories_estimated"
        case notes
        case hasScreenshot = "has_screenshot"
    }
}

struct WeeklyLoad: Codable {
    var sessionsThisWeek: Int
    var totalDurationMin: Int
    var avgIntensity: WorkoutIntensity
    var vsPrevWeek: String

    enum CodingKeys: String, CodingKey {
        case sessionsThisWeek = "sessions_this_week"
        case totalDurationMin = "total_duration_min"
        case avgIntensity = "avg_intensity"
        case vsPrevWeek = "vs_prev_week"
    }
}

struct Trends: Codable {
    var restingHr7d: TrendDirection
    var hrv7d: TrendDirection
    var vo2maxTrend: TrendDirection
    var vo2maxLatest: Double?

    enum CodingKeys: String, CodingKey {
        case restingHr7d = "resting_hr_7d"
        case hrv7d = "hrv_7d"
        case vo2maxTrend = "vo2max_trend"
        case vo2maxLatest = "vo2max_latest"
    }
}

struct TrainerContext: Codable {
    var date: String
    var timeOfDay: TimeOfDay
    var hrvMs: Double?
    var restingHrBpm: Double?
    var sleepHours: Double?
    var sleepQuality: SleepQuality?
    var sleepDeepMin: Double?
    var daysSinceLastWorkout: Int?
    var consecutiveTrainingDays: Int
    var lastWorkoutIntensity: WorkoutIntensity?
    var workout: WorkoutData?
    var weeklyLoad: WeeklyLoad
    var trends: Trends
    var weightKg: Double?
    var userMessage: String?

    enum CodingKeys: String, CodingKey {
        case date
        case timeOfDay = "time_of_day"
        case hrvMs = "hrv_ms"
        case restingHrBpm = "resting_hr_bpm"
        case sleepHours = "sleep_hours"
        case sleepQuality = "sleep_quality"
        case sleepDeepMin = "sleep_deep_min"
        case daysSinceLastWorkout = "days_since_last_workout"
        case consecutiveTrainingDays = "consecutive_training_days"
        case lastWorkoutIntensity = "last_workout_intensity"
        case workout
        case weeklyLoad = "weekly_load"
        case trends
        case weightKg = "weight_kg"
        case userMessage = "user_message"
    }

    func toJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - Trainer Response (from Claude)

struct ReadinessInfo: Codable {
    var score: Int
    var label: String
    var color: String
    var primarySignal: String

    enum CodingKeys: String, CodingKey {
        case score, label, color
        case primarySignal = "primary_signal"
    }

    var swiftUIColor: String {
        switch color.lowercased() {
        case "green": return "green"
        case "red": return "red"
        case "blue": return "blue"
        default: return "yellow"
        }
    }
}

struct TodayPlan: Codable {
    var recommendation: String
    var workoutType: String?
    var durationMin: Int?
    var targetZone: String?
    var targetAvgHr: Int?
    var structure: String?
    var rationale: String?

    enum CodingKeys: String, CodingKey {
        case recommendation
        case workoutType = "workout_type"
        case durationMin = "duration_min"
        case targetZone = "target_zone"
        case targetAvgHr = "target_avg_hr"
        case structure, rationale
    }
}

struct BodyReading: Codable {
    var recoveryStatus: String
    var fatigueSignals: [String]
    var positiveSignals: [String]

    enum CodingKeys: String, CodingKey {
        case recoveryStatus = "recovery_status"
        case fatigueSignals = "fatigue_signals"
        case positiveSignals = "positive_signals"
    }
}

struct PerformanceContext: Codable {
    var vsLastSession: String?
    var vsSamePeriodHist: String?
    var trendComment: String?

    enum CodingKeys: String, CodingKey {
        case vsLastSession = "vs_last_session"
        case vsSamePeriodHist = "vs_same_period_hist"
        case trendComment = "trend_comment"
    }
}

struct WatchSignals: Codable {
    var hrvInterpretation: String?
    var restingHrInterpretation: String?
    var vo2maxNote: String?

    enum CodingKeys: String, CodingKey {
        case hrvInterpretation = "hrv_interpretation"
        case restingHrInterpretation = "resting_hr_interpretation"
        case vo2maxNote = "vo2max_note"
    }
}

struct WeeklyPicture: Codable {
    var loadAssessment: String
    var nextKeySession: String?
    var restDayNeededBy: String?

    enum CodingKeys: String, CodingKey {
        case loadAssessment = "load_assessment"
        case nextKeySession = "next_key_session"
        case restDayNeededBy = "rest_day_needed_by"
    }
}

struct TrainerResponse: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var readiness: ReadinessInfo
    var today: TodayPlan
    var bodyReading: BodyReading
    var performanceContext: PerformanceContext
    var trainerNote: String
    var watchSignals: WatchSignals
    var weeklyPicture: WeeklyPicture
    var contextSnapshot: TrainerContext?

    enum CodingKeys: String, CodingKey {
        case id, timestamp
        case readiness, today
        case bodyReading = "body_reading"
        case performanceContext = "performance_context"
        case trainerNote = "trainer_note"
        case watchSignals = "watch_signals"
        case weeklyPicture = "weekly_picture"
        case contextSnapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        timestamp = (try? container.decode(Date.self, forKey: .timestamp)) ?? Date()
        readiness = try container.decode(ReadinessInfo.self, forKey: .readiness)
        today = try container.decode(TodayPlan.self, forKey: .today)
        bodyReading = try container.decode(BodyReading.self, forKey: .bodyReading)
        performanceContext = try container.decode(PerformanceContext.self, forKey: .performanceContext)
        trainerNote = try container.decode(String.self, forKey: .trainerNote)
        watchSignals = try container.decode(WatchSignals.self, forKey: .watchSignals)
        weeklyPicture = try container.decode(WeeklyPicture.self, forKey: .weeklyPicture)
        contextSnapshot = try? container.decodeIfPresent(TrainerContext.self, forKey: .contextSnapshot)
    }

    init(readiness: ReadinessInfo, today: TodayPlan, bodyReading: BodyReading,
         performanceContext: PerformanceContext, trainerNote: String,
         watchSignals: WatchSignals, weeklyPicture: WeeklyPicture,
         context: TrainerContext? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.readiness = readiness
        self.today = today
        self.bodyReading = bodyReading
        self.performanceContext = performanceContext
        self.trainerNote = trainerNote
        self.watchSignals = watchSignals
        self.weeklyPicture = weeklyPicture
        self.contextSnapshot = context
    }
}

// MARK: - App State

enum AppLoadingState {
    case idle
    case loading
    case success
    case failure(String)
}

// MARK: - Stored Workout Entry (for history)

struct WorkoutEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var type: WorkoutType
    var durationMin: Int
    var avgHr: Double?
    var peakHr: Double?
    var hrZones: HRZones?
    var rpe: Int?
    var caloriesEstimated: Double?
    var notes: String?
    var intensity: WorkoutIntensity

    var intensityFromHR: WorkoutIntensity {
        guard let avg = avgHr else { return .moderate }
        if avg >= 165 { return .high }
        if avg >= 145 { return .moderate }
        return .low
    }
}

// MARK: - HealthKit Snapshot (raw values from watch)

struct HealthSnapshot {
    var hrv: Double?
    var restingHR: Double?
    var sleepHours: Double?
    var sleepQuality: SleepQuality?
    var sleepDeepMin: Double?
    var vo2max: Double?
    var weight: Double?
    var recentWorkouts: [WorkoutEntry]
    var hrv7dHistory: [Double]
    var restingHR7dHistory: [Double]

    var consecutiveTrainingDays: Int {
        var count = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let hasWorkout = recentWorkouts.contains { calendar.isDate($0.date, inSameDayAs: day) }
            if hasWorkout { count += 1 } else { break }
        }
        return count
    }

    var daysSinceLastWorkout: Int? {
        guard let last = recentWorkouts.first else { return nil }
        return Calendar.current.dateComponents([.day], from: last.date, to: Date()).day
    }

    var lastWorkoutIntensity: WorkoutIntensity? {
        return recentWorkouts.first?.intensity
    }

    var hrv7dTrend: TrendDirection {
        guard hrv7dHistory.count >= 3 else { return .stable }
        let recent = Array(hrv7dHistory.prefix(3))
        let older = Array(hrv7dHistory.suffix(3))
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        let delta = (recentAvg - olderAvg) / max(olderAvg, 1)
        if delta > 0.05 { return .rising }
        if delta < -0.05 { return .falling }
        return .stable
    }

    var restingHR7dTrend: TrendDirection {
        guard restingHR7dHistory.count >= 3 else { return .stable }
        let recent = Array(restingHR7dHistory.prefix(3))
        let older = Array(restingHR7dHistory.suffix(3))
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        let delta = (recentAvg - olderAvg) / max(olderAvg, 1)
        if delta > 0.03 { return .rising }
        if delta < -0.03 { return .falling }
        return .stable
    }

    var weeklyLoad: WeeklyLoad {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let startOfPrevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) ?? now

        let thisWeekWorkouts = recentWorkouts.filter { $0.date >= startOfWeek }
        let prevWeekWorkouts = recentWorkouts.filter { $0.date >= startOfPrevWeek && $0.date < startOfWeek }

        let thisTotal = thisWeekWorkouts.reduce(0) { $0 + $1.durationMin }
        let prevTotal = prevWeekWorkouts.reduce(0) { $0 + $1.durationMin }

        let changePct: String
        if prevTotal == 0 {
            changePct = thisTotal > 0 ? "+100%" : "0%"
        } else {
            let pct = Int(Double(thisTotal - prevTotal) / Double(prevTotal) * 100)
            changePct = pct >= 0 ? "+\(pct)%" : "\(pct)%"
        }

        let avgIntensity: WorkoutIntensity
        let highCount = thisWeekWorkouts.filter { $0.intensity == .high }.count
        let lowCount = thisWeekWorkouts.filter { $0.intensity == .low }.count
        if highCount > thisWeekWorkouts.count / 2 {
            avgIntensity = .high
        } else if lowCount > thisWeekWorkouts.count / 2 {
            avgIntensity = .low
        } else {
            avgIntensity = .moderate
        }

        return WeeklyLoad(
            sessionsThisWeek: thisWeekWorkouts.count,
            totalDurationMin: thisTotal,
            avgIntensity: avgIntensity,
            vsPrevWeek: changePct
        )
    }
}
