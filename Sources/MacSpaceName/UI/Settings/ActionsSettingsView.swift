import SwiftUI
import UniformTypeIdentifiers
import MacSpaceNameCore

struct ActionsSettingsView: View {
    @EnvironmentObject var config: ConfigStore
    @Environment(\.appActions) private var actions
    @State private var selectedID: UUID?

    private var groups: [ActionGroup] { config.config.actionGroups }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selectedID) {
                    ForEach(groups) { group in
                        Label(group.name.isEmpty ? "Untitled" : group.name, systemImage: "play.rectangle")
                            .tag(group.id)
                    }
                }
                HStack(spacing: 0) {
                    Button { addGroup() } label: { Image(systemName: "plus") }
                    Button { removeSelected() } label: { Image(systemName: "minus") }
                        .disabled(selectedID == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 200)

            Divider()

            if let id = selectedID, let index = groups.firstIndex(where: { $0.id == id }) {
                ActionGroupEditor(group: Binding(
                    get: { config.config.actionGroups[safe: index] ?? ActionGroup(name: "") },
                    set: { value in
                        if config.config.actionGroups.indices.contains(index) {
                            config.config.actionGroups[index] = value
                        }
                    }
                ))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("Action groups").font(.headline)
                    Text("A group opens apps, folders and URLs, runs Apple Shortcuts or shell commands — from the menu bar (▶) or automatically when you enter a Space (Spaces tab → “On enter”).")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.horizontal, 24)
                    Button("Create a group") { addGroup() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func addGroup() {
        let group = ActionGroup(name: "New group", items: [ActionItem()])
        config.config.actionGroups.append(group)
        selectedID = group.id
    }

    private func removeSelected() {
        guard let id = selectedID else { return }
        config.config.actionGroups.removeAll { $0.id == id }
        for key in config.config.spaces.keys where config.config.spaces[key]?.onEnterGroupID == id {
            config.config.spaces[key]?.onEnterGroupID = nil
        }
        selectedID = nil
    }
}

struct ActionGroupEditor: View {
    @Binding var group: ActionGroup
    @Environment(\.appActions) private var actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Group name", text: $group.name).textFieldStyle(.roundedBorder)
                Button {
                    actions.runGroup(group)
                } label: {
                    Label("Run now", systemImage: "play.fill")
                }
            }
            Text("Steps run in order.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($group.items) { $item in
                        HStack(spacing: 6) {
                            Picker("", selection: $item.kind) {
                                ForEach(ActionKind.allCases, id: \.self) { Text($0.title) }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                            TextField(item.kind.placeholder, text: $item.value).textFieldStyle(.roundedBorder)
                            if item.kind == .openApp || item.kind == .openPath {
                                Button("…") { browse(for: $item) }
                            }
                            Button {
                                group.items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            Button {
                group.items.append(ActionItem())
            } label: {
                Label("Add step", systemImage: "plus")
            }
            Spacer()
            Text("Tip: to turn on a Focus mode when entering a Space, create an Apple Shortcut that sets the Focus and run it from here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func browse(for item: Binding<ActionItem>) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if item.wrappedValue.kind == .openApp {
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        } else {
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        item.wrappedValue.value = url.path
    }
}
