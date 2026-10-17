import SwiftUI
import MacSpaceNameCore

extension ConfigStore {
    func binding<T>(_ keyPath: WritableKeyPath<AppConfig, T>) -> Binding<T> {
        Binding(
            get: { self.config[keyPath: keyPath] },
            set: { self.config[keyPath: keyPath] = $0 }
        )
    }

    func spaceBinding<T>(_ key: String, _ keyPath: WritableKeyPath<SpaceConfig, T>) -> Binding<T> {
        Binding(
            get: { self.spaceConfig(for: key)[keyPath: keyPath] },
            set: { value in self.update(key) { $0[keyPath: keyPath] = value } }
        )
    }

    /// Optional string fields edited as plain text; empty text clears the value.
    func spaceTextBinding(_ key: String, _ keyPath: WritableKeyPath<SpaceConfig, String?>) -> Binding<String> {
        Binding(
            get: { self.spaceConfig(for: key)[keyPath: keyPath] ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                self.update(key) { $0[keyPath: keyPath] = trimmed.isEmpty ? nil : value }
            }
        )
    }
}

/// Closures the SwiftUI settings views use to reach app-level controllers.
struct AppActions {
    var openNotes: (String?) -> Void = { _ in }
    var runGroup: (ActionGroup) -> Void = { _ in }
    var openTimeTracking: () -> Void = {}
    var exportCSV: () -> Void = {}
    var clearTimeLog: () -> Void = {}
    var openQuickSwitcher: () -> Void = {}
}

private struct AppActionsKey: EnvironmentKey {
    static let defaultValue = AppActions()
}

extension EnvironmentValues {
    var appActions: AppActions {
        get { self[AppActionsKey.self] }
        set { self[AppActionsKey.self] = newValue }
    }
}
