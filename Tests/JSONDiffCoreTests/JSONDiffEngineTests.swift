import Foundation
import Testing
@testable import JSONDiffCore

struct JSONDiffEngineTests {
    @Test("Object key order does not create differences")
    func reorderedKeys() throws {
        let rows = try JSONDiffEngine.compare(
            left: #"{"outer":{"b":2,"a":1},"name":"demo"}"#,
            right: #"{"name":"demo","outer":{"a":1,"b":2}}"#
        )

        #expect(rows.allSatisfy { $0.kind == .unchanged })
    }

    @Test("Nested additions and removals retain their side")
    func additionsAndRemovals() throws {
        let rows = try JSONDiffEngine.compare(
            left: #"{"nested":{"old":true},"keep":1}"#,
            right: #"{"nested":{"new":true},"keep":1}"#
        )

        #expect(rows.contains { $0.kind == .modified && $0.left.contains("old") && $0.right.contains("new") })
    }

    @Test("Top-level JSON fragments are supported")
    func fragments() throws {
        let rows = try JSONDiffEngine.compare(left: "42", right: "43")
        #expect(rows.map(\.kind) == [.modified])
    }

    @Test("Smart double quotes are normalized")
    func smartQuotes() throws {
        let rows = try JSONDiffEngine.compare(left: "{“value”: 1}", right: #"{"value":1}"#)
        #expect(rows.allSatisfy { $0.kind == .unchanged })
    }

    @Test("Invalid input identifies the failing side")
    func invalidJSON() {
        do {
            _ = try JSONDiffEngine.compare(left: "{", right: "{}")
            Issue.record("Expected invalid JSON to throw")
        } catch let JSONDiffError.invalidJSON(side, detail) {
            #expect(side == "left")
            #expect(!detail.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A scalar replacement is paired as one modification")
    func scalarModification() throws {
        let result = try JSONDiffEngine.analyze(
            left: #"{"name":"before","count":1}"#,
            right: #"{"name":"after","count":1}"#
        )

        #expect(result.summary.modified == 1)
        #expect(result.summary.added == 0)
        #expect(result.summary.removed == 0)
        #expect(result.rows.contains {
            $0.kind == .modified && $0.left.contains("before") && $0.right.contains("after")
        })
    }

    @Test("Array order remains semantically significant")
    func arrayOrder() throws {
        let result = try JSONDiffEngine.analyze(
            left: #"{"items":["a","b","c"]}"#,
            right: #"{"items":["b","a","c"]}"#
        )

        #expect(!result.summary.isIdentical)
        #expect(result.summary.changes > 0)
    }

    @Test("An inserted property is reported without changing its neighbors")
    func insertedProperty() throws {
        let result = try JSONDiffEngine.analyze(
            left: #"{"a":1,"c":3}"#,
            right: #"{"a":1,"b":2,"c":3}"#
        )

        #expect(result.summary.added == 1)
        #expect(result.summary.modified == 0)
        #expect(result.rows.contains { $0.kind == .added && $0.right.contains(#""b""#) })
    }

    @Test("Empty inputs retain legacy empty-object behavior")
    func emptyInputs() throws {
        let result = try JSONDiffEngine.analyze(left: "", right: "")
        #expect(result.formattedLeft == "{}")
        #expect(result.summary.isIdentical)
    }

    @Test("Formatting and escaped slashes do not create differences")
    func formattingNoise() throws {
        let result = try JSONDiffEngine.analyze(
            left: "{\n  \"url\": \"https:\\/\\/xnu.app\", \"enabled\": true\n}",
            right: #"{"enabled":true,"url":"https://xnu.app"}"#
        )
        #expect(result.summary.isIdentical)
    }

    @Test("Decimal values retain their source precision")
    func decimalPrecision() throws {
        let result = try JSONDiffEngine.analyze(
            left: #"{"price":19.99,"weight":2.5}"#,
            right: #"{"price":24.99,"weight":2.2}"#
        )

        #expect(result.formattedLeft.contains("19.99"))
        #expect(result.formattedRight.contains("24.99"))
        #expect(!result.formattedLeft.contains("999999"))
        #expect(!result.formattedRight.contains("000000"))
    }

    @Test("Appending an array item does not flag the previous comma as a value change")
    func arrayAppendIgnoresCommaNoise() throws {
        let result = try JSONDiffEngine.analyze(
            left: #"{"items":["a","b"]}"#,
            right: #"{"items":["a","b","c"]}"#
        )

        #expect(result.summary.added == 1)
        #expect(result.summary.modified == 0)
        #expect(result.rows.contains { $0.kind == .unchanged && $0.left.contains(#""b""#) })
    }

    @Test("A multi-megabyte document compares within the regression budget", .timeLimit(.minutes(1)))
    func largeDocumentPerformance() throws {
        let entries = (0..<40_000).map { #""key\#($0)":\#($0)"# }.joined(separator: ",")
        let json = "{\(entries)}"
        let clock = ContinuousClock()

        let elapsed = try clock.measure {
            let rows = try JSONDiffEngine.compare(left: json, right: json)
            #expect(rows.allSatisfy { $0.kind == .unchanged })
        }

        #expect(elapsed < .seconds(8))
    }
}
