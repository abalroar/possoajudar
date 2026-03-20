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
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        // Intro
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "brain.head.profile")
                                    .font(.title2)
                                    .foregroundStyle(AppColors.accent)
                                Text("Pergunte ao Trainer")
                                    .font(.title2).fontWeight(.bold)
                            }
                            Text("Dúvidas técnicas, planejamento da semana, ou uma leitura honesta do momento.")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, AppSpacing.screenMargin)
                        .padding(.top, AppSpacing.md)

                        // Suggestions
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Perguntas frequentes")
                                .sectionHeader()
                                .padding(.horizontal, AppSpacing.screenMargin)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(suggestions, id: \.self) { s in
                                        Button(action: { messageText = s }) {
                                            Text(s)
                                                .font(.subheadline)
                                                .foregroundStyle(AppColors.textPrimary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(AppColors.surfaceTertiary)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.screenMargin)
                            }
                        }

                        // Error
                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(AppColors.fatigued)
                                .padding(AppSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.fatigued.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal, AppSpacing.screenMargin)
                        }

                        // Latest response
                        if let response = latestResponse {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Resposta do Trainer")
                                    .sectionHeader()
                                    .padding(.horizontal, AppSpacing.screenMargin)

                                Button {
                                    showingResponse = true
                                } label: {
                                    HStack(alignment: .top, spacing: AppSpacing.componentGap) {
                                        ReadinessBadge(
                                            score: response.readiness.score,
                                            color: response.readiness.color
                                        )
                                        Text(response.trainerNote)
                                            .font(.subheadline)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .lineLimit(4)
                                            .multilineTextAlignment(.leading)
                                            .lineSpacing(3)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textTertiary)
                                    }
                                    .cardStyle(elevation: .standard)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, AppSpacing.screenMargin)
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
            .background(AppColors.surfacePrimary)
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
                latestResponse = response
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Chat Input Bar

private struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.componentGap) {
            TextField("Pergunte algo...", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surfaceTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .disabled(isLoading)

            if isLoading {
                ProgressView()
                    .tint(AppColors.accent)
                    .frame(width: 36, height: 36)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            text.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AppColors.textTertiary
                                : AppColors.accent
                        )
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.vertical, AppSpacing.sm)
        .background(
            AppColors.surfacePrimary
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: -4)
        )
    }
}
