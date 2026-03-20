import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var persistence: PersistenceService

    var body: some View {
        NavigationStack {
            Group {
                if persistence.responses.isEmpty {
                    emptyState
                } else {
                    List(persistence.responses) { response in
                        NavigationLink(destination: TrainerResponseView(response: response)) {
                            HistoryRow(response: response)
                        }
                        .listRowBackground(AppColors.surfacePrimary)
                        .listRowSeparatorTint(AppColors.surfaceTertiary)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(AppColors.surfacePrimary)
                }
            }
            .navigationTitle("Histórico")
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.accent.opacity(0.4))

            Text("Sem histórico")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("As análises do trainer aparecerão aqui após o primeiro check-in.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.surfacePrimary)
    }
}

private struct HistoryRow: View {
    let response: TrainerResponse

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "E, d MMM · HH:mm"
        return formatter.string(from: response.timestamp)
    }

    var body: some View {
        HStack(spacing: AppSpacing.componentGap) {
            ReadinessBadge(
                score: response.readiness.score,
                color: response.readiness.color
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(response.today.recommendation.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if let zone = response.today.targetZone, let hr = response.today.targetAvgHr {
                    Text("\(zone) · \(hr) bpm")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            // Readiness color indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.readinessColor(for: response.readiness.color))
                .frame(width: 3, height: 32)
        }
        .padding(.vertical, AppSpacing.xxs)
    }
}
