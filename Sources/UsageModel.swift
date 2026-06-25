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

    struct SpendInfo {
        let used: String        // formatted money, e.g. "€43.36"
        let limit: String       // topped-up cap, e.g. "€100.00"
        let remaining: String   // limit − used
        let percent: Double
        let status: String?     // nil when active; "out of credits" / "off" otherwise
    }

    /// Real money values for pay-as-you-go top-up credits, from the API `spend` block.
    var spendInfo: SpendInfo? {
        guard let s = usage?.spend,
              let usedV = s.used?.value,
              let limitV = s.limit?.value, limitV > 0 else { return nil }
        let cur = s.used?.currency ?? s.limit?.currency
        let status: String? = (s.enabled == true) ? nil
            : (s.disabledReason == "out_of_credits" ? "out of credits" : "off")
        return SpendInfo(
            used: Money.format(usedV, currency: cur),
            limit: Money.format(limitV, currency: cur),
            remaining: Money.format(max(0, limitV - usedV), currency: cur),
            percent: s.percent ?? (usedV / limitV * 100),
            status: status
        )
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
