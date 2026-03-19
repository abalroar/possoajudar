import SwiftUI

struct TrainerResponseView: View {
    let response: TrainerResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header readiness gauge
                ReadinessGaugeView(
                    score: response.readiness.score,
                    label: response.readiness.label,
                    colorName: response.readiness.color,
                    primarySignal: response.readiness.primarySignal,
                    size: 180
                )
                .padding(.top, 8)

                // Trainer note (most important field)
                TrainerNoteCard(text: response.trainerNote)

                // Today's plan
                TodayPlanCard(plan: response.today)

                // Body reading
                BodyReadingCard(reading: response.bodyReading)

                // Watch signals
                WatchSignalsCard(signals: response.watchSignals)

                // Performance context
                PerformanceContextCard(context: response.performanceContext)

                // Weekly picture
                WeeklyPictureCard(picture: response.weeklyPicture)

                // Timestamp
                Text(response.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Análise do Trainer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-cards

private struct TrainerNoteCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nota do Trainer", systemImage: "person.fill.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct TodayPlanCard: View {
    let plan: TodayPlan

    private var recommendationColor: Color {
        switch plan.recommendation {
        case "treinar": return .green
        case "treino leve": return .yellow
        case "recuperação ativa": return .orange
        case "descanso": return .red
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Plano de Hoje", systemImage: "figure.run")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline) {
                Text(plan.recommendation.capitalized)
                    .font(.title3.bold())
                    .foregroundColor(recommendationColor)
                Spacer()
                if let zone = plan.targetZone {
                    Text(zone)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Capsule())
                }
            }

            if let hr = plan.targetAvgHr {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").foregroundColor(.red).font(.caption)
                    Text("Alvo: \(hr) bpm")
                        .font(.subheadline.weight(.medium))
                }
            }

            if let duration = plan.durationMin {
                HStack(spacing: 4) {
                    Image(systemName: "clock").foregroundColor(.secondary).font(.caption)
                    Text("\(duration) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let structure = plan.structure, !structure.isEmpty {
                Divider()
                Text(structure)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }

            if let rationale = plan.rationale, !rationale.isEmpty {
                Divider()
                Text(rationale)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct BodyReadingCard: View {
    let reading: BodyReading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Leitura Corporal", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(reading.recoveryStatus)
                .font(.subheadline)
                .lineSpacing(3)

            if !reading.fatigueSignals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Sinais de Fadiga", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                    ForEach(reading.fatigueSignals, id: \.self) { signal in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(.orange)
                            Text(signal).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            if !reading.positiveSignals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Sinais Positivos", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                    ForEach(reading.positiveSignals, id: \.self) { signal in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•").foregroundColor(.green)
                            Text(signal).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct WatchSignalsCard: View {
    let signals: WatchSignals

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sinais do Watch", systemImage: "applewatch")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            if let hrv = signals.hrvInterpretation {
                WatchSignalRow(icon: "waveform", label: "HRV", value: hrv)
            }
            if let rhr = signals.restingHrInterpretation {
                WatchSignalRow(icon: "heart.fill", label: "FC Repouso", value: rhr)
            }
            if let vo2 = signals.vo2maxNote {
                WatchSignalRow(icon: "lungs.fill", label: "VO₂ Máx", value: vo2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct WatchSignalRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.caption)
                    .lineSpacing(2)
            }
        }
    }
}

private struct PerformanceContextCard: View {
    let context: PerformanceContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Contexto de Performance", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ContextRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.caption)
                .lineSpacing(2)
        }
    }
}

private struct WeeklyPictureCard: View {
    let picture: WeeklyPicture

    private var loadColor: Color {
        switch picture.loadAssessment {
        case "leve": return .blue
        case "adequada": return .green
        case "elevada": return .orange
        case "excessiva": return .red
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Semana", systemImage: "calendar.badge.clock")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack {
                Text("Carga Semanal")
                    .font(.subheadline)
                Spacer()
                Text(picture.loadAssessment.capitalized)
                    .font(.subheadline.bold())
                    .foregroundColor(loadColor)
            }

            if let next = picture.nextKeySession {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Próxima Sessão Chave")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(next).font(.caption).lineSpacing(2)
                }
            }

            if let rest = picture.restDayNeededBy {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill").font(.caption).foregroundColor(.purple)
                    Text("Descanso recomendado até: \(rest)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
