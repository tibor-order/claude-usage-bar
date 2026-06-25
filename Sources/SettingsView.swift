import SwiftUI

/// Tabbed settings: Menu Bar (what shows + format), Meters (what's in the dropdown), Alerts.
struct SettingsView: View {
    var body: some View {
        TabView {
            MenuBarTab().tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            MetersTab().tabItem { Label("Meters", systemImage: "list.bullet") }
            AlertsTab().tabItem { Label("Alerts", systemImage: "bell") }
        }
        .frame(width: 400, height: 260)
    }
}

private struct MenuBarTab: View {
    @AppStorage(Prefs.headline)    private var headline = MeterKey.sevenDay.rawValue
    @AppStorage(Prefs.showPercent) private var showPercent = true
    @AppStorage(Prefs.showReset)   private var showReset = true
    @AppStorage(Prefs.showDot)     private var showDot = true

    var body: some View {
        Form {
            Picker("Show in menu bar", selection: $headline) {
                ForEach(MeterKey.allCases) { Text($0.displayName).tag($0.rawValue) }
                Text("Most-constrained").tag("mostConstrained")
            }
            Toggle("Percentage", isOn: $showPercent)
            Toggle("Reset countdown", isOn: $showReset)
            Toggle("Colored status dot", isOn: $showDot)
            Text("“Most-constrained” shows whichever meter is closest to its limit.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct MetersTab: View {
    @AppStorage(Prefs.showKey(.fiveHour))       private var sFive = true
    @AppStorage(Prefs.showKey(.sevenDay))       private var sWeek = true
    @AppStorage(Prefs.showKey(.sevenDayOpus))   private var sOpus = true
    @AppStorage(Prefs.showKey(.sevenDaySonnet)) private var sSonnet = true
    @AppStorage(Prefs.showExtra)                private var sExtra = true

    var body: some View {
        Form {
            Section("Show in the dropdown") {
                Toggle(MeterKey.fiveHour.displayName, isOn: $sFive)
                Toggle(MeterKey.sevenDay.displayName, isOn: $sWeek)
                Toggle(MeterKey.sevenDayOpus.displayName, isOn: $sOpus)
                Toggle(MeterKey.sevenDaySonnet.displayName, isOn: $sSonnet)
                Toggle("Extra usage (overflow credits)", isOn: $sExtra)
            }
            Text("Enabled meters always appear; one with no usage this period shows as “no usage.”")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct AlertsTab: View {
    @AppStorage(Prefs.notifyEnabled)   private var notify = true
    @AppStorage(Prefs.notifyThreshold) private var threshold = 90.0

    var body: some View {
        Form {
            Toggle("Notify me when usage is high", isOn: $notify)
            HStack {
                Text("Alert at")
                Slider(value: $threshold, in: 50...100, step: 5)
                Text("\(Int(threshold))%").monospacedDigit().frame(width: 44, alignment: .trailing)
            }
            .disabled(!notify)
            Text("Fires once per reset window when any meter crosses the threshold.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
