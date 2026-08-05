extension JSONDiffResult {
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
