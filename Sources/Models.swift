import Foundation

/// One usage meter, e.g. the 5-hour session window. Both fields may be null in the API.
struct Meter: Codable {
    let utilization: Double?
    let resetsAt: String?   // raw ISO-8601 string, or nil
    let limitDollars: Double?       // null on most plans; set only for $-metered limits
    let usedDollars: Double?
    let remainingDollars: Double?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
        case limitDollars = "limit_dollars"
        case usedDollars = "used_dollars"
        case remainingDollars = "remaining_dollars"
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
    let utilization: Double?
    let currency: String?
    let disabledReason: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
        case currency
        case disabledReason = "disabled_reason"
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
    let spend: Spend?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
        case spend
    }
}

/// A money amount in minor units (e.g. cents). value = amount_minor / 10^exponent.
struct Money: Codable {
    let amountMinor: Double?
    let currency: String?
    let exponent: Int?

    enum CodingKeys: String, CodingKey {
        case amountMinor = "amount_minor"
        case currency
        case exponent
    }

    var value: Double? {
        guard let a = amountMinor else { return nil }
        return a / pow(10.0, Double(exponent ?? 0))
    }

    static func format(_ v: Double, currency: String?) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency ?? "USD"
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }
}

/// Pay-as-you-go top-up ("usage credits"): real spent / cap amounts.
struct Spend: Codable {
    let used: Money?
    let limit: Money?
    let percent: Double?
    let enabled: Bool?
    let disabledReason: String?
    let canPurchaseCredits: Bool?

    enum CodingKeys: String, CodingKey {
        case used, limit, percent, enabled
        case disabledReason = "disabled_reason"
        case canPurchaseCredits = "can_purchase_credits"
    }
}
