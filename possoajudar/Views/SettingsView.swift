import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var claude: ClaudeService
    @EnvironmentObject private var persistence: PersistenceService

    @State private var apiKeyInput = ""
    @State private var showAPIKey = false
    @State private var saved = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // API Key
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack {
                            if showAPIKey {
                                TextField("sk-ant-...", text: $apiKeyInput)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("sk-ant-...", text: $apiKeyInput)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button { showAPIKey.toggle() } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }

                        if saved {
                            Label("Chave salva com sucesso", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppColors.ready)
                        }
                    }

                    Button {
                        claude.apiKey = apiKeyInput.trimmingCharacters(in: .whitespaces)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                    } label: {
                        Text("Salvar Chave")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Chave de API Anthropic")
                } footer: {
                    Text("Obtenha sua chave em console.anthropic.com. Armazenada com segurança no Keychain — nunca transmitida a servidores externos.")
                        .foregroundStyle(AppColors.textTertiary)
                }

                // Baselines
                Section {
                    BaselineRow(
                        icon: "waveform",
                        label: "HRV de Referência",
                        value: String(format: "%.1f", ReadinessCalculator.hrvBaseline),
                        unit: "ms"
                    )
                    BaselineRow(
                        icon: "heart.fill",
                        label: "FC Repouso de Referência",
                        value: String(format: "%.1f", ReadinessCalculator.hrBaseline),
                        unit: "bpm"
                    )
                } header: {
                    Text("Baselines (auto-calibradas)")
                } footer: {
                    Text("Atualizadas automaticamente com média exponencial (α=0,1) a cada check-in.")
                        .foregroundStyle(AppColors.textTertiary)
                }

                // Profile
                Section {
                    ProfileRow(icon: "person.fill", label: "Usuário", value: "Matheus")
                    ProfileRow(icon: "heart.fill", label: "FCmáx Estimada", value: "190 bpm")
                    ProfileRow(icon: "bicycle", label: "Equipamento", value: "Kikos V.3.i")
                    ProfileRow(icon: "lungs.fill", label: "VO\u{2082} Máx Histórico", value: "50,1 mL/kg/min")
                } header: {
                    Text("Perfil Permanente")
                }

                // Data
                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Limpar Histórico de Análises", systemImage: "trash")
                    }
                } header: {
                    Text("Dados")
                } footer: {
                    Text("\(persistence.responses.count) análises armazenadas localmente.")
                        .foregroundStyle(AppColors.textTertiary)
                }

                // About
                Section {
                    ProfileRow(icon: "app.badge", label: "Versão", value: "1.0.0")
                    ProfileRow(icon: "cpu", label: "Modelo", value: "claude-opus-4-6")
                    ProfileRow(icon: "doc.text", label: "System Prompt", value: "Trainer v2")
                } header: {
                    Text("Sobre o App")
                } footer: {
                    VStack(spacing: AppSpacing.xs) {
                        Text("Posso Ajudar")
                            .font(.headline)
                            .foregroundStyle(AppColors.accent)
                        Text("Apenas métricas calculadas no dispositivo são enviadas à API. Nenhum dado bruto de saúde é transmitido.")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.md)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.surfaceSecondary)
            .navigationTitle("Ajustes")
            .onAppear {
                if let key = claude.apiKey { apiKeyInput = key }
            }
            .confirmationDialog(
                "Limpar histórico?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Limpar", role: .destructive) { persistence.clearHistory() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Isso apagará todas as análises salvas. Não pode ser desfeito.")
            }
        }
    }
}

// MARK: - Row Components

private struct BaselineRow: View {
    let icon: String
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            HStack(spacing: AppSpacing.xxs) {
                Text(value)
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(AppColors.accent)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }
}

private struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(label)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
