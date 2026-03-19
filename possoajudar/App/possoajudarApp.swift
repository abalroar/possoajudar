import SwiftUI

@main
struct possoajudarApp: App {
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var claude = ClaudeService()
    @StateObject private var persistence = PersistenceService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKit)
                .environmentObject(claude)
                .environmentObject(persistence)
        }
    }
}
