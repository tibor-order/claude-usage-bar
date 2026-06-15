import Foundation
import Security

/// Reads the long-lived Claude OAuth token.
/// Priority: $CLAUDE_CODE_OAUTH_TOKEN (if launched from a shell) → Keychain item
/// created by spike/seed-token.sh (service=ClaudeUsageBar, account=default).
enum TokenStore {
    static let service = "ClaudeUsageBar"
    static let account = "default"

    static func read() -> String? {
        if let t = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"],
           !t.isEmpty {
            return t
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
