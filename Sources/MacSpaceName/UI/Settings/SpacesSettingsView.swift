import SwiftUI
import KeyboardShortcuts
import MacSpaceNameCore

struct SpacesSettingsView: View {
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var spaces: SpaceService

    var body: some View {
        Form {
            ForEach(spaces.snapshot.displays, id: \.identifier) { display in
                Section(spaces.snapshot.displays.count > 1 ? DisplayInfo.name(forIdentifier: display.identifier) : "Spaces") {
                    ForEach(display.desktops, id: \.key) { space in
                        SpaceSettingsRow(space: space)
                    }
                }
            }
            if spaces.snapshot.desktops.isEmpty {
                Section {
                    Text("No desktops found. Is this macOS version supported?").foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Names, icons and colors are stored per Space (by its UUID) in config.json, so they survive restarts and reordering. "
                     + "Full-screen apps appear under their app name and cannot be renamed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct SpaceSettingsRow: View {
    let space: SpaceInfo
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var spaces: SpaceService
    @Environment(\.appActions) private var actions

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: config.spaceConfig(for: space.key).color) ?? Color.gray },
            set: { newValue in config.update(space.key) { $0.color = NSColor(newValue).hexString } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(space.desktopNumber ?? space.indexOnDisplay)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 22, alignment: .trailing)
                IconField(icon: config.spaceTextBinding(space.key, \.icon), color: spaces.color(for: space))
                TextField(spaces.defaultName(for: space), text: config.spaceTextBinding(space.key, \.name))
                    .textFieldStyle(.roundedBorder)
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                Menu {
                    ForEach(SpacePalette.presets, id: \.self) { hex in
                        Button {
                            config.update(space.key) { $0.color = hex }
                        } label: {
                            Label(hex, systemImage: "circle.fill")
                        }
                    }
                    Divider()
                    Button("No color") { config.update(space.key) { $0.color = nil } }
                } label: {
                    Image(systemName: "paintpalette")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 34)
                if space.isCurrentOnDisplay {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).help("Current space")
                }
            }
            HStack(spacing: 12) {
                ShortcutRecorder("Shortcut:", name: .space(space.key))
                Picker("On enter:", selection: config.spaceBinding(space.key, \.onEnterGroupID)) {
                    Text("Nothing").tag(UUID?.none)
                    ForEach(config.config.actionGroups) { group in
                        Text(group.name).tag(Optional(group.id))
                    }
                }
                .frame(maxWidth: 230)
                Spacer()
                Button("Notes…") { actions.openNotes(space.key) }
                Button("Reset") {
                    config.update(space.key) { $0.name = nil; $0.icon = nil; $0.color = nil }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A short text field for an emoji / SF Symbol name plus a menu of suggestions.
struct IconField: View {
    @Binding var icon: String
    var color: NSColor?

    var body: some View {
        HStack(spacing: 4) {
            TextField("Icon", text: $icon)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
            Menu {
                ForEach(SpaceIcon.suggestions, id: \.self) { suggestion in
                    Button {
                        icon = suggestion
                    } label: {
                        if let resolved = SpaceIcon(string: suggestion), case .symbol(let name) = resolved {
                            Label(name, systemImage: name)
                        } else {
                            Text(suggestion)
                        }
                    }
                }
                Divider()
                Button("No icon") { icon = "" }
            } label: {
                SpaceIconView(icon: SpaceIcon(string: icon), color: color.map { Color(nsColor: $0) }, size: 14)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 36)
        }
        .help("Type an emoji (💼) or an SF Symbol name (briefcase.fill)")
    }
}
