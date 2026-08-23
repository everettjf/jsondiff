#!/bin/bash
set -euo pipefail

version="${1:-}"
if [[ -z "$version" ]]; then
  echo "usage: $0 <version>" >&2
  exit 64
fi
version="${version#v}"

brew uninstall --cask myjsondiff >/dev/null 2>&1 || true
brew install --cask everettjf/tap/myjsondiff
installed_version="$(defaults read /Applications/MyJSONDiff.app/Contents/Info CFBundleShortVersionString)"
[[ "$installed_version" == "$version" ]] || {
  echo "unexpected installed version: $installed_version" >&2
  exit 65
}
codesign --verify --deep --strict --verbose=2 /Applications/MyJSONDiff.app
spctl --assess --type execute --verbose=4 /Applications/MyJSONDiff.app
open -n -a /Applications/MyJSONDiff.app
echo "Verified MyJSONDiff $version from Homebrew"
