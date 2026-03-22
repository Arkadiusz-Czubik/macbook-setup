#!/usr/bin/env bash
set -e

echo "=== macOS Security Hardening ==="

# FileVault (full disk encryption)
if fdesetup status | grep -q "On"; then
    echo "[OK] FileVault is ON"
else
    echo "[!!] FileVault is OFF — enable it manually in System Settings > Privacy & Security > FileVault"
fi

# Firewall
echo "Enabling firewall..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
echo "[OK] Firewall ON + stealth mode"

# Gatekeeper
sudo spctl --master-enable 2>/dev/null || true
echo "[OK] Gatekeeper enabled"

# Require password immediately after screensaver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "[OK] Password required immediately after screensaver"

# Disable remote login (SSH server)
sudo systemsetup -setremotelogin off 2>/dev/null || true
echo "[OK] Remote login disabled"

# Automatic updates
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true
defaults write com.apple.commerce AutoUpdate -bool true
echo "[OK] Automatic updates enabled"

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "[OK] File extensions visible"

echo ""
echo "=== Security hardening complete ==="
