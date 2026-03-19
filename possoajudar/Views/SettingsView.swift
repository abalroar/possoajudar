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
                // API Key section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
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
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }

                        if saved {
                            Label("Chave salva com sucesso", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    Button("Salvar Chave") {
                        claude.apiKey = apiKeyInput.trimmingCharacters(in: .whitespaces)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saved = false
                        }
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("Chave de API Anthropic")
                } footer: {
                    Text("Obtenha sua chave em console.anthropic.com. Armazenada com segurança no Keychain do dispositivo — nunca transmitida a servidores externos.")
                }

                // Baselines section
                Section {
                    BaselineRow(
                        label: "HRV de Referência",
                        unit: "ms",
                        value: ReadinessCalculator.hrvBaseline
                    )
                    BaselineRow(
                        label: "FC Repouso de Referência",
                        unit: "bpm",
                        value: ReadinessCalculator.hrBaseline
                    )
                } header: {
                    Text("Baselines (auto-calibradas)")
                } footer: {
                    Text("Atualizadas automaticamente com média exponencial (α=0,1) a cada check-in.")
                }

                // Profile section
                Section {
                    InfoRow(label: "Usuário", value: "Matheus")
                    InfoRow(label: "FCmáx Estimada", value: "190 bpm")
                    InfoRow(label: "Equipamento", value: "Kikos V.3.i")
                    InfoRow(label: "VO₂ Máx Histórico", value: "50,1 mL/kg/min")
                } header: {
                    Text("Perfil Permanente")
                }

                // Data section
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
                }

                // App info
                Section {
                    InfoRow(label: "Versão", value: "1.0.0")
                    InfoRow(label: "Modelo", value: "claude-opus-4-6")
                    InfoRow(label: "System Prompt", value: "Trainer v2")
                } header: {
                    Text("Sobre o App")
                } footer: {
                    Text("Apenas métricas calculadas no dispositivo são enviadas à API. Nenhum dado bruto de saúde é transmitido.")
                }
            }
            .navigationTitle("Ajustes")
            .onAppear {
                if let key = claude.apiKey {
                    apiKeyInput = key
                }
            }
            .confirmationDialog(
                "Limpar histórico?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Limpar", role: .destructive) {
                    persistence.clearHistory()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Isso apagará todas as análises salvas. Não pode ser desfeito.")
            }
        }
    }
}

private struct BaselineRow: View {
    let label: String
    let unit: String
    let value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f \(unit)", value))
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
