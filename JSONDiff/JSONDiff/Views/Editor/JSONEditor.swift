import SwiftUI

struct JSONEditor: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let side: EditorSide
    let openFile: (EditorSide) -> Void
    let reportError: (String) -> Void
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(byteCount, format: .byteCount(style: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Button("Open…", systemImage: "doc") { openFile(side) }
                    .controlSize(.small)
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isDropTarget ? Color.accentColor : Color.secondary.opacity(0.35),
                            lineWidth: isDropTarget ? 2 : 1
                        )
                }
                .overlay {
                    if text.isEmpty {
                        ContentUnavailableView(
                            "Paste or Drop JSON",
                            systemImage: "curlybraces",
                            description: Text("UTF-8 files up to 50 MB")
                        )
                        .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(title)
                .dropDestination(for: URL.self, action: handleDrop) { isDropTarget = $0 }
        }
        .padding(12)
        .frame(minWidth: 340)
    }

    private var byteCount: Int64 { Int64(text.utf8.count) }

    private func handleDrop(_ urls: [URL], location: CGPoint) -> Bool {
        guard let url = urls.first else { return false }
        Task {
            do {
                text = try await JSONFileLoader.load(from: url)
            } catch {
                reportError(error.localizedDescription)
            }
        }
        return true
    }
}
