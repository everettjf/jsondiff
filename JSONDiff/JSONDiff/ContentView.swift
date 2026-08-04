import Observation
import SwiftUI

@Observable
@MainActor
final class JSONDiffModel {
    var leftJSON = ""
    var rightJSON = ""
    var rows: [DiffRow] = []
    var errorMessage: String?
    var isShowingDiff = false

    var changeCount: Int {
        rows.lazy.filter { $0.kind != .unchanged }.count
    }

    func compare() {
        do {
            leftJSON = JSONDiffEngine.normalizeQuotes(in: leftJSON)
            rightJSON = JSONDiffEngine.normalizeQuotes(in: rightJSON)
            rows = try JSONDiffEngine.compare(left: leftJSON, right: rightJSON)
            errorMessage = nil
            isShowingDiff = true
        } catch {
            rows = []
            errorMessage = error.localizedDescription
            isShowingDiff = false
        }
    }

    func clear() {
        leftJSON = ""
        rightJSON = ""
        rows = []
        errorMessage = nil
        isShowingDiff = false
    }

    func loadDemo() {
        leftJSON = Self.demoLeft
        rightJSON = Self.demoRight
        rows = []
        errorMessage = nil
        isShowingDiff = false
    }

    private static let demoLeft = """
    {
      "name": "Product A",
      "price": 19.99,
      "features": ["Durable", "Waterproof", "Lightweight"],
      "specs": { "weight": 2.5, "color": "blue", "dimensions": { "height": 10, "width": 15, "depth": 5 } },
      "inStock": true,
      "categories": ["electronics", "accessories"]
    }
    """

    private static let demoRight = """
    {
      "name": "Product A",
      "price": 24.99,
      "features": ["Durable", "Waterproof", "Eco-friendly"],
      "specs": { "weight": 2.2, "color": "green", "dimensions": { "height": 10, "width": 15, "depth": 6 } },
      "inStock": true,
      "categories": ["electronics", "accessories", "outdoor"],
      "discount": 10
    }
    """
}

struct ContentView: View {
    @State private var model = JSONDiffModel()
    @FocusState private var focusedEditor: EditorSide?

    private enum EditorSide: Hashable {
        case left
        case right
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                if model.isShowingDiff {
                    DiffResultView(rows: model.rows)
                } else {
                    editorPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            actionBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to Compare", isPresented: errorBinding) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: .compareJSON)) { _ in model.compare() }
        .onReceive(NotificationCenter.default.publisher(for: .clearJSON)) { _ in model.clear() }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "curlybraces.square")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MyJSONDiff")
                    .font(.headline)
                Text(model.isShowingDiff ? "Sorted, order-insensitive comparison" : "Paste two JSON documents to compare")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isShowingDiff {
                Text("\(model.changeCount) changed lines")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var editorPane: some View {
        HSplitView {
            JSONEditor(title: "Left JSON", text: $model.leftJSON)
                .focused($focusedEditor, equals: .left)
            JSONEditor(title: "Right JSON", text: $model.rightJSON)
                .focused($focusedEditor, equals: .right)
        }
        .defaultFocus($focusedEditor, .left)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Clear All", systemImage: "trash", role: .destructive) {
                model.clear()
            }
            .disabled(model.leftJSON.isEmpty && model.rightJSON.isEmpty)

            Button("Demo", systemImage: "sparkles") {
                model.loadDemo()
                focusedEditor = .left
            }

            Spacer()

            if model.isShowingDiff {
                Button("Edit", systemImage: "pencil") {
                    model.isShowingDiff = false
                    focusedEditor = .left
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            Button("Compare JSON", systemImage: "arrow.left.arrow.right") {
                model.compare()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(12)
    }
}

private struct JSONEditor: View {
    let title: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 1)
                }
                .accessibilityLabel(title)
        }
        .padding(12)
        .frame(minWidth: 300)
    }
}

private struct DiffResultView: View {
    let rows: [DiffRow]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                DiffHeader(title: "Original (Sorted)")
                Divider()
                DiffHeader(title: "Modified (Sorted)")
            }
            Divider()
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        DiffRowView(row: row)
                    }
                }
            }
        }
    }
}

private struct DiffHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

private struct DiffRowView: View {
    let row: DiffRow

    var body: some View {
        HStack(spacing: 0) {
            DiffLine(number: row.leftLineNumber, text: row.left, kind: row.kind == .removed ? .removed : .unchanged)
            Divider()
            DiffLine(number: row.rightLineNumber, text: row.right, kind: row.kind == .added ? .added : .unchanged)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        switch row.kind {
        case .unchanged: "Unchanged: \(row.left)"
        case .removed: "Removed from line \(row.leftLineNumber ?? 0): \(row.left)"
        case .added: "Added at line \(row.rightLineNumber ?? 0): \(row.right)"
        }
    }
}

private struct DiffLine: View {
    let number: Int?
    let text: String
    let kind: DiffKind

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
            Text(text.isEmpty ? " " : text)
                .textSelection(.enabled)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(minWidth: 480, maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        switch kind {
        case .unchanged: .clear
        case .removed: .red.opacity(0.18)
        case .added: .green.opacity(0.18)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 700)
}
