import SwiftUI

struct ActionBar: View {
    let hasInput: Bool
    let result: JSONDiffResult?
    let isComparing: Bool
    let clear: () -> Void
    let loadDemo: () -> Void
    let swap: () -> Void
    let edit: () -> Void
    let copyResult: () -> Void
    let exportResult: () -> Void
    let compare: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Clear All", systemImage: "trash", role: .destructive, action: clear)
                .disabled(!hasInput)
            Button("Demo", systemImage: "sparkles", action: loadDemo)

            if result == nil {
                Button("Swap", systemImage: "arrow.left.arrow.right", action: swap)
                    .disabled(!hasInput)
            }

            Spacer()

            if result != nil {
                Button("Copy Report", systemImage: "doc.on.doc", action: copyResult)
                Button("Export…", systemImage: "square.and.arrow.up", action: exportResult)
                Button("Edit", systemImage: "pencil", action: edit)
                    .keyboardShortcut("e", modifiers: .command)
            }

            Button(action: compare) {
                if isComparing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Comparing…")
                } else {
                    Label("Compare JSON", systemImage: "arrow.left.arrow.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isComparing)
        }
        .padding(12)
    }
}
