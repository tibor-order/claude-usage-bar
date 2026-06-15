import SwiftUI
import AppKit

@main
struct ClaudeUsageBarApp: App {
    @StateObject private var model = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            // Always-present label view → its .task starts polling at app launch.
            LabelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu-bar title. Owns the lifecycle kick (`.task` fires once when the label appears).
struct LabelView: View {
    @ObservedObject var model: UsageModel
    var body: some View {
        Text(model.labelText)
            .task { model.start() }
    }
}

struct PopoverView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude Usage").font(.headline)

            if model.rows.isEmpty {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.lastError == "no token" {
                    Text("Run `claude setup-token`, then `spike/seed-token.sh`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                ForEach(model.rows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(row.name)
                            Spacer()
                            Text("\(Int(row.pct.rounded()))%").monospacedDigit()
                            if let r = row.reset {
                                Text(resetText(r)).foregroundStyle(.secondary).font(.caption)
                            }
                        }
                        ProgressView(value: min(row.pct, 100), total: 100)
                            .tint(tint(row.pct))
                    }
                }
            }

            if let extra = model.extraUsageText {
                Divider()
                Text(extra).font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Text(updatedText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { Task { await model.refresh() } }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 290)
    }

    private var emptyMessage: String {
        if let e = model.lastError { return "Can't load usage: \(e)" }
        return "Loading…"
    }

    private var updatedText: String {
        guard let u = model.lastUpdated else { return "—" }
        return "Updated \(u.formatted(date: .omitted, time: .shortened))"
    }

    private func tint(_ p: Double) -> Color { p >= 80 ? .red : (p >= 50 ? .yellow : .green) }

    private func resetText(_ d: Date) -> String {
        let s = d.timeIntervalSinceNow
        if s <= 0 { return "now" }
        let h = Int(s) / 3600
        if h >= 48 { return "\(h / 24)d" }
        if h >= 1 { return "\(h)h" }
        return "\(Int(s) / 60)m"
    }
}
