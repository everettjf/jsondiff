import Foundation

nonisolated enum JSONFileLoader {
    nonisolated enum LoadError: LocalizedError {
        case notAFile
        case fileTooLarge
        case unsupportedEncoding

        var errorDescription: String? {
            switch self {
            case .notAFile: "Choose a JSON file, not a folder."
            case .fileTooLarge: "The selected file is larger than 50 MB."
            case .unsupportedEncoding: "The file is not valid UTF-8 text."
            }
        }
    }

    static func load(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { throw LoadError.notAFile }
            guard (values.fileSize ?? 0) <= 50 * 1_024 * 1_024 else { throw LoadError.fileTooLarge }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                throw LoadError.unsupportedEncoding
            }
            return text
        }.value
    }
}
