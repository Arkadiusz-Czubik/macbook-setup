#!/bin/bash
# =============================================================================
# SEED SCRIPT — jedyny skrypt który musisz odpalić na świeżym Macu
# =============================================================================
#
# Lokalizacja: TrueNAS share → smb://192.168.30.3/ariusz/seed.sh
#
# Na świeżym Macu:
#   1. Podłącz się do WiFi
#   2. Finder → Cmd+K → smb://192.168.30.3/ariusz (login: ariusz)
#   3. Otwórz Terminal
#   4. bash /Volumes/ariusz/seed.sh
#
# Ten skrypt:
#   1. Instaluje Xcode CLT
#   2. Instaluje Homebrew
#   3. Instaluje 1Password (żebyś miał dostęp do haseł)
#   4. Instaluje gh (GitHub CLI)
#   5. Loguje do GitHuba (teraz masz hasło z 1Password)
#   6. Klonuje macbook-setup repo
#   7. Odpala bootstrap.sh (reszta automatycznie)
# =============================================================================

set -e

echo ""
echo "============================================"
echo "  MacBook Setup — Starting from scratch"
echo "============================================"
echo ""

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p &>/dev/null; then
    echo "[1/7] Installing Xcode Command Line Tools..."
    echo "      A dialog will pop up. Click 'Install' and wait."
    xcode-select --install
    echo ""
    echo ">>> Press any key when Xcode CLT installation finishes."
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
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3. 1Password (so you have access to passwords for next steps) ---
echo "[3/7] Installing 1Password..."
brew install --cask 1password 2>/dev/null || true

echo ""
echo ">>> Open 1Password and sign in to your account."
echo "    You'll need your passwords for GitHub login in the next step."
echo ""
echo ">>> Press any key when 1Password is ready."
read -n 1
echo ""

# --- 4. GitHub CLI ---
if ! command -v gh &>/dev/null; then
    echo "[4/7] Installing GitHub CLI..."
    brew install gh
else
    echo "[4/7] GitHub CLI: already installed"
fi

# --- 5. GitHub login ---
if ! gh auth status &>/dev/null; then
    echo "[5/7] Logging in to GitHub..."
    echo "      A browser will open. Log in with your personal account (Arkadiusz-Czubik)."
    echo "      Use 1Password to fill in your credentials."
    echo ""
    gh auth login -h github.com -p https -w
else
    echo "[5/7] GitHub: already logged in"
fi

# --- 6. Clone macbook-setup ---
if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    echo "[6/7] Cloning macbook-setup repo..."
    gh repo clone Arkadiusz-Czubik/macbook-setup "$HOME/.local/share/chezmoi"
else
    echo "[6/7] macbook-setup: already cloned"
fi

# --- 7. Run bootstrap ---
echo "[7/7] Running bootstrap.sh..."
echo ""
bash "$HOME/.local/share/chezmoi/.setup/bootstrap.sh"
