import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var persistence: PersistenceService

    var body: some View {
        NavigationStack {
            Group {
                if persistence.responses.isEmpty {
                    ContentUnavailableView(
                        "Sem histórico",
                        systemImage: "clock",
                        description: Text("As análises do trainer aparecerão aqui após o primeiro check-in.")
                    )
                } else {
                    List(persistence.responses) { response in
                        NavigationLink(destination: TrainerResponseView(response: response)) {
                            HistoryRow(response: response)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Histórico")
        }
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
        HStack(spacing: 12) {
            ReadinessBadge(
                score: response.readiness.score,
                color: response.readiness.color
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(response.today.recommendation.capitalized)
                    .font(.subheadline.weight(.medium))

                if let zone = response.today.targetZone, let hr = response.today.targetAvgHr {
                    Text("\(zone) · \(hr) bpm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
