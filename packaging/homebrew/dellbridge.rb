cask "dellbridge" do
  version "0.2.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/elCanosail/dellbridge/releases/download/v#{version}/DellBridge-#{version}.dmg"
  name "DellBridge"
  desc "Open DDC/CI bridge for Dell USB-C monitors"
  homepage "https://github.com/elCanosail/dellbridge"

  depends_on macos: ">= :ventura"

  app "DellBridge.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/DellBridge.app"]
  end

  caveats "DellBridge is not notarized yet. This cask removes the quarantine flag so the app opens normally."
end
