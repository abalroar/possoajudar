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
                VStack(spacing: AppSpacing.sectionGap) {
                    heroSection
                    signalsSection
                    primaryActions
                    latestResponseSection

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(AppColors.fatigued)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.screenMargin)
                    }
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.surfacePrimary)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoadingHealth || isLoadingClaude {
                        ProgressView().tint(AppColors.accent)
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

    // MARK: - Hero Section (gradient background + gauge)

    private var heroSection: some View {
        ZStack(alignment: .top) {
            // Gradient background
            AppGradients.heroBackground
                .frame(height: 340)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: AppSpacing.xs) {
                VStack(spacing: AppSpacing.xxs) {
                    Text(greetingText)
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.md)

                if let r = localReadiness {
                    ReadinessGaugeView(
                        score: r.score,
                        label: r.label,
                        colorName: r.color,
                        primarySignal: r.primarySignal,
                        size: 200
                    )
                } else if isLoadingHealth {
                    VStack(spacing: AppSpacing.sm) {
                        ProgressView()
                            .tint(AppColors.accent)
                            .scaleEffect(1.2)
                        Text("Lendo dados do Watch...")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(height: 230)
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "applewatch")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.textTertiary)
                        Text("Aguardando dados do Apple Watch")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(height: 230)
                }
            }
        }
    }

    // MARK: - Signal Chips

    private var signalsSection: some View {
        Group {
            if let snap = snapshot {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.componentGap) {
                        if let hrv = snap.hrv {
                            SignalChip(
                                icon: "waveform",
                                label: "HRV",
                                value: String(format: "%.0f ms", hrv),
                                color: hrv >= ReadinessCalculator.hrvBaseline ? AppColors.ready : AppColors.recovering
                            )
                        }
                        if let rhr = snap.restingHR {
                            SignalChip(
                                icon: "heart.fill",
                                label: "FC Repouso",
                                value: String(format: "%.0f bpm", rhr),
                                color: rhr <= ReadinessCalculator.hrBaseline ? AppColors.ready : AppColors.recovering
                            )
                        }
                        if let sleep = snap.sleepHours {
                            SignalChip(
                                icon: "moon.fill",
                                label: "Sono",
                                value: String(format: "%.1fh", sleep),
                                color: sleep >= 7 ? AppColors.ready : (sleep >= 6 ? AppColors.recovering : AppColors.fatigued)
                            )
                        }
                        if let vo2 = snap.vo2max {
                            SignalChip(
                                icon: "lungs.fill",
                                label: "VO\u{2082} Máx",
                                value: String(format: "%.1f", vo2),
                                color: vo2 >= 40 ? AppColors.ready : (vo2 >= 35 ? AppColors.recovering : AppColors.fatigued)
                            )
                        }
                        if snap.consecutiveTrainingDays > 0 {
                            SignalChip(
                                icon: "flame.fill",
                                label: "Sequência",
                                value: "\(snap.consecutiveTrainingDays)d",
                                color: snap.consecutiveTrainingDays >= 5 ? AppColors.recovering : AppColors.inForm
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                }
            }
        }
    }

    // MARK: - CTA Buttons

    private var primaryActions: some View {
        VStack(spacing: AppSpacing.componentGap) {
            Button(action: fetchTrainerAnalysis) {
                HStack(spacing: AppSpacing.xs) {
                    if isLoadingClaude {
                        ProgressView().tint(.white)
                        Text("Consultando o trainer...")
                    } else {
                        Image(systemName: modeIcon)
                        Text(modeTitle)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppGradients.ctaButton)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(isLoadingClaude || isLoadingHealth)

            Button(action: { showingWorkoutLog = true }) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "plus.circle")
                    Text("Registrar Treino")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, AppSpacing.screenMargin)
    }

    // MARK: - Latest Response Preview

    @ViewBuilder
    private var latestResponseSection: some View {
        if let response = trainerResponse ?? persistence.latestResponse() {
            Button(action: { showingResponse = true }) {
                VStack(alignment: .leading, spacing: AppSpacing.componentGap) {
                    HStack {
                        Label("Última análise", systemImage: "person.fill.checkmark")
                            .sectionHeader()
                        Spacer()
                        Text(response.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Text(response.trainerNote)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)

                    HStack(spacing: AppSpacing.xs) {
                        if let zone = response.today.targetZone {
                            Tag(text: zone, color: AppColors.accent)
                        }
                        if let hr = response.today.targetAvgHr {
                            Tag(text: "\(hr) bpm", color: AppColors.fatigued)
                        }
                        Tag(text: response.weeklyPicture.loadAssessment.capitalized, color: AppColors.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .cardStyle(elevation: .standard)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.screenMargin)
        }
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
                errorMessage = "Não foi possível ler os dados de saúde."
                isLoadingClaude = false
                return
            }
            let context = await healthKit.buildContext(from: snap, timeOfDay: timeOfDay)
            do {
                let response = try await claude.fetchAnalysis(context: context)
                persistence.save(response: response)
                trainerResponse = response
                isLoadingClaude = false
                showingResponse = true
            } catch {
                errorMessage = error.localizedDescription
                isLoadingClaude = false
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

// MARK: - Signal Chip

struct SignalChip: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(width: 88, height: 80)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Tag

struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
