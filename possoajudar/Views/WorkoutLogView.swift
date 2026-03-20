import SwiftUI

struct WorkoutLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var persistence: PersistenceService

    var onComplete: ((TrainerResponse) -> Void)?

    @State private var workoutType: WorkoutType = .indoorCycling
    @State private var durationMin: Int = 45
    @State private var avgHR: String = ""
    @State private var peakHR: String = ""
    @State private var rpe: Int = 7
    @State private var notes: String = ""
    @State private var isLoading = false
    @State private var error: String?

    private let workoutOptions: [(WorkoutType, String, String)] = [
        (.indoorCycling, "bicycle", "Spinning"),
        (.elliptical, "figure.elliptical", "Elíptico"),
        (.outdoorCycling, "bicycle.circle", "Outdoor"),
        (.walk, "figure.walk", "Caminhada"),
        (.mobility, "figure.flexibility", "Mobilidade"),
        (.other, "figure.mixed.cardio", "Outro"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {

                        // Workout type selector
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Tipo de Treino").sectionHeader()
                                .padding(.horizontal, AppSpacing.screenMargin)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(workoutOptions, id: \.0) { (type, icon, label) in
                                        WorkoutTypeChip(
                                            icon: icon,
                                            label: label,
                                            isSelected: workoutType == type
                                        ) {
                                            workoutType = type
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenMargin)
                            }
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Duração").sectionHeader()

                            HStack(spacing: AppSpacing.lg) {
                                DurationButton(icon: "minus") {
                                    if durationMin > 5 { durationMin -= 5 }
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("\(durationMin)")
                                        .font(.system(.title, design: .rounded).monospacedDigit().bold())
                                        .foregroundStyle(AppColors.textPrimary)
                                        .contentTransition(.numericText())
                                        .animation(.easeOut(duration: 0.2), value: durationMin)
                                    Text("minutos")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer()
                                DurationButton(icon: "plus") {
                                    if durationMin < 180 { durationMin += 5 }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenMargin)

                        // Heart rate
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Frequência Cardíaca").sectionHeader()

                            HStack(spacing: AppSpacing.md) {
                                HRField(label: "FC Média", placeholder: "162", text: $avgHR)
                                HRField(label: "FC Pico", placeholder: "178", text: $peakHR)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenMargin)

                        // RPE
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Text("Esforço Percebido").sectionHeader()
                                Spacer()
                                Text("\(rpe)/10")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(rpeColor)
                            }

                            Slider(value: Binding(
                                get: { Double(rpe) },
                                set: { rpe = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(rpeColor)

                            Text(rpeLabel)
                                .font(.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.screenMargin)

                        // Notes
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Observações").sectionHeader()
                            TextField("Como foi o treino? Algo que notar...", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(AppSpacing.sm)
                                .background(AppColors.surfaceTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, AppSpacing.screenMargin)

                        // Error
                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(AppColors.fatigued)
                                .padding(.horizontal, AppSpacing.screenMargin)
                        }

                        Spacer(minLength: AppSpacing.xl)
                    }
                    .padding(.top, AppSpacing.lg)
                }

                // Submit button (outside scroll, always visible)
                Button(action: submitWorkout) {
                    if isLoading {
                        HStack(spacing: AppSpacing.xs) {
                            ProgressView().tint(.white)
                            Text("Analisando com o trainer...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Registrar e Analisar", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(height: 52)
                .background(AppGradients.ctaButton)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
                .disabled(isLoading)
                .padding(.horizontal, AppSpacing.screenMargin)
                .padding(.vertical, AppSpacing.sm)
            }
            .background(AppColors.surfacePrimary)
            .navigationTitle("Registrar Treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
    }

    private var rpeColor: Color {
        switch rpe {
        case 1...3: return AppColors.ready
        case 4...6: return AppColors.recovering
        case 7...8: return AppColors.fatigued.opacity(0.8)
        default: return AppColors.fatigued
        }
    }

    private var rpeLabel: String {
        switch rpe {
        case 1...3: return "Leve — conversa fácil"
        case 4...5: return "Moderado — respiração mais forte"
        case 6...7: return "Difícil — zona de limiar"
        case 8...9: return "Muito difícil — quase máximo"
        default: return "Máximo absoluto"
        }
    }

    private func submitWorkout() {
        isLoading = true
        error = nil

        Task {
            let avgHRVal = Double(avgHR)
            let peakHRVal = Double(peakHR)

            let hrZones: HRZones?
            if let avg = avgHRVal {
                let pct = avg / 190.0
                if pct >= 0.90 {
                    hrZones = HRZones(z1Pct: 2, z2Pct: 5, z3Pct: 10, z4Pct: 30, z5Pct: 53)
                } else if pct >= 0.80 {
                    hrZones = HRZones(z1Pct: 5, z2Pct: 10, z3Pct: 20, z4Pct: 55, z5Pct: 10)
                } else if pct >= 0.70 {
                    hrZones = HRZones(z1Pct: 10, z2Pct: 20, z3Pct: 40, z4Pct: 25, z5Pct: 5)
                } else {
                    hrZones = HRZones(z1Pct: 15, z2Pct: 50, z3Pct: 25, z4Pct: 8, z5Pct: 2)
                }
            } else {
                hrZones = nil
            }

            let estimatedCal = Double(durationMin) * (avgHRVal.map { $0 >= 155 ? 10.0 : 7.0 } ?? 8.0)

            let workout = WorkoutData(
                type: workoutType,
                durationMin: durationMin,
                avgHr: avgHRVal,
                peakHr: peakHRVal,
                hrZones: hrZones,
                rpe: rpe,
                caloriesEstimated: estimatedCal,
                notes: notes.isEmpty ? nil : notes,
                hasScreenshot: false
            )

            let intensity: WorkoutIntensity = avgHRVal.map { $0 >= 165 ? .high : ($0 >= 145 ? .moderate : .low) } ?? .moderate
            let entry = WorkoutEntry(
                date: Date(),
                type: workoutType,
                durationMin: durationMin,
                avgHr: avgHRVal,
                peakHr: peakHRVal,
                hrZones: hrZones,
                rpe: rpe,
                caloriesEstimated: estimatedCal,
                notes: notes.isEmpty ? nil : notes,
                intensity: intensity
            )
            persistence.saveManualWorkout(entry)

            let snapshot = await healthKit.fetchHealthSnapshot()
            let context = await healthKit.buildContext(
                from: snapshot,
                timeOfDay: .postWorkout,
                workout: workout,
                userMessage: notes.isEmpty ? nil : notes
            )

            do {
                let response = try await claude.fetchAnalysis(context: context)
                persistence.save(response: response)
                await MainActor.run {
                    onComplete?(response)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Workout Type Chip

private struct WorkoutTypeChip: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xxs) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .frame(width: 76, height: 68)
            .background(isSelected ? AppColors.accent : AppColors.surfaceTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : AppColors.accent.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Duration Button

private struct DurationButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.surfaceTertiary)
                .clipShape(Circle())
        }
    }
}

// MARK: - HR Input Field

private struct HRField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .font(.headline.monospacedDigit())
                .padding(AppSpacing.sm)
                .background(AppColors.surfaceTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
