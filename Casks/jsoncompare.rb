cask "jsoncompare" do
  version "1.5.0"
  sha256 "6630d618e2ad882158addfaa68cb15e773ba2bfeab6d44b6ba2c3540b66c5697"

  url "https://github.com/everettjf/jsoncompare/releases/download/v#{version}/JSONCompare-#{version}.zip"
  name "JSON Compare"
  desc "Fast, native, order-insensitive JSON comparison for macOS"
  homepage "https://xnu.app/jsoncompare/"

  depends_on macos: :sonoma
  app "JSON Compare.app"

  zap trash: [
    "~/Library/Preferences/com.xnu.jsondiff.plist",
    "~/Library/Saved Application State/com.xnu.jsondiff.savedState",
  ]
end
