#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== macOS Bootstrap ==="
echo ""

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p &>/dev/null; then
    echo "[1/7] Installing Xcode Command Line Tools..."
    xcode-select --install
    echo ">>> Press any key after Xcode CLT installation finishes."
    read -n 1
else
    echo "[1/7] Xcode Command Line Tools: already installed"
fi

# --- 2. Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "[2/7] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[2/7] Homebrew: already installed"
fi

# --- 3. 1Password + CLI (needed before chezmoi for secrets) ---
echo "[3/7] Installing 1Password..."
brew install --cask 1password 2>/dev/null || true
brew install --cask 1password-cli 2>/dev/null || true

echo ""
echo ">>> MANUAL STEPS REQUIRED (1Password setup):"
echo ""
echo "    1. Open 1Password app (it should be in /Applications now)"
echo "    2. Sign in with your 1Password account"
echo "    3. Go to: 1Password menu bar > Settings (Cmd+,)"
echo "    4. Click 'Developer' in the left sidebar"
echo "    5. Check 'Integrate with 1Password CLI'"
echo "    6. Click 'Set up the SSH Agent' and follow the prompts"
echo "       - When asked about key names: choose 'Use Key Names'"
echo "    7. Make sure your SSH keys are in 1Password:"
echo "       - 'GitHub Work (arekc-at-volume)' in Work vault"
echo "       - 'GitHub Personal (Arkadiusz-Czubik)' in Personal vault"
echo "    8. Edit SSH Agent config (~/.config/1Password/ssh/agent.toml):"
echo "       - Add:  [[ssh-keys]]"
echo "       -        vault = \"Work\""
echo ""
echo ">>> When all done, press any key to continue."
read -n 1
echo ""

# Verify 1Password CLI works
if ! op account list &>/dev/null; then
    echo "[!!] 1Password CLI not working. Check that 'Integrate with 1Password CLI' is enabled."
    echo ">>> Fix it and press any key to retry."
    read -n 1
fi

# Verify SSH agent works
echo "Verifying SSH agent..."
if ssh -T git@github.com-personal 2>&1 | grep -q "successfully"; then
    echo "[OK] SSH to GitHub (personal) works"
else
    echo "[!!] SSH to GitHub (personal) failed. Check 1Password SSH Agent setup."
    echo ">>> Fix it and press any key to continue anyway."
    read -n 1
fi

# --- 4. chezmoi + dotfiles ---
echo "[4/7] Setting up chezmoi + dotfiles..."
brew install chezmoi 2>/dev/null || true

if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    chezmoi init git@github.com-personal:Arkadiusz-Czubik/macbook-setup.git
fi
chezmoi apply

# --- 5. Brewfile ---
echo "[5/7] Installing packages from Brewfile..."
brew bundle install --file="$SCRIPT_DIR/Brewfile" --no-lock

# --- 6. SDKMAN + Java ---
echo "[6/7] Setting up SDKMAN..."
bash "$SCRIPT_DIR/setup-sdkman.sh"

# --- 7. macOS security hardening ---
echo "[7/7] Applying macOS security settings..."
bash "$SCRIPT_DIR/macos-security.sh"

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Manual steps remaining:"
echo "  - gh auth login"
echo "  - aws sso login"
echo "  - Sign in to apps (Obsidian, Slack, etc.)"
echo "  - Import Bitwarden export to 1Password if needed"
echo "  - Configure Time Machine (see docs/SETUP-DETAILED.md section 13)"
echo "  - Restore Docker volumes if needed: .setup/docker/restore-docker.sh <backup-path>"
