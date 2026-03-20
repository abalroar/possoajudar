import SwiftUI

struct TrainerResponseView: View {
    let response: TrainerResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero: Readiness gauge
                ReadinessGaugeView(
                    score: response.readiness.score,
                    label: response.readiness.label,
                    colorName: response.readiness.color,
                    primarySignal: response.readiness.primarySignal,
                    size: 180
                )
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl)

                // Tier 1 — Hero: Trainer Note
                TrainerNoteCard(text: response.trainerNote)
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.bottom, AppSpacing.xl)

                // Tier 2 — Primary: Today + Body Reading
                VStack(spacing: AppSpacing.lg) {
                    TodayPlanCard(plan: response.today)
                    BodyReadingCard(reading: response.bodyReading)
                }
                .padding(.horizontal, AppSpacing.screenMargin)
                .padding(.bottom, AppSpacing.lg)

                // Tier 3 — Secondary: Watch, Performance, Weekly
                VStack(spacing: AppSpacing.md) {
                    WatchSignalsCard(signals: response.watchSignals)
                    PerformanceContextCard(context: response.performanceContext)
                    WeeklyPictureCard(picture: response.weeklyPicture)
                }
                .padding(.horizontal, AppSpacing.screenMargin)

                // Timestamp
                Text(response.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppColors.surfacePrimary)
        .navigationTitle("Análise do Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Tier 1: Trainer Note (Hero card)

private struct TrainerNoteCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Nota do Trainer", systemImage: "quote.opening")
                .sectionHeader()

            Text(text)
                .font(.body)
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(5)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                AppColors.surfaceElevated
                AppGradients.trainerNote
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.accent)
                .frame(width: 3)
                .padding(.vertical, AppSpacing.xs)
        }
        .shadow(color: AppColors.accent.opacity(0.1), radius: 12, y: 4)
    }
}

// MARK: - Tier 2: Today Plan

private struct TodayPlanCard: View {
    let plan: TodayPlan

    private var recommendationColor: Color {
        switch plan.recommendation {
        case "treinar": return AppColors.ready
        case "treino leve": return AppColors.recovering
        case "recuperação ativa": return AppColors.recovering
        case "descanso": return AppColors.fatigued
        default: return AppColors.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.componentGap) {
            Label("Plano de Hoje", systemImage: "figure.run")
                .sectionHeader()

            HStack(alignment: .firstTextBaseline) {
                Text(plan.recommendation.capitalized)
                    .font(.title3.bold())
                    .foregroundStyle(recommendationColor)
                Spacer()
                if let zone = plan.targetZone {
                    Text(zone)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                }
            }

            if let hr = plan.targetAvgHr {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "heart.fill").foregroundStyle(AppColors.fatigued).font(.caption)
                    Text("Alvo: \(hr) bpm")
                        .font(.subheadline.weight(.medium))
                }
            }

            if let duration = plan.durationMin {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "clock").foregroundStyle(AppColors.textSecondary).font(.caption)
                    Text("\(duration) min")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if let structure = plan.structure, !structure.isEmpty {
                Divider().overlay(AppColors.surfaceTertiary)
                Text(structure)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }

            if let rationale = plan.rationale, !rationale.isEmpty {
                Divider().overlay(AppColors.surfaceTertiary)
                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .italic()
                    .lineSpacing(3)
            }
        }
        .cardStyle(elevation: .prominent)
    }
}

// MARK: - Tier 2: Body Reading

private struct BodyReadingCard: View {
    let reading: BodyReading

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.componentGap) {
            Label("Leitura Corporal", systemImage: "waveform.path.ecg")
                .sectionHeader()

            Text(reading.recoveryStatus)
                .font(.subheadline)
                .lineSpacing(3)

            if !reading.fatigueSignals.isEmpty {
                SignalList(
                    title: "Sinais de Fadiga",
                    icon: "exclamationmark.triangle.fill",
                    color: AppColors.recovering,
                    items: reading.fatigueSignals
                )
            }

            if !reading.positiveSignals.isEmpty {
                SignalList(
                    title: "Sinais Positivos",
                    icon: "checkmark.circle.fill",
                    color: AppColors.ready,
                    items: reading.positiveSignals
                )
            }
        }
        .cardStyle(elevation: .prominent)
    }
}

private struct SignalList: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(color).frame(width: 5, height: 5).padding(.top, 5)
                    Text(item).font(.caption).foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Tier 3: Watch Signals

private struct WatchSignalsCard: View {
    let signals: WatchSignals

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Sinais do Watch", systemImage: "applewatch")
                .sectionHeader()

            if let hrv = signals.hrvInterpretation {
                WatchSignalRow(icon: "waveform", label: "HRV", value: hrv)
            }
            if let rhr = signals.restingHrInterpretation {
                WatchSignalRow(icon: "heart.fill", label: "FC Repouso", value: rhr)
            }
            if let vo2 = signals.vo2maxNote {
                WatchSignalRow(icon: "lungs.fill", label: "VO\u{2082} Máx", value: vo2)
            }
        }
        .cardStyle(elevation: .standard)
    }
}

private struct WatchSignalRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - Tier 3: Performance Context

private struct PerformanceContextCard: View {
    let context: PerformanceContext

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("Contexto de Performance", systemImage: "chart.line.uptrend.xyaxis")
                .sectionHeader()

            if let last = context.vsLastSession {
                ContextRow(label: "vs. Última Sessão", value: last)
            }
            if let hist = context.vsSamePeriodHist {
                ContextRow(label: "vs. Histórico", value: hist)
            }
            if let trend = context.trendComment {
                ContextRow(label: "Tendência", value: trend)
            }
        }
        .cardStyle(elevation: .standard)
    }
}

private struct ContextRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(2)
        }
    }
}

// MARK: - Tier 3: Weekly Picture

private struct WeeklyPictureCard: View {
    let picture: WeeklyPicture

    private var loadColor: Color {
        switch picture.loadAssessment {
        case "leve": return AppColors.inForm
        case "adequada": return AppColors.ready
        case "elevada": return AppColors.recovering
        case "excessiva": return AppColors.fatigued
        default: return AppColors.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.componentGap) {
            Label("Semana", systemImage: "calendar.badge.clock")
                .sectionHeader()

            HStack {
                Text("Carga Semanal")
                    .font(.subheadline)
                Spacer()
                Text(picture.loadAssessment.capitalized)
                    .font(.subheadline.bold())
                    .foregroundStyle(loadColor)
            }

            if let next = picture.nextKeySession {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Próxima Sessão Chave")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .textCase(.uppercase)
                    Text(next).font(.caption).foregroundStyle(AppColors.textSecondary).lineSpacing(2)
                }
            }

            if let rest = picture.restDayNeededBy {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "moon.fill").font(.caption).foregroundStyle(.purple)
                    Text("Descanso recomendado até: \(rest)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .cardStyle(elevation: .standard)
    }
}
