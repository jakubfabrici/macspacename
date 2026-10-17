import SwiftUI
import MacSpaceNameCore

struct TimeTrackingSettingsView: View {
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var tracker: TimeTracker
    @Environment(\.appActions) private var actions

    var body: some View {
        Form {
            Section("Tracking") {
                Toggle("Track time per Space and app automatically", isOn: config.binding(\.settings.timeTracking))
                Stepper(value: config.binding(\.settings.idleMinutes), in: 1...60) {
                    Text("Count as idle after \(config.config.settings.idleMinutes) min without input")
                }
                Text("Tracking switches with you: every change of Space or frontmost app starts a new entry. "
                     + "Idle time is cut out automatically. Nothing ever leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Today") {
                HStack {
                    Text(TimeAggregator.format(tracker.total(in: .today))).font(.title2.monospacedDigit())
                    Spacer()
                    Button("Open Time Tracking…") { actions.openTimeTracking() }
                    Button("Export CSV…") { actions.exportCSV() }
                }
            }
            Section("Data") {
                HStack {
                    Button("Clear log…") {
                        if RenamePrompt.confirm(title: "Clear the time log?", message: "All tracked time will be deleted.", button: "Clear", destructive: true) {
                            actions.clearTimeLog()
                        }
                    }
                    Spacer()
                    Text(tracker.fileURL.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
        }
        .formStyle(.grouped)
    }
}
