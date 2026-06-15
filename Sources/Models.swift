import Foundation

/// One usage meter, e.g. the 5-hour session window. Both fields may be null in the API.
struct Meter: Codable {
    let utilization: Double?
    let resetsAt: String?   // raw ISO-8601 string, or nil

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? { Meter.parse(resetsAt) }

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

/// Pay-as-you-go overflow credits (shown only when enabled).
struct ExtraUsage: Codable {
    let isEnabled: Bool?
    let monthlyLimit: Double?
    let usedCredits: Double?
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case currency
    }
}

/// Response of GET /api/oauth/usage. Only the meters we surface are decoded;
/// unknown experimental buckets are ignored.
struct Usage: Codable {
    let fiveHour: Meter?
    let sevenDay: Meter?
    let sevenDayOpus: Meter?
    let sevenDaySonnet: Meter?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}
