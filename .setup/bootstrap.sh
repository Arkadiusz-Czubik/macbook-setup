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

# --- 3. 1Password + CLI + chezmoi ---
echo "[3/7] Installing 1Password + chezmoi..."
brew install --cask 1password 2>/dev/null || true
brew install --cask 1password-cli 2>/dev/null || true
brew install chezmoi 2>/dev/null || true

# Add GitHub to known hosts (avoids SSH prompt on first connection)
mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true

# --- 4. Oh My Zsh + Powerlevel10k + chezmoi dotfiles ---
echo "[4/7] Setting up shell + dotfiles..."

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "  Installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "  Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

# chezmoi + dotfiles
if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    chezmoi init https://github.com/Arkadiusz-Czubik/macbook-setup.git
fi
chezmoi apply

# --- 5. 1Password SSH Agent setup (after chezmoi so ~/.ssh/config exists) ---
if op account list &>/dev/null && ssh -T git@github.com-personal 2>&1 | grep -q "successfully"; then
    echo "[5/7] 1Password + SSH Agent: already configured"
else
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

    # Verify
    if op account list &>/dev/null; then
        echo "[OK] 1Password CLI works"
    else
        echo "[!!] 1Password CLI not working — skipping, fix later."
    fi

    if ssh -T git@github.com-personal 2>&1 | grep -q "successfully"; then
        echo "[OK] SSH to GitHub (personal) works"
    else
        echo "[!!] SSH to GitHub (personal) failed — skipping, fix later."
    fi
fi

# Switch chezmoi remote to SSH (now that SSH works)
cd "$HOME/.local/share/chezmoi"
if git remote get-url origin 2>/dev/null | grep -q "https://"; then
    git remote set-url origin git@github.com-personal:Arkadiusz-Czubik/macbook-setup.git 2>/dev/null || true
fi
cd - >/dev/null

# --- 6. Brewfile ---
echo "[6/7] Installing packages from Brewfile..."
brew bundle install --file="$SCRIPT_DIR/Brewfile" --verbose

# --- 7. SDKMAN + Java + macOS security ---
echo "[7/7] Setting up SDKMAN + macOS security..."
bash "$SCRIPT_DIR/setup-sdkman.sh"
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
