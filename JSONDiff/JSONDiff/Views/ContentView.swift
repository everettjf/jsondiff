import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = JSONDiffModel()
    @State private var importSide: EditorSide = .left
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = PlainTextDocument(text: "")
    @FocusState private var focusedEditor: EditorSide?

    var body: some View {
        VStack(spacing: 0) {
            StatusHeader(result: model.result)
            Divider()
            content
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
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .fileDialogMessage("Choose a UTF-8 JSON document")
        .fileDialogConfirmationLabel("Open JSON")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "MyJSONDiff.txt",
            onCompletion: handleExport
        )
        .onReceive(NotificationCenter.default.publisher(for: .compareJSON)) { _ in compare() }
        .onReceive(NotificationCenter.default.publisher(for: .clearJSON)) { _ in model.clear() }
        .onReceive(NotificationCenter.default.publisher(for: .swapJSON)) { _ in model.swapInputs() }
    }

    @ViewBuilder
    private var content: some View {
        if let result = model.result {
            DiffResultView(result: result)
        } else {
            HSplitView {
                JSONEditor(title: "Original JSON", text: $model.leftJSON, side: .left, openFile: openFile, reportError: reportError)
                    .focused($focusedEditor, equals: .left)
                JSONEditor(title: "Modified JSON", text: $model.rightJSON, side: .right, openFile: openFile, reportError: reportError)
                    .focused($focusedEditor, equals: .right)
            }
            .defaultFocus($focusedEditor, .left)
        }
    }

    private var actionBar: some View {
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
            compare: compare
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private func compare() {
        Task { await model.compare() }
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

    private func handleImport(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        Task {
            do {
                model.setText(try await JSONFileLoader.load(from: url), for: importSide)
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private func handleExport(_ result: Result<URL, any Error>) {
        if case let .failure(error) = result {
            model.errorMessage = error.localizedDescription
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

#Preview {
    ContentView()
        .frame(width: 1180, height: 760)
}
