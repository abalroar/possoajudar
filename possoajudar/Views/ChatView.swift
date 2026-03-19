import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var persistence: PersistenceService

    @State private var messageText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingResponse = false
    @State private var latestResponse: TrainerResponse?

    private let suggestions = [
        "Por que minha FC demora a baixar pós-treino?",
        "Quero fazer 5 dias seguidos essa semana, como estruturo?",
        "Sinto que regredi muito. Onde estou?",
        "Posso treinar mesmo estando cansado hoje?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Intro
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pergunte ao Trainer")
                                .font(.title2.bold())
                            Text("Dúvidas técnicas, planejamento da semana, ou só uma leitura honesta do momento.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

                        // Suggestions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Perguntas frequentes")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(suggestions, id: \.self) { s in
                                        Button(action: { messageText = s }) {
                                            Text(s)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color(.secondarySystemBackground))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Error
                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                        }

                        // Latest response
                        if let response = latestResponse {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Resposta do Trainer")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal)

                                Button {
                                    showingResponse = true
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        ReadinessBadge(
                                            score: response.readiness.score,
                                            color: response.readiness.color
                                        )
                                        Text(response.trainerNote)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(4)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }

                        Spacer(minLength: 120)
                    }
                }

                // Input bar
                ChatInputBar(
                    text: $messageText,
                    isLoading: isLoading,
                    onSend: sendMessage
                )
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingResponse) {
                if let r = latestResponse {
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
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let msg = messageText
        messageText = ""
        isLoading = true
        errorMessage = nil

        Task {
            let snapshot = await healthKit.fetchHealthSnapshot()
            let hour = Calendar.current.component(.hour, from: Date())
            let context = await healthKit.buildContext(
                from: snapshot,
                timeOfDay: TimeOfDay.fromHour(hour),
                userMessage: msg
            )
            do {
                let response = try await claude.fetchAnalysis(context: context)
                persistence.save(response: response)
                await MainActor.run {
                    latestResponse = response
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

private struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                TextField("Pergunte algo...", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .disabled(isLoading)

                if isLoading {
                    ProgressView()
                        .frame(width: 36, height: 36)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .blue)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }
}
