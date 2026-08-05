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
            "Invalid \(side) JSON: \(detail)"
        }
    }
}
