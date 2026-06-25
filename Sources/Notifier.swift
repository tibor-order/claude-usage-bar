import Foundation
import UserNotifications

/// Local notifications when a meter crosses the alert threshold.
/// Fires once per (meter, reset-window): re-arms only after the meter drops back below
/// threshold or its reset window rolls over — so a sustained-high meter won't spam every poll.
enum Notifier {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func evaluate(_ usage: Usage) {
        let d = UserDefaults.standard
        guard d.bool(forKey: Prefs.notifyEnabled) else { return }
        let threshold = d.double(forKey: Prefs.notifyThreshold)

        for key in MeterKey.allCases {
            guard let m = key.meter(usage), let pct = m.utilization else { continue }
            let stateKey = "notified_\(key.rawValue)"
            let window = m.resetsAt ?? "no-reset"   // identifies the current reset window

            if pct >= threshold {
                if d.string(forKey: stateKey) != window {     // not yet notified for this window
                    d.set(window, forKey: stateKey)
                    fire(title: "Claude usage \(Int(pct.rounded()))%",
                         body: "\(key.displayName) is at \(Int(pct.rounded()))% (alert at \(Int(threshold))%).")
                }
            } else if d.string(forKey: stateKey) != nil {
                d.removeObject(forKey: stateKey)              // re-arm for a later climb
            }
        }
    }

    private static func fire(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
