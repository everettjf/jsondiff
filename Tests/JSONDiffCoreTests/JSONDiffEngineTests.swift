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

        #expect(rows.contains { $0.kind == .removed && $0.left.contains("old") })
        #expect(rows.contains { $0.kind == .added && $0.right.contains("new") })
    }

    @Test("Top-level JSON fragments are supported")
    func fragments() throws {
        let rows = try JSONDiffEngine.compare(left: "42", right: "43")
        #expect(rows.map(\.kind) == [.removed, .added])
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
