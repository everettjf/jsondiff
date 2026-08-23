cask "myjsondiff" do
  version "1.4.0"
  sha256 "e77afe91a70dbfb90c60121c9383ea49ba26050aa2c40814a530e01bdfb88e75"

  url "https://github.com/everettjf/jsondiff/releases/download/v#{version}/MyJSONDiff-#{version}.zip"
  name "MyJSONDiff"
  desc "Fast, native, order-insensitive JSON comparison for macOS"
  homepage "https://xnu.app/jsondiff/"

  depends_on macos: ">= :sonoma"
  app "MyJSONDiff.app"

  zap trash: [
    "~/Library/Preferences/com.xnu.jsondiff.plist",
    "~/Library/Saved Application State/com.xnu.jsondiff.savedState",
  ]
end
