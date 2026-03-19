import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var persistence: PersistenceService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Hoje", systemImage: "house.fill")
                }
                .tag(0)

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.fill")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label("Histórico", systemImage: "clock.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.blue)
        .task {
            if !healthKit.isAuthorized {
                await healthKit.requestAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(ClaudeService())
        .environmentObject(PersistenceService.shared)
}
