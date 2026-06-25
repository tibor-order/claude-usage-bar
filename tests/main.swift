import Foundation

// Decode test: run the real captured response through the production Models.swift.
let path = CommandLine.arguments.dropFirst().first ?? "spike/usage-sample.json"
let data = try! Data(contentsOf: URL(fileURLWithPath: path))
let u = try! JSONDecoder().decode(Usage.self, from: data)

func show(_ name: String, _ m: Meter?) {
    guard let m else { print("  \(name): (null bucket — omitted)"); return }
    let util = m.utilization.map { "\($0)%" } ?? "nil"
    let reset = m.resetDate.map { ISO8601DateFormatter().string(from: $0) } ?? "nil"
    print("  \(name): util=\(util) reset=\(reset)")
}

print("Decoded \(path):")
show("five_hour", u.fiveHour)
show("seven_day", u.sevenDay)
show("seven_day_opus", u.sevenDayOpus)
show("seven_day_sonnet", u.sevenDaySonnet)
if let e = u.extraUsage {
    print("  extra_usage: enabled=\(e.isEnabled ?? false) used=\(e.usedCredits ?? 0)/\(e.monthlyLimit ?? 0) \(e.currency ?? "")")
}
if let s = u.spend {
    func money(_ m: Money?) -> String { (m?.value).map { Money.format($0, currency: m?.currency) } ?? "nil" }
    print("  spend: used=\(money(s.used)) limit=\(money(s.limit)) percent=\(s.percent.map { String($0) } ?? "nil") enabled=\(s.enabled ?? false) reason=\(s.disabledReason ?? "-")")
}
print("DECODE OK")
