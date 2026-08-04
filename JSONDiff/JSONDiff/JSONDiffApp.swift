import SwiftUI

@main
struct JSONDiffApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Compare JSON") {
                    NotificationCenter.default.post(name: .compareJSON, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Clear All") {
                    NotificationCenter.default.post(name: .clearJSON, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let compareJSON = Notification.Name("MyJSONDiff.compare")
    static let clearJSON = Notification.Name("MyJSONDiff.clear")
}
