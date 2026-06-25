import Foundation
import SwiftUI

/// Observable state for the menu bar: polls UsageClient, exposes display-ready rows,
/// and triggers threshold notifications.
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
        Notifier.requestAuth()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        do {
            let u = try await UsageClient.fetch()
            usage = u
            lastError = nil
            lastUpdated = Date()
            Notifier.evaluate(u)
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
        let key: MeterKey
        let pct: Double
        let reset: Date?
        var id: String { key.rawValue }
        var name: String { key.displayName }
    }

    func row(for key: MeterKey) -> Row? {
        guard let u = usage, let m = key.meter(u), let p = m.utilization else { return nil }
        return Row(key: key, pct: p, reset: m.resetDate)
    }

    /// Meters that currently have data, in a stable order.
    var rows: [Row] { MeterKey.allCases.compactMap { row(for: $0) } }

    var mostConstrained: Row? { rows.max { $0.pct < $1.pct } }

    /// The row to show in the menu bar, per the user's headline choice.
    func headlineRow(_ choice: String) -> Row? {
        guard usage != nil else { return nil }
        if choice == "mostConstrained" { return mostConstrained }
        if let key = MeterKey(rawValue: choice), let r = row(for: key) { return r }
        return mostConstrained ?? rows.first   // chosen meter is null right now → graceful fallback
    }

    /// Shown whenever an overflow allowance exists — including when it's off/exhausted,
    /// since that status is itself useful. nil only when there's no extra-usage block at all.
    var extraUsageText: String? {
        guard let e = usage?.extraUsage, let limit = e.monthlyLimit, limit > 0 else { return nil }
        let used = Int((e.usedCredits ?? 0).rounded())
        let cur = e.currency ?? ""
        var s = "Extra usage: \(used)/\(Int(limit)) \(cur)"
        if let u = e.utilization { s += " · \(Int(u.rounded()))%" }
        if e.isEnabled != true {
            s += e.disabledReason == "out_of_credits" ? " · out of credits" : " · off"
        }
        return s
    }

    static func dot(_ p: Double) -> String { p >= 80 ? "🔴" : (p >= 50 ? "🟡" : "🟢") }

    /// Compact "in Xh / Yd / Zm", or nil if no/elapsed reset.
    static func shortDuration(_ d: Date?) -> String? {
        guard let s = d?.timeIntervalSinceNow, s > 0 else { return nil }
        let h = Int(s) / 3600
        if h >= 48 { return "\(h / 24)d" }
        if h >= 1 { return "\(h)h" }
        return "\(Int(s) / 60)m"
    }
}
