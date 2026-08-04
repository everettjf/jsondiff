import Foundation

enum DiffKind: Equatable, Sendable {
    case unchanged
    case removed
    case added
}

struct DiffRow: Identifiable, Equatable, Sendable {
    let id: Int
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let left: String
    let right: String
    let kind: DiffKind
}

enum JSONDiffError: LocalizedError, Equatable {
    case invalidJSON(side: String, detail: String)

    var errorDescription: String? {
        switch self {
        case let .invalidJSON(side, detail):
            return "Invalid \(side) JSON: \(detail)"
        }
    }
}

enum JSONDiffEngine {
    static func normalizeQuotes(in text: String) -> String {
        text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
    }

    static func formatAndSort(_ source: String, side: String) throws -> String {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "{}" : source
        do {
            let object = try JSONSerialization.jsonObject(with: Data(value.utf8), options: [.fragmentsAllowed])
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
            )
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw JSONDiffError.invalidJSON(side: side, detail: error.localizedDescription)
        }
    }

    static func compare(left: String, right: String) throws -> [DiffRow] {
        let formattedLeft = try formatAndSort(normalizeQuotes(in: left), side: "left")
        let formattedRight = try formatAndSort(normalizeQuotes(in: right), side: "right")
        return lineDiff(
            left: formattedLeft.components(separatedBy: .newlines),
            right: formattedRight.components(separatedBy: .newlines)
        )
    }

    private static func lineDiff(left: [String], right: [String]) -> [DiffRow] {
        let changes = right.difference(from: left)
        let removals = Dictionary(uniqueKeysWithValues: changes.removals.map { change in
            switch change {
            case let .remove(offset, element, _): (offset, element)
            case .insert: preconditionFailure("Expected a removal")
            }
        })
        let insertions = Dictionary(uniqueKeysWithValues: changes.insertions.map { change in
            switch change {
            case let .insert(offset, element, _): (offset, element)
            case .remove: preconditionFailure("Expected an insertion")
            }
        })

        var rows: [DiffRow] = []
        var leftIndex = 0
        var rightIndex = 0

        while leftIndex < left.count || rightIndex < right.count {
            if let removed = removals[leftIndex] {
                rows.append(DiffRow(
                    id: rows.count,
                    leftLineNumber: leftIndex + 1,
                    rightLineNumber: nil,
                    left: removed,
                    right: "",
                    kind: .removed
                ))
                leftIndex += 1
            } else if let inserted = insertions[rightIndex] {
                rows.append(DiffRow(
                    id: rows.count,
                    leftLineNumber: nil,
                    rightLineNumber: rightIndex + 1,
                    left: "",
                    right: inserted,
                    kind: .added
                ))
                rightIndex += 1
            } else if leftIndex < left.count, rightIndex < right.count {
                rows.append(DiffRow(
                    id: rows.count,
                    leftLineNumber: leftIndex + 1,
                    rightLineNumber: rightIndex + 1,
                    left: left[leftIndex],
                    right: right[rightIndex],
                    kind: .unchanged
                ))
                leftIndex += 1
                rightIndex += 1
            } else if leftIndex < left.count {
                rows.append(DiffRow(
                    id: rows.count,
                    leftLineNumber: leftIndex + 1,
                    rightLineNumber: nil,
                    left: left[leftIndex],
                    right: "",
                    kind: .removed
                ))
                leftIndex += 1
            } else if rightIndex < right.count {
                rows.append(DiffRow(
                    id: rows.count,
                    leftLineNumber: nil,
                    rightLineNumber: rightIndex + 1,
                    left: "",
                    right: right[rightIndex],
                    kind: .added
                ))
                rightIndex += 1
            }
        }

        return rows
    }
}

enum JSONFileLoader {
    enum LoadError: LocalizedError {
        case notAFile
        case unsupportedEncoding

        var errorDescription: String? {
            switch self {
            case .notAFile: "Drop a JSON file, not a folder."
            case .unsupportedEncoding: "The file is not valid UTF-8 text."
            }
        }
    }

    static func load(from url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { throw LoadError.notAFile }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else {
                throw LoadError.unsupportedEncoding
            }
            return text
        }.value
    }
}
