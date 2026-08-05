import SwiftUI

struct DiffResultView: View {
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
            DiffLine(number: row.leftLineNumber, text: row.left, counterpart: row.right, kind: row.kind, side: .left)
            Divider()
            DiffLine(number: row.rightLineNumber, text: row.right, counterpart: row.left, kind: row.kind, side: .right)
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
