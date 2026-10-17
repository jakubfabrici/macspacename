import Foundation

/// A continuous interval spent on one space in one app.
public struct TimeEntry: Codable, Identifiable, Hashable {
    public var id: UUID
    public var spaceKey: String
    public var spaceName: String
    public var appBundleID: String?
    public var appName: String?
    /// Optional user-provided session label ("Client X invoice").
    public var session: String?
    public var start: Date
    public var end: Date

    public init(
        id: UUID = UUID(),
        spaceKey: String,
        spaceName: String,
        appBundleID: String? = nil,
        appName: String? = nil,
        session: String? = nil,
        start: Date,
        end: Date
    ) {
        self.id = id
        self.spaceKey = spaceKey
        self.spaceName = spaceName
        self.appBundleID = appBundleID
        self.appName = appName
        self.session = session
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

public struct TimeLog: Codable, Hashable {
    public var entries: [TimeEntry]
    public init(entries: [TimeEntry] = []) { self.entries = entries }
}

public enum TimeRange: String, CaseIterable, Hashable {
    case today, thisWeek, all

    public var title: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .all: return "All time"
        }
    }

    public func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .all:
            return nil
        }
    }
}

public struct TimeTotal: Identifiable, Hashable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let seconds: TimeInterval

    public init(key: String, label: String, seconds: TimeInterval) {
        self.key = key
        self.label = label
        self.seconds = seconds
    }
}

public enum TimeAggregator {
    public enum Grouping: String, CaseIterable, Hashable {
        case space, app, session

        public var title: String {
            switch self {
            case .space: return "Space"
            case .app: return "App"
            case .session: return "Session"
            }
        }
    }

    /// Sums durations, clipping entries to the requested range (entries can span midnight).
    public static func totals(
        _ entries: [TimeEntry],
        by grouping: Grouping,
        in range: TimeRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TimeTotal] {
        let interval = range.interval(now: now, calendar: calendar)
        var seconds: [String: TimeInterval] = [:]
        var labels: [String: String] = [:]
        for entry in entries {
            let duration = clippedDuration(of: entry, to: interval)
            guard duration > 0 else { continue }
            let key: String
            let label: String
            switch grouping {
            case .space:
                key = entry.spaceKey
                label = entry.spaceName
            case .app:
                key = entry.appBundleID ?? entry.appName ?? "unknown"
                label = entry.appName ?? entry.appBundleID ?? "Unknown app"
            case .session:
                key = entry.session ?? ""
                label = entry.session ?? "No session"
            }
            seconds[key, default: 0] += duration
            labels[key] = label
        }
        return seconds
            .map { TimeTotal(key: $0.key, label: labels[$0.key] ?? $0.key, seconds: $0.value) }
            .sorted { $0.seconds > $1.seconds }
    }

    public static func total(_ entries: [TimeEntry], in range: TimeRange, now: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        let interval = range.interval(now: now, calendar: calendar)
        return entries.reduce(0) { $0 + clippedDuration(of: $1, to: interval) }
    }

    static func clippedDuration(of entry: TimeEntry, to interval: DateInterval?) -> TimeInterval {
        guard let interval else { return entry.duration }
        let start = max(entry.start, interval.start)
        let end = min(entry.end, interval.end)
        return max(0, end.timeIntervalSince(start))
    }

    /// "2h 05m", "45m", "<1m"
    public static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return "\(minutes)m" }
        return total > 0 ? "<1m" : "0m"
    }
}

public enum CSVExporter {
    public static let header = "start,end,duration_seconds,space,space_key,app,app_bundle_id,session"

    public static func csv(for entries: [TimeEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [header]
        for entry in entries.sorted(by: { $0.start < $1.start }) {
            let fields = [
                formatter.string(from: entry.start),
                formatter.string(from: entry.end),
                String(Int(entry.duration.rounded())),
                entry.spaceName,
                entry.spaceKey,
                entry.appName ?? "",
                entry.appBundleID ?? "",
                entry.session ?? "",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
