import AppKit
import SwiftUI
import MacSpaceNameCore

struct TimeTrackingView: View {
    @EnvironmentObject var tracker: TimeTracker
    @EnvironmentObject var config: ConfigStore
    @State private var range: TimeRange = .today
    @State private var grouping: TimeAggregator.Grouping = .space

    var body: some View {
        let totals = tracker.totals(by: grouping, in: range)
        let overall = tracker.total(in: range)
        let maxSeconds = totals.map(\.seconds).max() ?? 1

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $range) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.title) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                Spacer()
                Picker("Group by", selection: $grouping) {
                    ForEach(TimeAggregator.Grouping.allCases, id: \.self) { Text($0.title) }
                }
                .frame(maxWidth: 180)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(TimeAggregator.format(overall)).font(.system(size: 28, weight: .bold).monospacedDigit())
                Text("tracked \(range.title.lowercased())").foregroundStyle(.secondary)
                Spacer()
                statusLabel
                if config.config.settings.timeTracking {
                    Button(tracker.isPaused ? "Resume" : "Pause") { tracker.isPaused.toggle() }
                }
            }

            TextField("Session name (optional, e.g. “Client X – invoice 42”)", text: $tracker.sessionName)
                .textFieldStyle(.roundedBorder)

            if totals.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text(config.config.settings.timeTracking ? "Nothing tracked yet for this period." : "Time tracking is turned off in Settings.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                List(totals) { total in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(total.label).lineLimit(1)
                            Spacer()
                            Text(TimeAggregator.format(total.seconds)).monospacedDigit().foregroundStyle(.secondary)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15))
                                Capsule().fill(Color.accentColor.opacity(0.7))
                                    .frame(width: max(4, proxy.size.width * CGFloat(total.seconds / maxSeconds)))
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack {
                Button("Export CSV…") { tracker.exportCSVWithPanel() }
                Button("Clear log…") {
                    if RenamePrompt.confirm(title: "Clear the time log?", message: "All tracked time will be deleted. Export it first if you need it.", button: "Clear", destructive: true) {
                        tracker.clearLog()
                    }
                }
                Spacer()
                Text(tracker.fileURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 440)
    }

    private var statusText: String {
        if !config.config.settings.timeTracking { return "Off" }
        if tracker.isPaused { return "Paused" }
        if tracker.isIdle { return "Idle" }
        return "Tracking"
    }

    private var statusColor: Color {
        if !config.config.settings.timeTracking { return .secondary }
        if tracker.isPaused { return .orange }
        if tracker.isIdle { return .secondary }
        return .green
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusText).foregroundStyle(.secondary)
        }
    }
}

@MainActor
final class TimeTrackingWindowController {
    private weak var app: AppContainer!
    private var window: NSWindow?

    func attach(to app: AppContainer) {
        self.app = app
    }

    func show() {
        let window = self.window ?? WindowFactory.make(
            title: "Time Tracking",
            size: NSSize(width: 600, height: 480),
            content: TimeTrackingView()
                .environmentObject(app.tracker)
                .environmentObject(app.config)
        )
        self.window = window
        WindowFactory.present(window)
    }
}
