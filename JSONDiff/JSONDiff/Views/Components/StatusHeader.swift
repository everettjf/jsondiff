import SwiftUI

struct StatusHeader: View {
    let result: JSONDiffResult?

    var body: some View {
        HStack {
            Text(result == nil ? "Compare JSON locally with formatting noise removed" : "Keys sorted · values and array order preserved")
                .font(.callout)
                .foregroundStyle(.secondary)
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
        .padding(.vertical, 8)
    }
}
