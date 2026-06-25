import SwiftUI
import AppKit

@main
struct ClaudeUsageBarApp: App {
    @StateObject private var model: UsageModel

    init() {
        Prefs.registerDefaults()
        _model = StateObject(wrappedValue: UsageModel())
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            LabelView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

/// Menu-bar title. Owns the lifecycle kick (`.task` fires once at launch) and renders
/// the user-chosen headline meter in the user-chosen format.
struct LabelView: View {
    @ObservedObject var model: UsageModel
    @AppStorage(Prefs.headline)    private var headline = MeterKey.sevenDay.rawValue
    @AppStorage(Prefs.showPercent) private var showPercent = true
    @AppStorage(Prefs.showReset)   private var showReset = true
    @AppStorage(Prefs.showDot)     private var showDot = true

    var body: some View {
        Text(text).task { model.start() }
    }

    private var text: String {
        if let err = model.lastError, model.usage == nil { return "⚠︎ \(err)" }
        guard let row = model.headlineRow(headline) else { return "…" }
        var parts: [String] = []
        if showDot { parts.append(UsageModel.dot(row.pct)) }
        if showPercent { parts.append("\(Int(row.pct.rounded()))%") }
        var s = parts.joined(separator: " ")
        if s.isEmpty { s = row.name }                       // never render an empty title
        if showReset, let dur = UsageModel.shortDuration(row.reset) { s += " · \(dur)" }
        return s
    }
}

struct PopoverView: View {
    @ObservedObject var model: UsageModel
    @Environment(\.openSettings) private var openSettings

    @AppStorage(Prefs.showKey(.fiveHour))       private var sFive = true
    @AppStorage(Prefs.showKey(.sevenDay))       private var sWeek = true
    @AppStorage(Prefs.showKey(.sevenDayOpus))   private var sOpus = true
    @AppStorage(Prefs.showKey(.sevenDaySonnet)) private var sSonnet = true
    @AppStorage(Prefs.showExtra)                private var sExtra = true

    private func visible(_ key: MeterKey) -> Bool {
        switch key {
        case .fiveHour:       return sFive
        case .sevenDay:       return sWeek
        case .sevenDayOpus:   return sOpus
        case .sevenDaySonnet: return sSonnet
        }
    }

    var body: some View {
        let enabled = MeterKey.allCases.filter { visible($0) }
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude Usage").font(.headline)

            if model.usage == nil {
                Text(model.lastError.map { "Can't load usage: \($0)" } ?? "Loading…")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.lastError == "no token" {
                    Text("Run `claude setup-token`, then `spike/seed-token.sh`.")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } else {
                if enabled.isEmpty {
                    Text("No meters selected — open Settings ▸ Meters.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(enabled) { meterRow($0) }       // a toggled-on meter ALWAYS shows
                if sExtra, let sp = model.spendInfo {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Extra credits")
                            Spacer()
                            Text("\(sp.used) / \(sp.limit)").monospacedDigit()
                        }
                        ProgressView(value: min(sp.percent, 100), total: 100).tint(tint(sp.percent))
                        Text(sp.status.map { "\(sp.remaining) left · \($0)" } ?? "\(sp.remaining) left")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            HStack {
                Text(updatedText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { Task { await model.refresh() } }
            }
            HStack {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    /// A meter with data → name + % + reset + bar. A meter with no data this window →
    /// muted "no usage" so the row still corresponds to its toggle.
    @ViewBuilder
    private func meterRow(_ key: MeterKey) -> some View {
        if let row = model.row(for: key) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.name)
                    Spacer()
                    Text("\(Int(row.pct.rounded()))%").monospacedDigit()
                    if let dur = UsageModel.shortDuration(row.reset) {
                        Text(dur).foregroundStyle(.secondary).font(.caption)
                    }
                }
                ProgressView(value: min(row.pct, 100), total: 100).tint(tint(row.pct))
            }
        } else {
            HStack {
                Text(key.displayName).foregroundStyle(.secondary)
                Spacer()
                Text("no usage").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var updatedText: String {
        guard let u = model.lastUpdated else { return "—" }
        return "Updated \(u.formatted(date: .omitted, time: .shortened))"
    }

    private func tint(_ p: Double) -> Color { p >= 80 ? .red : (p >= 50 ? .yellow : .green) }
}
