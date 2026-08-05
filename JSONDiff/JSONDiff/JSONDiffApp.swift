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

                Button("Swap Sides") {
                    NotificationCenter.default.post(name: .swapJSON, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }

        Settings {
            Form {
                Section("More Apps") {
                    Link(destination: URL(string: "https://apps.apple.com/us/app/startmyapp-fast-app-launch/id6753610893")!) {
                        Label("StartMyApp", systemImage: "bolt")
                    }
                    Link(destination: URL(string: "https://apps.apple.com/us/app/scriptwidget/id1555600758")!) {
                        Label("ScriptWidget", systemImage: "curlybraces.square")
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 420, height: 220)
        }
    }
}

extension Notification.Name {
    static let compareJSON = Notification.Name("MyJSONDiff.compare")
    static let clearJSON = Notification.Name("MyJSONDiff.clear")
    static let swapJSON = Notification.Name("MyJSONDiff.swap")
}
