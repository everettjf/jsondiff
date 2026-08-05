import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class JSONDiffModel {
    var leftJSON = ""
    var rightJSON = ""
    var result: JSONDiffResult?
    var errorMessage: String?
    var isComparing = false

    var isShowingDiff: Bool { result != nil }

    func compare() async {
        guard !isComparing else { return }
        isComparing = true
        errorMessage = nil
        let left = leftJSON
        let right = rightJSON

        do {
            let output = try await Task.detached(priority: .userInitiated) {
                try JSONDiffEngine.analyze(left: left, right: right)
            }.value
            result = output
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
        isComparing = false
    }

    func clear() {
        leftJSON = ""
        rightJSON = ""
        result = nil
        errorMessage = nil
    }

    func edit() {
        result = nil
    }

    func swapInputs() {
        (leftJSON, rightJSON) = (rightJSON, leftJSON)
        result = nil
    }

    func setText(_ text: String, for side: EditorSide) {
        switch side {
        case .left: leftJSON = text
        case .right: rightJSON = text
        }
        result = nil
    }

    func loadDemo() {
        leftJSON = Self.demoLeft
        rightJSON = Self.demoRight
        result = nil
        errorMessage = nil
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

enum EditorSide: Hashable, Sendable {
    case left
    case right
}

struct ContentView: View {
    @State private var model = JSONDiffModel()
    @State private var importSide: EditorSide = .left
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = PlainTextDocument(text: "")
    @FocusState private var focusedEditor: EditorSide?

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(result: model.result)
            Divider()

            Group {
                if let result = model.result {
                    DiffResultView(result: result)
                } else {
                    editorPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            ActionBar(
                hasInput: !model.leftJSON.isEmpty || !model.rightJSON.isEmpty,
                result: model.result,
                isComparing: model.isComparing,
                clear: model.clear,
                loadDemo: loadDemo,
                swap: model.swapInputs,
                edit: edit,
                copyResult: copyResult,
                exportResult: prepareExport,
                compare: { Task { await model.compare() } }
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Unable to Compare", isPresented: errorBinding) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            load(url, for: importSide)
        }
        .fileDialogMessage("Choose a UTF-8 JSON document")
        .fileDialogConfirmationLabel("Open JSON")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "MyJSONDiff.txt"
        ) { result in
            if case let .failure(error) = result {
                model.errorMessage = error.localizedDescription
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .compareJSON)) { _ in
            Task { await model.compare() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearJSON)) { _ in model.clear() }
        .onReceive(NotificationCenter.default.publisher(for: .swapJSON)) { _ in model.swapInputs() }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private var editorPane: some View {
        HSplitView {
            JSONEditor(title: "Original JSON", text: $model.leftJSON, side: .left, openFile: openFile, reportError: reportError)
                .focused($focusedEditor, equals: .left)
            JSONEditor(title: "Modified JSON", text: $model.rightJSON, side: .right, openFile: openFile, reportError: reportError)
                .focused($focusedEditor, equals: .right)
        }
        .defaultFocus($focusedEditor, .left)
    }

    private func loadDemo() {
        model.loadDemo()
        focusedEditor = .left
    }

    private func edit() {
        model.edit()
        focusedEditor = .left
    }

    private func openFile(for side: EditorSide) {
        importSide = side
        isImporting = true
    }

    private func load(_ url: URL, for side: EditorSide) {
        Task {
            do {
                model.setText(try await JSONFileLoader.load(from: url), for: side)
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private func reportError(_ message: String) {
        model.errorMessage = message
    }

    private func copyResult() {
        guard let result = model.result else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.exportText, forType: .string)
    }

    private func prepareExport() {
        guard let result = model.result else { return }
        exportDocument = PlainTextDocument(text: result.exportText)
        isExporting = true
    }
}

private struct AppHeader: View {
    let result: JSONDiffResult?

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("MyJSONDiff")
                    .font(.headline)
                Text(result == nil ? "Compare JSON locally with formatting noise removed" : "Keys sorted · values and array order preserved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let summary = result?.summary {
                if summary.isIdentical {
                    Label("Identical", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("\(summary.changes) changes")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct JSONEditor: View {
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
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    Task {
                        do {
                            text = try await JSONFileLoader.load(from: url)
                        } catch {
                            reportError(error.localizedDescription)
                        }
                    }
                    return true
                } isTargeted: { isDropTarget = $0 }
        }
        .padding(12)
        .frame(minWidth: 340)
    }

    private var byteCount: Int64 { Int64(text.utf8.count) }
}

private struct ActionBar: View {
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

private struct DiffResultView: View {
    let result: JSONDiffResult
    @State private var showsUnchanged = true

    private var visibleRows: [DiffRow] {
        showsUnchanged ? result.rows : result.rows.filter { $0.kind != .unchanged }
    }

    var body: some View {
        VStack(spacing: 0) {
            DiffSummaryBar(summary: result.summary, showsUnchanged: $showsUnchanged)
            Divider()
            HStack(spacing: 0) {
                DiffHeader(title: "Original (Sorted)")
                Divider()
                DiffHeader(title: "Modified (Sorted)")
            }
            .frame(height: 34)
            Divider()
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(visibleRows) { row in
                            DiffRowView(row: row)
                        }
                    }
                    .frame(minWidth: max(geometry.size.width, 1_040), alignment: .leading)
                }
            }
        }
    }
}

private struct DiffSummaryBar: View {
    let summary: DiffSummary
    @Binding var showsUnchanged: Bool

    var body: some View {
        HStack(spacing: 14) {
            SummaryBadge(label: "Modified", value: summary.modified, color: .orange)
            SummaryBadge(label: "Added", value: summary.added, color: .green)
            SummaryBadge(label: "Removed", value: summary.removed, color: .red)
            SummaryBadge(label: "Unchanged", value: summary.unchanged, color: .secondary)
            Spacer()
            Toggle("Show unchanged", isOn: $showsUnchanged)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct SummaryBadge: View {
    let label: LocalizedStringKey
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
            Text(value, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

private struct DiffHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 520, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

private struct DiffRowView: View {
    let row: DiffRow

    var body: some View {
        HStack(spacing: 0) {
            DiffLine(
                number: row.leftLineNumber,
                text: row.left,
                counterpart: row.right,
                kind: row.kind,
                side: .left
            )
            Divider()
            DiffLine(
                number: row.rightLineNumber,
                text: row.right,
                counterpart: row.left,
                kind: row.kind,
                side: .right
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        switch row.kind {
        case .unchanged: "Unchanged: \(row.left)"
        case .removed: "Removed from line \(row.leftLineNumber ?? 0): \(row.left)"
        case .added: "Added at line \(row.rightLineNumber ?? 0): \(row.right)"
        case .modified: "Changed from \(row.left) to \(row.right)"
        }
    }
}

private struct DiffLine: View {
    let number: Int?
    let text: String
    let counterpart: String
    let kind: DiffKind
    let side: EditorSide

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.tertiary)
                .frame(width: 42, alignment: .trailing)
            highlightedText
                .textSelection(.enabled)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(minWidth: 520, maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
    }

    private var highlightedText: Text {
        guard kind == .modified else { return Text(verbatim: text.isEmpty ? " " : text) }
        let segments = LineChangeSegments(text: text, counterpart: counterpart)
        return Text(verbatim: segments.prefix)
            + Text(verbatim: segments.change.isEmpty ? " " : segments.change)
                .foregroundStyle(side == .left ? Color.red : Color.green)
                .bold()
            + Text(verbatim: segments.suffix)
    }

    private var backgroundColor: Color {
        switch kind {
        case .unchanged: .clear
        case .removed: side == .left ? .red.opacity(0.16) : .clear
        case .added: side == .right ? .green.opacity(0.16) : .clear
        case .modified: .orange.opacity(0.14)
        }
    }
}

private struct LineChangeSegments {
    let prefix: String
    let change: String
    let suffix: String

    init(text: String, counterpart: String) {
        let characters = Array(text)
        let other = Array(counterpart)
        var prefixCount = 0
        while prefixCount < min(characters.count, other.count), characters[prefixCount] == other[prefixCount] {
            prefixCount += 1
        }

        var suffixCount = 0
        while suffixCount < min(characters.count - prefixCount, other.count - prefixCount),
              characters[characters.count - suffixCount - 1] == other[other.count - suffixCount - 1] {
            suffixCount += 1
        }

        prefix = String(characters.prefix(prefixCount))
        change = String(characters.dropFirst(prefixCount).dropLast(suffixCount))
        suffix = String(characters.suffix(suffixCount))
    }
}

private struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private extension JSONDiffResult {
    var exportText: String {
        var output = "MyJSONDiff Report\n"
        output += "Modified: \(summary.modified)  Added: \(summary.added)  Removed: \(summary.removed)\n\n"
        for row in rows where row.kind != .unchanged {
            switch row.kind {
            case .modified:
                output += "~ L\(row.leftLineNumber ?? 0): \(row.left)\n"
                output += "~ R\(row.rightLineNumber ?? 0): \(row.right)\n"
            case .removed:
                output += "- L\(row.leftLineNumber ?? 0): \(row.left)\n"
            case .added:
                output += "+ R\(row.rightLineNumber ?? 0): \(row.right)\n"
            case .unchanged:
                break
            }
        }
        return output
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 760)
}
