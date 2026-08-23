# JSON Compare

Repository: <https://github.com/everettjf/jsoncompare>

JSON Compare is a privacy-first, fast, native macOS app for comparing two JSON documents side by side. It parses both documents into a decimal-safe JSON model, sorts object keys deterministically, and aligns the formatted output so results focus on data changes instead of formatting noise.

## Maintenance Status

JSON Compare is in maintenance mode. It will continue to receive essential compatibility and reliability fixes, but no new comparison features are planned. For JSON and plist comparison alongside text, folders, images, Git difftool/mergetool, and three-way merge, use [GrapeCompare](https://xnu.app/grapecompare/).

## Screenshot

![JSON Compare screenshot](screenshot.png)

## Website

Official site: https://www.xnu.app/jsoncompare

## Install

JSON Compare is distributed as a signed and notarized Homebrew Cask:

```bash
brew install --cask everettjf/tap/jsoncompare
```

The former Mac App Store listing has been retired.

Any future Mac App Store release will be a new application using the bundle identifier `com.xnu.jsoncompare`; it will not replace or inherit the retired MyJSONDiff listing.

## Features

- Side-by-side JSON editors with a clear, readable layout
- Open or drag UTF-8 JSON files up to 50 MB
- Order-insensitive object comparison via deterministic key sorting
- Precise decimal rendering without binary floating-point artifacts
- Aligned added, removed, and modified lines with inline change emphasis
- Change counts and an option to hide unchanged lines
- Copy or export a plain-text diff report
- Handles objects, arrays, strings, numbers, booleans, nulls, and top-level fragments
- Fully local processing with no network access
- Native light and dark mode support
- Keyboard shortcuts and VoiceOver-friendly controls

## How It Works

1. Paste JSON A on the left
2. Paste JSON B on the right
3. Click "Compare JSON"
4. The tool parses exact JSON values and sorts object keys
5. A native line-alignment engine pairs replacements and separates additions/removals
6. Review, filter, copy, or export the side-by-side report

### Diff Legend

- **Added** (green): present on the right, missing on the left
- **Removed** (red): present on the left, missing on the right
- **Modified** (orange): aligned content changed between the two documents

## Tech Stack

- Swift and SwiftUI, with no embedded browser or JavaScript runtime
- `JSONDecoder` with `Decimal` values for exact numeric rendering
- A native Swift alignment engine built on `CollectionDifference`

## Requirements

- macOS 14 or later

## Privacy

All comparison and file processing happens on-device. JSON Compare has no network dependency and does not upload document contents.

## Local Development

```bash
open JSONDiff/JSONDiff.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project JSONDiff/JSONDiff.xcodeproj \
  -scheme JSONDiff \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Contributing

Issues and pull requests for compatibility and reliability fixes are welcome. New comparison capabilities belong in [GrapeCompare](https://github.com/everettjf/grapecompare).

## License

MIT

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=everettjf/jsoncompare&type=Date)](https://star-history.com/#everettjf/jsoncompare&Date)
