import Foundation

/// The usage meters the API returns that we surface. (Other experimental buckets are ignored.)
enum MeterKey: String, CaseIterable, Identifiable {
    case fiveHour, sevenDay, sevenDayOpus, sevenDaySonnet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveHour:       return "Session (5h)"
        case .sevenDay:       return "Week (all models)"
        case .sevenDayOpus:   return "Week (Opus)"
        case .sevenDaySonnet: return "Week (Sonnet)"
        }
    }

    func meter(_ u: Usage) -> Meter? {
        switch self {
        case .fiveHour:       return u.fiveHour
        case .sevenDay:       return u.sevenDay
        case .sevenDayOpus:   return u.sevenDayOpus
        case .sevenDaySonnet: return u.sevenDaySonnet
        }
    }
}

/// Centralized UserDefaults keys + their defaults. Views use @AppStorage with the same keys;
/// non-view readers (UsageModel, Notifier) read UserDefaults directly — so defaults MUST be
/// registered at launch (App.init) before anything reads them.
enum Prefs {
    // keys
    static let headline       = "headline"          // String: a MeterKey rawValue, or "mostConstrained"
    static let showPercent    = "showPercent"
    static let showReset      = "showReset"
    static let showDot        = "showDot"
    static let showExtra      = "show_extra"
    static let notifyEnabled  = "notifyEnabled"
    static let notifyThreshold = "notifyThreshold"  // Double 50…100
    static func showKey(_ k: MeterKey) -> String { "show_\(k.rawValue)" }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            headline: MeterKey.sevenDay.rawValue,   // default = Week / all models
            showPercent: true,
            showReset: true,
            showDot: true,
            showKey(.fiveHour): true,
            showKey(.sevenDay): true,
            showKey(.sevenDayOpus): true,
            showKey(.sevenDaySonnet): true,
            showExtra: true,
            notifyEnabled: true,
            notifyThreshold: 90.0,
        ])
    }
}
