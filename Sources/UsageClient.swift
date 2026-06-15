import Foundation

enum UsageError: Error {
    case noToken
    case http(Int, String)
    case decode(Error)
}

/// Single responsibility: fetch + decode the usage endpoint. No UI, no state.
enum UsageClient {
    static let endpoint: URL = {
        let base = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"]
            ?? "https://api.anthropic.com"
        return URL(string: base + "/api/oauth/usage")!
    }()

    static func fetch() async throws -> Usage {
        guard let token = TokenStore.read() else { throw UsageError.noToken }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("claude-cli/2.1.138 (ClaudeUsageBar)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw UsageError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(Usage.self, from: data)
        } catch {
            throw UsageError.decode(error)
        }
    }
}
