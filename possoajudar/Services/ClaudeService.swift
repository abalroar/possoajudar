import Foundation

/// Calls the Anthropic Messages API with the personal trainer system prompt.
@MainActor
final class ClaudeService: ObservableObject {

    @Published var loadingState: AppLoadingState = .idle

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-6"
    private let maxTokens = 2048

    // MARK: - API Key

    var apiKey: String? {
        get { KeychainService.load(for: .anthropicAPIKey) }
        set {
            if let key = newValue, !key.isEmpty {
                KeychainService.save(key, for: .anthropicAPIKey)
            } else {
                KeychainService.delete(for: .anthropicAPIKey)
            }
        }
    }

    var hasAPIKey: Bool { !(apiKey?.isEmpty ?? true) }

    // MARK: - Main Fetch

    /// Calls Claude with the trainer context and returns a parsed TrainerResponse.
    func fetchAnalysis(context: TrainerContext) async throws -> TrainerResponse {
        guard let key = apiKey, !key.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        loadingState = .loading

        do {
            let response = try await callAPI(context: context, apiKey: key)
            loadingState = .success
            return response
        } catch {
            loadingState = .failure(error.localizedDescription)
            throw error
        }
    }

    // MARK: - API Call

    private func callAPI(context: TrainerContext, apiKey: String) async throws -> TrainerResponse {
        let contextJSON = context.toJSONString()
        let userContent = """
        Contexto atual (JSON):
        \(contextJSON)
        \(context.userMessage.map { "\nMensagem do usuário: \($0)" } ?? "")
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": SystemPrompt.trainerV2,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let http = httpResponse as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw ClaudeError.apiError(statusCode: http.statusCode, message: body)
        }

        return try parseResponse(data: data, context: context)
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data, context: TrainerContext) throws -> TrainerResponse {
        // Parse the Anthropic API wrapper
        guard let apiJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = apiJSON["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeError.parseError("Could not extract text from API response")
        }

        // Extract JSON from the text (Claude may add markdown code fences)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeError.parseError("Could not encode response as UTF8")
        }

        let decoder = JSONDecoder()
        do {
            var response = try decoder.decode(TrainerResponse.self, from: jsonData)
            // Attach context snapshot for history display
            // (TrainerResponse.init handles the id/timestamp)
            return TrainerResponse(
                readiness: response.readiness,
                today: response.today,
                bodyReading: response.bodyReading,
                performanceContext: response.performanceContext,
                trainerNote: response.trainerNote,
                watchSignals: response.watchSignals,
                weeklyPicture: response.weeklyPicture,
                context: context
            )
        } catch {
            throw ClaudeError.parseError("JSON decode failed: \(error.localizedDescription)\n\nRaw: \(jsonString.prefix(500))")
        }
    }

    private func extractJSON(from text: String) -> String {
        // Remove markdown code fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        // Find the JSON object boundaries
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Chave de API Anthropic não configurada. Acesse Ajustes para adicionar."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        case .apiError(let code, let msg):
            if code == 401 { return "Chave de API inválida. Verifique em Ajustes." }
            if code == 429 { return "Limite de requisições atingido. Aguarde e tente novamente." }
            return "Erro da API (\(code)): \(msg.prefix(200))"
        case .parseError(let detail):
            return "Erro ao interpretar resposta do trainer: \(detail)"
        }
    }
}
