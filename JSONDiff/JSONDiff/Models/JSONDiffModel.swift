import Foundation
import Observation

@Observable
@MainActor
final class JSONDiffModel {
    var leftJSON = ""
    var rightJSON = ""
    var result: JSONDiffResult?
    var errorMessage: String?
    var isComparing = false

    func compare() async {
        guard !isComparing else { return }
        isComparing = true
        errorMessage = nil
        let left = leftJSON
        let right = rightJSON

        do {
            result = try await Task.detached(priority: .userInitiated) {
                try JSONDiffEngine.analyze(left: left, right: right)
            }.value
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
        isComparing = false
    }

    func clear() {
        leftJSON = ""
        rightJSON = ""
        result = nil
        errorMessage = nil
    }

    func edit() {
        result = nil
    }

    func swapInputs() {
        (leftJSON, rightJSON) = (rightJSON, leftJSON)
        result = nil
    }

    func setText(_ text: String, for side: EditorSide) {
        switch side {
        case .left: leftJSON = text
        case .right: rightJSON = text
        }
        result = nil
    }

    func loadDemo() {
        leftJSON = Self.demoLeft
        rightJSON = Self.demoRight
        result = nil
        errorMessage = nil
    }

    private static let demoLeft = """
    {
      "name": "Product A",
      "price": 19.99,
      "features": ["Durable", "Waterproof", "Lightweight"],
      "specs": { "weight": 2.5, "color": "blue", "dimensions": { "height": 10, "width": 15, "depth": 5 } },
      "inStock": true,
      "categories": ["electronics", "accessories"]
    }
    """

    private static let demoRight = """
    {
      "name": "Product A",
      "price": 24.99,
      "features": ["Durable", "Waterproof", "Eco-friendly"],
      "specs": { "weight": 2.2, "color": "green", "dimensions": { "height": 10, "width": 15, "depth": 6 } },
      "inStock": true,
      "categories": ["electronics", "accessories", "outdoor"],
      "discount": 10
    }
    """
}
