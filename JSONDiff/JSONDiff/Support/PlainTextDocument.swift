import SwiftUI
import UniformTypeIdentifiers

struct PlainTextDocument: FileDocument {
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

/// Xcode 27's asynchronous document pipeline keeps file coordination and I/O
/// away from the main actor. The legacy `FileDocument` above remains the
/// back-deployment path for macOS 14–26.
@available(macOS 27.0, *)
@MainActor
final class AsyncPlainTextDocument: WritableDocument {
    typealias Writer = FileWrapperDocumentWriter<Data>

    static var writableContentTypes: [UTType] { [.plainText] }

    private let text: String

    init(text: String) {
        self.text = text
    }

    nonisolated func writer(configuration: sending WriteConfiguration) -> sending Writer {
        FileWrapperDocumentWriter(configuration) { snapshot, previous in
            if previous?.regularFileContents == snapshot, let previous {
                return previous
            }
            return FileWrapper(regularFileWithContents: snapshot)
        }
    }

    func snapshot(contentType: UTType) async throws -> sending Data {
        Data(text.utf8)
    }
}
