import AppKit
import Carbon
import SwiftUI
import KeyboardShortcuts

/// Records a global shortcut for a `KeyboardShortcuts.Name`.
///
/// Used instead of `KeyboardShortcuts.Recorder`: that view loads its localized strings from the library's
/// SwiftPM resource bundle, which `make bundle` does not (and, because of code signing, cannot) place where
/// SwiftPM looks for it, so the app hit a `fatalError` as soon as a recorder appeared. This view only uses
/// the library's storage API, which needs no resources.
struct ShortcutRecorder: View {
    let title: String
    let name: KeyboardShortcuts.Name

    @State private var shortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording = false
    @State private var monitor: Any?

    init(_ title: String, name: KeyboardShortcuts.Name) {
        self.title = title
        self.name = name
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                Button(action: toggleRecording) {
                    Text(label)
                        .frame(minWidth: 110)
                        .foregroundStyle(isRecording ? Color.accentColor : (shortcut == nil ? Color.secondary : Color.primary))
                }
                if shortcut != nil, !isRecording {
                    Button {
                        set(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove shortcut")
                }
            }
        }
        .onAppear { shortcut = KeyboardShortcuts.getShortcut(for: name) }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return "Type shortcut…" }
        guard let shortcut else { return "Record Shortcut" }
        return ShortcutFormatter.string(for: shortcut)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = Int(event.keyCode)
        if modifiers.isEmpty, keyCode == kVK_Escape {
            stopRecording()
            return
        }
        if modifiers.isEmpty, keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
            set(nil)
            stopRecording()
            return
        }
        // Without ⌘, ⌥ or ⌃ a global shortcut would swallow ordinary typing; function keys are the exception.
        let isFunctionKey = ShortcutFormatter.functionKeys[keyCode] != nil
        guard !modifiers.subtracting(.shift).isEmpty || isFunctionKey,
              let recorded = KeyboardShortcuts.Shortcut(event: event) else {
            NSSound.beep()
            return
        }
        set(recorded)
        stopRecording()
    }

    private func set(_ value: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(value, for: name)
        shortcut = value
    }
}

/// Human-readable shortcut text ("⌥Space", "⌃⌘K") built without the library's localized resources.
enum ShortcutFormatter {
    static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    static func string(for shortcut: KeyboardShortcuts.Shortcut) -> String {
        var text = ""
        let modifiers = shortcut.modifiers
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        let code = shortcut.carbonKeyCode
        if let name = specialKeys[code] ?? functionKeys[code] { return text + name }
        return text + (character(forKeyCode: code) ?? "#\(code)")
    }

    /// The character the key produces on the current keyboard layout (so "Z" on a QWERTZ keyboard is right).
    static func character(forKeyCode keyCode: Int) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
