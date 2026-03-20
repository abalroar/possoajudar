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
        .tint(AppColors.accent)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.surfacePrimary)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textTertiary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.textTertiary)
            ]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
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
