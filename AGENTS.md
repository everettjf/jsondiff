# Repository Guidelines

## Project Overview

JSON Compare is a native macOS SwiftUI app for comparing two JSON documents. It parses both inputs with Foundation, serializes objects with stable sorted keys, and renders an order-insensitive side-by-side line diff. The legacy Tauri/Next.js implementation has been retired; do not reintroduce a web runtime or JavaScript dependency for core comparison behavior.

## Structure

- `JSONDiff/JSONDiff.xcodeproj`: primary Xcode project.
- `JSONDiff/JSONDiff/JSONDiffApp.swift`: app scene and commands.
- `JSONDiff/JSONDiff/ContentView.swift`: editors, result UI, and observable app state.
- `JSONDiff/JSONDiff/JSONDiffEngine.swift`: quote normalization, JSON parsing/sorting, and line diff logic.
- `resource/` and `screenshot.png`: App Store and README assets.

Keep parsing and comparison logic independent from SwiftUI so it remains directly testable.

## Build and Verification

```bash
xcodebuild \
  -project JSONDiff/JSONDiff.xcodeproj \
  -scheme JSONDiff \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

When changing comparison behavior, verify nested objects, arrays, JSON fragments, empty input, invalid JSON, reordered keys, smart quotes, additions, and removals.

## Swift and SwiftUI Conventions

- Use native SwiftUI and Foundation APIs; bridge to AppKit only when SwiftUI cannot provide the required macOS behavior.
- Keep owned observable models in private `@State`; use `@Observable` for new model types.
- Keep all `@State` and `@FocusState` properties private.
- Use stable identity in `ForEach` and `Button` for interactive controls.
- Preserve keyboard access, VoiceOver labels, text selection, system appearance, and resizable split-pane behavior.
- Do not embed a WebView or duplicate JSON comparison logic in the view layer.

## Documentation and Releases

Update `README.md` whenever requirements, features, screenshots, build commands, or architecture change. Keep the public repository URL canonical: `https://github.com/everettjf/jsoncompare`.

The current bundle identifier is `com.xnu.jsoncompare`. The retired MyJSONDiff App Store record and its old `com.xnu.jsondiff` identity are intentionally not compatibility targets. A future App Store release must be created as a new app.

The Xcode target defaults to App Sandbox for future App Store builds. The Homebrew release script explicitly overrides `ENABLE_APP_SANDBOX=NO` for Developer ID distribution; preserve this channel-specific split.
