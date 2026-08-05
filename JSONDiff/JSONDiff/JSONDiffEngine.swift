import Foundation

nonisolated enum DiffKind: Equatable, Sendable {
    case unchanged
    case removed
    case added
    case modified
}

nonisolated struct DiffRow: Identifiable, Equatable, Sendable {
    let id: Int
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let left: String
    let right: String
    let kind: DiffKind
}

nonisolated struct DiffSummary: Equatable, Sendable {
    let unchanged: Int
    let added: Int
    let removed: Int
    let modified: Int

    var changes: Int { added + removed + modified }
    var isIdentical: Bool { changes == 0 }
}

nonisolated struct JSONDiffResult: Equatable, Sendable {
    let rows: [DiffRow]
    let formattedLeft: String
    let formattedRight: String
    let summary: DiffSummary
}

nonisolated enum JSONDiffError: LocalizedError, Equatable {
    case invalidJSON(side: String, detail: String)

    var errorDescription: String? {
        switch self {
        case let .invalidJSON(side, detail):
            return "Invalid \(side) JSON: \(detail)"
        }
    }
}

nonisolated private enum JSONValue: Decodable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Decimal)
    case boolean(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func prettyPrinted(level: Int = 0) throws -> String {
        switch self {
        case let .object(values):
            guard !values.isEmpty else { return "{}" }
            let indentation = String(repeating: "  ", count: level)
            let childIndentation = String(repeating: "  ", count: level + 1)
            let lines = try values.keys.sorted().map { key in
                let encodedKey = try Self.encodeString(key)
                return "\(childIndentation)\(encodedKey) : \(try values[key]!.prettyPrinted(level: level + 1))"
            }
            return "{\n\(lines.joined(separator: ",\n"))\n\(indentation)}"
        case let .array(values):
            guard !values.isEmpty else { return "[]" }
            let indentation = String(repeating: "  ", count: level)
            let childIndentation = String(repeating: "  ", count: level + 1)
            let lines = try values.map { "\(childIndentation)\(try $0.prettyPrinted(level: level + 1))" }
            return "[\n\(lines.joined(separator: ",\n"))\n\(indentation)]"
        case let .string(value):
            return try Self.encodeString(value)
        case let .number(value):
            return NSDecimalNumber(decimal: value).description(withLocale: Locale(identifier: "en_US_POSIX"))
        case let .boolean(value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }

    private static func encodeString(_ value: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

nonisolated enum JSONDiffEngine {
    nonisolated static func normalizeQuotes(in text: String) -> String {
        text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
    }

    nonisolated static func formatAndSort(_ source: String, side: String) throws -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? "{}" : normalizeQuotes(in: source)

        do {
            return try JSONDecoder().decode(JSONValue.self, from: Data(value.utf8)).prettyPrinted()
        } catch {
            let detail: String
            if let decodingError = error as? DecodingError {
                detail = decodingError.conciseDescription
            } else {
                detail = error.localizedDescription
            }
            throw JSONDiffError.invalidJSON(side: side, detail: detail)
        }
    }

    nonisolated static func analyze(left: String, right: String) throws -> JSONDiffResult {
        let formattedLeft = try formatAndSort(left, side: "left")
        let formattedRight = try formatAndSort(right, side: "right")
        let rows = lineDiff(
            left: formattedLeft.components(separatedBy: .newlines),
            right: formattedRight.components(separatedBy: .newlines)
        )
        let summary = DiffSummary(
            unchanged: rows.count { $0.kind == .unchanged },
            added: rows.count { $0.kind == .added },
            removed: rows.count { $0.kind == .removed },
            modified: rows.count { $0.kind == .modified }
        )
        return JSONDiffResult(
            rows: rows,
            formattedLeft: formattedLeft,
            formattedRight: formattedRight,
            summary: summary
        )
    }

    nonisolated static func compare(left: String, right: String) throws -> [DiffRow] {
        try analyze(left: left, right: right).rows
    }

    nonisolated private static func lineDiff(left: [String], right: [String]) -> [DiffRow] {
        // A newly inserted sibling changes the previous line's trailing comma. Treat that
        // punctuation as formatting context, not as a user-visible value modification.
        let leftMatchKeys = left.map(matchingKey)
        let rightMatchKeys = right.map(matchingKey)
        let changes = rightMatchKeys.difference(from: leftMatchKeys)
        let removalOffsets = Set(changes.removals.map(\.offset))
        let insertionOffsets = Set(changes.insertions.map(\.offset))

        var rows: [DiffRow] = []
        var leftIndex = 0
        var rightIndex = 0

        func append(leftLine: Int?, rightLine: Int?, leftText: String, rightText: String, kind: DiffKind) {
            rows.append(DiffRow(
                id: rows.count,
                leftLineNumber: leftLine,
                rightLineNumber: rightLine,
                left: leftText,
                right: rightText,
                kind: kind
            ))
        }

        while leftIndex < left.count || rightIndex < right.count {
            let hasRemoval = leftIndex < left.count && removalOffsets.contains(leftIndex)
            let hasInsertion = rightIndex < right.count && insertionOffsets.contains(rightIndex)

            if !hasRemoval, !hasInsertion, leftIndex < left.count, rightIndex < right.count {
                append(
                    leftLine: leftIndex + 1,
                    rightLine: rightIndex + 1,
                    leftText: left[leftIndex],
                    rightText: right[rightIndex],
                    kind: .unchanged
                )
                leftIndex += 1
                rightIndex += 1
                continue
            }

            var removedLines: [(number: Int, text: String)] = []
            while leftIndex < left.count, removalOffsets.contains(leftIndex) {
                removedLines.append((leftIndex + 1, left[leftIndex]))
                leftIndex += 1
            }

            var addedLines: [(number: Int, text: String)] = []
            while rightIndex < right.count, insertionOffsets.contains(rightIndex) {
                addedLines.append((rightIndex + 1, right[rightIndex]))
                rightIndex += 1
            }

            let pairedCount = min(removedLines.count, addedLines.count)
            for index in 0..<pairedCount {
                append(
                    leftLine: removedLines[index].number,
                    rightLine: addedLines[index].number,
                    leftText: removedLines[index].text,
                    rightText: addedLines[index].text,
                    kind: .modified
                )
            }
            for line in removedLines.dropFirst(pairedCount) {
                append(leftLine: line.number, rightLine: nil, leftText: line.text, rightText: "", kind: .removed)
            }
            for line in addedLines.dropFirst(pairedCount) {
                append(leftLine: nil, rightLine: line.number, leftText: "", rightText: line.text, kind: .added)
            }

            if removedLines.isEmpty, addedLines.isEmpty {
                if leftIndex < left.count {
                    append(leftLine: leftIndex + 1, rightLine: nil, leftText: left[leftIndex], rightText: "", kind: .removed)
                    leftIndex += 1
                } else if rightIndex < right.count {
                    append(leftLine: nil, rightLine: rightIndex + 1, leftText: "", rightText: right[rightIndex], kind: .added)
                    rightIndex += 1
                }
            }
        }

        return rows
    }

    nonisolated private static func matchingKey(for line: String) -> String {
        let whitespaceCount = line.reversed().prefix(while: \.isWhitespace).count
        let trailingWhitespace = line.suffix(whitespaceCount)
        let body = line.dropLast(whitespaceCount)
        guard body.last == "," else { return line }
        return String(body.dropLast()) + String(trailingWhitespace)
    }
}

nonisolated private extension DecodingError {
    var conciseDescription: String {
        switch self {
        case let .dataCorrupted(context), let .keyNotFound(_, context),
             let .typeMismatch(_, context), let .valueNotFound(_, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
        @unknown default:
            return localizedDescription
        }
    }
}

nonisolated private extension CollectionDifference.Change {
    var offset: Int {
        switch self {
        case let .insert(offset, _, _), let .remove(offset, _, _): offset
        }
    }
}

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
