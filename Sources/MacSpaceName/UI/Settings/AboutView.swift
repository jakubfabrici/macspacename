import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("MacSpaceName").font(.largeTitle.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Name your macOS Spaces. See the name in the menu bar and Mission Control, jump by name, and track where your time goes.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/jakubfabrici/macspacename")!)
                Link("Report an issue", destination: URL(string: "https://github.com/jakubfabrici/macspacename/issues")!)
                Link("How it works", destination: URL(string: "https://github.com/jakubfabrici/macspacename/blob/main/docs/how-it-works.md")!)
            }
            Spacer().frame(height: 8)
            Text("Free and open source under the MIT License.\nInspired by SpaceJump. Techniques borrowed with thanks from WhichSpace, Spaceman and Hammerspoon.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
