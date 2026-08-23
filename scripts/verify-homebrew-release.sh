#!/bin/bash
set -euo pipefail

version="${1:-}"
if [[ -z "$version" ]]; then
  echo "usage: $0 <version>" >&2
  exit 64
fi
version="${version#v}"

brew uninstall --cask myjsondiff >/dev/null 2>&1 || true
brew uninstall --cask jsoncompare >/dev/null 2>&1 || true
brew install --cask everettjf/tap/jsoncompare
installed_version="$(defaults read '/Applications/JSON Compare.app/Contents/Info' CFBundleShortVersionString)"
[[ "$installed_version" == "$version" ]] || {
  echo "unexpected installed version: $installed_version" >&2
  exit 65
}
codesign --verify --deep --strict --verbose=2 "/Applications/JSON Compare.app"
spctl --assess --type execute --verbose=4 "/Applications/JSON Compare.app"
open -n -a "/Applications/JSON Compare.app"
echo "Verified JSON Compare $version from Homebrew"
