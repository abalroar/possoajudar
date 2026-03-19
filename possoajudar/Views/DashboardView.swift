import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var persistence: PersistenceService

    @State private var snapshot: HealthSnapshot?
    @State private var localReadiness: ReadinessCalculator.Result?
    @State private var isLoadingHealth = false
    @State private var isLoadingClaude = false
    @State private var trainerResponse: TrainerResponse?
    @State private var showingResponse = false
    @State private var showingWorkoutLog = false
    @State private var errorMessage: String?
    @State private var showingNoAPIKey = false

    private var timeOfDay: TimeOfDay {
        TimeOfDay.fromHour(Calendar.current.component(.hour, from: Date()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Top section: readiness + date
                    headerSection

                    // Quick signals row
                    if let snap = snapshot {
                        signalsRow(snap: snap)
                    }

                    // Primary action buttons
                    primaryActions

                    // Latest trainer response preview
                    if let response = trainerResponse ?? persistence.latestResponse() {
                        latestResponsePreview(response: response)
                    }

                    // Error
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoadingHealth || isLoadingClaude {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showingResponse) {
                if let r = trainerResponse ?? persistence.latestResponse() {
                    NavigationStack {
                        TrainerResponseView(response: r)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("OK") { showingResponse = false }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showingWorkoutLog) {
                WorkoutLogView { response in
                    trainerResponse = response
                    showingResponse = true
                }
                .environmentObject(healthKit)
                .environmentObject(claude)
                .environmentObject(persistence)
            }
            .alert("Chave de API necessária", isPresented: $showingNoAPIKey) {
                Button("OK") {}
            } message: {
                Text("Configure sua chave Anthropic em Ajustes para obter análises do trainer.")
            }
            .task {
                await loadHealthData()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Date + greeting
            VStack(spacing: 2) {
                Text(greetingText)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // Readiness gauge
            if let r = localReadiness {
                ReadinessGaugeView(
                    score: r.score,
                    label: r.label,
                    colorName: r.color,
                    primarySignal: r.primarySignal,
                    size: 200
                )
            } else if isLoadingHealth {
                ProgressView("Lendo dados do Watch...")
                    .frame(height: 220)
            } else {
                // No data yet
                VStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Aguardando dados do Apple Watch")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 220)
            }
        }
    }

    // MARK: - Quick Signals Row

    private func signalsRow(snap: HealthSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let hrv = snap.hrv {
                    SignalChip(
                        icon: "waveform",
                        label: "HRV",
                        value: String(format: "%.0f ms", hrv),
                        color: hrv >= ReadinessCalculator.hrvBaseline ? .green : .orange
                    )
                }
                if let rhr = snap.restingHR {
                    SignalChip(
                        icon: "heart.fill",
                        label: "FC Repouso",
                        value: String(format: "%.0f bpm", rhr),
                        color: rhr <= ReadinessCalculator.hrBaseline ? .green : .orange
                    )
                }
                if let sleep = snap.sleepHours {
                    SignalChip(
                        icon: "moon.fill",
                        label: "Sono",
                        value: String(format: "%.1fh", sleep),
                        color: sleep >= 7 ? .green : (sleep >= 6 ? .yellow : .red)
                    )
                }
                if let vo2 = snap.vo2max {
                    SignalChip(
                        icon: "lungs.fill",
                        label: "VO₂ Máx",
                        value: String(format: "%.1f", vo2),
                        color: vo2 >= 40 ? .green : (vo2 >= 35 ? .yellow : .orange)
                    )
                }
                if snap.consecutiveTrainingDays > 0 {
                    SignalChip(
                        icon: "flame.fill",
                        label: "Sequência",
                        value: "\(snap.consecutiveTrainingDays)d",
                        color: snap.consecutiveTrainingDays >= 5 ? .orange : .blue
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Primary Actions

    private var primaryActions: some View {
        VStack(spacing: 12) {
            // Main CTA: Get trainer analysis
            Button(action: fetchTrainerAnalysis) {
                HStack {
                    if isLoadingClaude {
                        ProgressView().tint(.white)
                        Text("Consultando o trainer...")
                    } else {
                        Image(systemName: modeIcon)
                        Text(modeTitle)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoadingClaude || isLoadingHealth)
            .padding(.horizontal, 16)

            // Secondary: Log workout
            Button(action: { showingWorkoutLog = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Registrar Treino")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Latest Response Preview

    private func latestResponsePreview(response: TrainerResponse) -> some View {
        Button(action: { showingResponse = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Última análise", systemImage: "person.fill.checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text(response.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(response.trainerNote)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let zone = response.today.targetZone {
                        Tag(text: zone, color: .blue)
                    }
                    if let hr = response.today.targetAvgHr {
                        Tag(text: "\(hr) bpm", color: .red)
                    }
                    Tag(text: response.weeklyPicture.loadAssessment.capitalized, color: .secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Data Loading

    private func loadHealthData() async {
        isLoadingHealth = true
        errorMessage = nil

        if !healthKit.isAuthorized {
            await healthKit.requestAuthorization()
        }

        let snap = await healthKit.fetchHealthSnapshot()
        let readiness = ReadinessCalculator.calculate(
            hrv: snap.hrv,
            restingHR: snap.restingHR,
            sleepHours: snap.sleepHours,
            consecutiveDays: snap.consecutiveTrainingDays
        )

        snapshot = snap
        localReadiness = readiness
        isLoadingHealth = false
    }

    private func fetchTrainerAnalysis() {
        guard claude.hasAPIKey else {
            showingNoAPIKey = true
            return
        }

        isLoadingClaude = true
        errorMessage = nil

        Task {
            if snapshot == nil { await loadHealthData() }
            guard let snap = snapshot else {
                await MainActor.run {
                    errorMessage = "Não foi possível ler os dados de saúde."
                    isLoadingClaude = false
                }
                return
            }

            let context = await healthKit.buildContext(
                from: snap,
                timeOfDay: timeOfDay
            )

            do {
                let response = try await claude.fetchAnalysis(context: context)
                persistence.save(response: response)
                await MainActor.run {
                    trainerResponse = response
                    isLoadingClaude = false
                    showingResponse = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingClaude = false
                }
            }
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bom dia, Matheus"
        case 12..<18: return "Boa tarde, Matheus"
        default: return "Boa noite, Matheus"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: Date()).capitalized
    }

    private var modeTitle: String {
        switch timeOfDay {
        case .morning: return "Check-in Matinal"
        case .preWorkout: return "Pré-Treino"
        case .postWorkout: return "Analisar Pós-Treino"
        case .evening: return "Consultar Trainer"
        }
    }

    private var modeIcon: String {
        switch timeOfDay {
        case .morning: return "sun.horizon.fill"
        case .preWorkout: return "figure.run.circle.fill"
        case .postWorkout: return "checkmark.circle.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

// MARK: - Reusable Components

struct SignalChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(width: 72, height: 68)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
