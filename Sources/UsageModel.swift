import Foundation
import SwiftUI

/// Observable state for the menu bar: polls UsageClient on an adaptive schedule, caches the
/// last good result, and triggers threshold notifications.
@MainActor
final class UsageModel: ObservableObject {
    @Published private(set) var usage: Usage?
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private var timer: Timer?
    private let baseInterval: TimeInterval = 300        // 5 min when healthy
    private var nextDelay: TimeInterval = 300
    private var started = false

    private let cacheKey = "cachedUsage"
    private let cacheAtKey = "cachedUsageAt"

    init() {
        // Restore last-good usage so a cold start (or a rate-limit) shows data immediately
        // instead of an error.
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(Usage.self, from: data) {
            usage = cached
            lastUpdated = UserDefaults.standard.object(forKey: cacheAtKey) as? Date
        }
    }

    func start() {
        guard !started else { return }
        started = true
        Notifier.requestAuth()
        Task { await tick() }
    }

    /// Forced refresh from the UI; also reschedules the next automatic poll.
    func refreshNow() async { await tick() }

    private func tick() async {
        await refresh()
        scheduleNext(nextDelay)
    }

    private func scheduleNext(_ delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { await self?.tick() }
        }
    }

    private func refresh() async {
        do {
            let u = try await UsageClient.fetch()
            usage = u
            lastError = nil
            lastUpdated = Date()
            nextDelay = baseInterval                    // healthy → back to 5 min
            persist(u)
            Notifier.evaluate(u)
        } catch {
            lastError = Self.describe(error)
            nextDelay = Self.backoff(for: error, current: nextDelay, base: baseInterval)
            // NOTE: usage is intentionally NOT cleared — keep showing the last good value.
        }
    }

    private func persist(_ u: Usage) {
        guard let data = try? JSONEncoder().encode(u) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheAtKey)
    }

    /// Honor Retry-After on 429; otherwise exponential backoff up to 30 min.
    static func backoff(for error: Error, current: TimeInterval, base: TimeInterval) -> TimeInterval {
        if case let UsageError.rateLimited(retryAfter) = error {
            return min(max(retryAfter ?? current * 2, 120), 1800)
        }
        return min(max(current, 90), base)              // transient errors: retry within ~base
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case UsageError.noToken: return "no token"
        case UsageError.rateLimited: return "rate-limited"
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

    var rows: [Row] { MeterKey.allCases.compactMap { row(for: $0) } }

    var mostConstrained: Row? { rows.max { $0.pct < $1.pct } }

    func headlineRow(_ choice: String) -> Row? {
        guard usage != nil else { return nil }
        if choice == "mostConstrained" { return mostConstrained }
        if let key = MeterKey(rawValue: choice), let r = row(for: key) { return r }
        return mostConstrained ?? rows.first
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

    /// Compact "Xh / Yd / Zm", or nil if no/elapsed reset.
    static func shortDuration(_ d: Date?) -> String? {
        guard let s = d?.timeIntervalSinceNow, s > 0 else { return nil }
        let h = Int(s) / 3600
        if h >= 48 { return "\(h / 24)d" }
        if h >= 1 { return "\(h)h" }
        return "\(Int(s) / 60)m"
    }
}
