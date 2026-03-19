import Foundation

/// Lightweight persistence for trainer responses and workout history using UserDefaults.
final class PersistenceService: ObservableObject {

    static let shared = PersistenceService()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let trainerResponses = "trainer_responses_v2"
        static let manualWorkouts = "manual_workouts_v1"
    }

    // MARK: - Trainer Responses

    @Published private(set) var responses: [TrainerResponse] = []

    init() {
        responses = loadResponses()
    }

    func save(response: TrainerResponse) {
        var current = loadResponses()
        current.insert(response, at: 0)
        // Keep last 90 responses
        if current.count > 90 { current = Array(current.prefix(90)) }
        encode(current, forKey: Keys.trainerResponses)
        responses = current
    }

    func latestResponse() -> TrainerResponse? {
        responses.first
    }

    func clearHistory() {
        defaults.removeObject(forKey: Keys.trainerResponses)
        responses = []
    }

    private func loadResponses() -> [TrainerResponse] {
        guard let data = defaults.data(forKey: Keys.trainerResponses),
              let decoded = try? JSONDecoder().decode([TrainerResponse].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Manual Workout Entries

    @Published private(set) var manualWorkouts: [WorkoutEntry] = []

    func saveManualWorkout(_ entry: WorkoutEntry) {
        var current = loadManualWorkouts()
        current.insert(entry, at: 0)
        if current.count > 200 { current = Array(current.prefix(200)) }
        encode(current, forKey: Keys.manualWorkouts)
        manualWorkouts = current
    }

    func loadManualWorkouts() -> [WorkoutEntry] {
        guard let data = defaults.data(forKey: Keys.manualWorkouts),
              let decoded = try? JSONDecoder().decode([WorkoutEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Helpers

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
