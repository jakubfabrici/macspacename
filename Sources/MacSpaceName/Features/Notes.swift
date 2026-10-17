import AppKit
import SwiftUI
import MacSpaceNameCore

@MainActor
final class NotesSelection: ObservableObject {
    @Published var key: String?
}

struct NotesView: View {
    @EnvironmentObject var spaces: SpaceService
    @EnvironmentObject var config: ConfigStore
    @EnvironmentObject var selection: NotesSelection
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Space", selection: $selection.key) {
                ForEach(spaces.snapshot.desktops, id: \.key) { space in
                    Text(spaces.name(for: space)).tag(Optional(space.key))
                }
            }

            if let key = selection.key {
                Text("Notes").font(.headline)
                TextEditor(text: config.spaceBinding(key, \.notes))
                    .font(.body)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

                Text("Checklist").font(.headline)
                let items = config.spaceConfig(for: key).checklist
                if items.isEmpty {
                    Text("No items yet.").foregroundStyle(.secondary).font(.caption)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items) { item in
                            HStack {
                                Toggle("", isOn: Binding(
                                    get: { item.isDone },
                                    set: { done in
                                        config.update(key) { cfg in
                                            if let index = cfg.checklist.firstIndex(where: { $0.id == item.id }) {
                                                cfg.checklist[index].isDone = done
                                            }
                                        }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                Text(item.text)
                                    .strikethrough(item.isDone)
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                Spacer()
                                Button {
                                    config.update(key) { $0.checklist.removeAll { $0.id == item.id } }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(minHeight: 80)

                HStack {
                    TextField("Add a checklist item", text: $newItem)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addItem(to: key) }
                    Button("Add") { addItem(to: key) }
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    if items.contains(where: \.isDone) {
                        Button("Clear done") {
                            config.update(key) { $0.checklist.removeAll(where: \.isDone) }
                        }
                    }
                }
            } else {
                Text("Pick a Space to see its notes.").foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 440, minHeight: 420)
    }

    private func addItem(to key: String) {
        let text = newItem.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        config.update(key) { $0.checklist.append(ChecklistItem(text: text)) }
        newItem = ""
    }
}

@MainActor
final class NotesWindowController {
    private weak var app: AppContainer!
    private var window: NSWindow?
    private let selection = NotesSelection()

    func attach(to app: AppContainer) {
        self.app = app
    }

    func show(spaceKey: String?) {
        if let spaceKey { selection.key = spaceKey }
        if selection.key == nil { selection.key = app.spaces.activeSpace?.key }
        let window = self.window ?? WindowFactory.make(
            title: "Space Notes",
            size: NSSize(width: 480, height: 460),
            content: NotesView()
                .environmentObject(app.spaces)
                .environmentObject(app.config)
                .environmentObject(selection)
        )
        self.window = window
        WindowFactory.present(window)
    }
}
