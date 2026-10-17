import AppKit
import SwiftUI

/// A space icon is either an SF Symbol name ("briefcase.fill") or free text, usually an emoji ("💼").
enum SpaceIcon: Equatable {
    case symbol(String)
    case text(String)

    init?(string: String?) {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let looksLikeSymbolName = raw.unicodeScalars.allSatisfy { $0.isASCII } && !raw.contains(" ")
            && raw.rangeOfCharacter(from: .letters) != nil
        if looksLikeSymbolName, NSImage(systemSymbolName: raw, accessibilityDescription: nil) != nil {
            self = .symbol(raw)
        } else {
            self = .text(raw)
        }
    }

    var text: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    var symbolName: String? {
        if case .symbol(let value) = self { return value }
        return nil
    }

    /// An AppKit image for the icon. Symbols are tinted with `color` (template when `nil`); text becomes a glyph image.
    func nsImage(color: NSColor?, pointSize: CGFloat) -> NSImage? {
        switch self {
        case .symbol(let name):
            guard let base = NSImage(systemSymbolName: name, accessibilityDescription: name) else { return nil }
            var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
            if let color {
                configuration = configuration.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
            }
            let image = base.withSymbolConfiguration(configuration) ?? base
            image.isTemplate = color == nil
            return image
        case .text(let value):
            let font = NSFont.systemFont(ofSize: pointSize)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (value as NSString).size(withAttributes: attributes)
            let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { rect in
                (value as NSString).draw(in: rect, withAttributes: attributes)
                return true
            }
            image.isTemplate = false
            return image
        }
    }

    /// Suggested icons shown in Settings.
    static let suggestions: [String] = [
        "💼", "🏠", "💻", "🎨", "🎵", "📚", "🧪", "🎮", "💬", "📈", "✉️", "🧘", "🎬", "📝", "🛠️", "🌍",
        "briefcase.fill", "house.fill", "terminal.fill", "paintbrush.fill", "music.note", "book.fill",
        "gamecontroller.fill", "bubble.left.fill", "chart.line.uptrend.xyaxis", "envelope.fill", "globe", "star.fill",
    ]
}

/// SwiftUI rendering of a `SpaceIcon`.
struct SpaceIconView: View {
    let icon: SpaceIcon?
    var color: Color?
    var size: CGFloat = 16

    var body: some View {
        Group {
            switch icon {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(color ?? Color.primary)
            case .text(let value):
                Text(value).font(.system(size: size))
            case nil:
                Circle()
                    .fill(color ?? Color.secondary.opacity(0.4))
                    .frame(width: size * 0.6, height: size * 0.6)
            }
        }
        .frame(width: size + 6, height: size + 6)
    }
}
