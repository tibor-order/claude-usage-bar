import Foundation
import SwiftUI

/// Observable state for the menu bar: polls UsageClient and exposes display-ready values.
@MainActor
final class UsageModel: ObservableObject {
    @Published private(set) var usage: Usage?
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private var timer: Timer?
    private let interval: TimeInterval = 60
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        do {
            usage = try await UsageClient.fetch()
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = Self.describe(error)
        }
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case UsageError.noToken: return "no token"
        case let UsageError.http(code, _): return code == 401 ? "auth" : "http \(code)"
        case UsageError.decode: return "bad data"
        default: return "offline"
        }
    }

    // MARK: - Display

    struct Row: Identifiable {
        let name: String
        let pct: Double
        let reset: Date?
        var id: String { name }
    }

    var rows: [Row] {
        guard let u = usage else { return [] }
        var out: [Row] = []
        func add(_ name: String, _ m: Meter?) {
            if let m, let p = m.utilization { out.append(Row(name: name, pct: p, reset: m.resetDate)) }
        }
        add("Session (5h)", u.fiveHour)
        add("Week (all models)", u.sevenDay)
        add("Week (Opus)", u.sevenDayOpus)
        add("Week (Sonnet)", u.sevenDaySonnet)
        return out
    }

    /// Most-constrained meter drives the menu-bar headline.
    var headline: Row? { rows.max(by: { $0.pct < $1.pct }) }

    var extraUsageText: String? {
        guard let e = usage?.extraUsage, e.isEnabled == true, let limit = e.monthlyLimit else { return nil }
        let used = e.usedCredits ?? 0
        let cur = e.currency ?? ""
        return "Extra usage: \(Int(used)) / \(Int(limit)) \(cur)"
    }

    var labelText: String {
        if let err = lastError, usage == nil { return "⚠︎ \(err)" }
        guard let h = headline else { return "…" }
        return "\(Self.dot(h.pct)) \(Int(h.pct.rounded()))%\(Self.resetSuffix(h.reset))"
    }

    static func dot(_ p: Double) -> String { p >= 80 ? "🔴" : (p >= 50 ? "🟡" : "🟢") }

    static func resetSuffix(_ d: Date?) -> String {
        guard let s = d?.timeIntervalSinceNow, s > 0 else { return "" }
        let h = Int(s) / 3600
        if h >= 48 { return " · \(h / 24)d" }
        if h >= 1 { return " · \(h)h" }
        return " · \(Int(s) / 60)m"
    }
}
