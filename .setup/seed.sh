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
#   3. Instaluje gh (GitHub CLI)
#   4. Loguje do GitHuba (przez przeglądarkę)
#   5. Klonuje macbook-setup repo
#   6. Odpala bootstrap.sh (reszta automatycznie)
# =============================================================================

set -e

echo ""
echo "============================================"
echo "  MacBook Setup — Starting from scratch"
echo "============================================"
echo ""

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p &>/dev/null; then
    echo "[1/6] Installing Xcode Command Line Tools..."
    echo "      A dialog will pop up. Click 'Install' and wait."
    xcode-select --install
    echo ""
    echo ">>> Press any key when Xcode CLT installation finishes."
    read -n 1
else
    echo "[1/6] Xcode Command Line Tools: already installed"
fi

# --- 2. Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "[2/6] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[2/6] Homebrew: already installed"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3. GitHub CLI ---
if ! command -v gh &>/dev/null; then
    echo "[3/6] Installing GitHub CLI..."
    brew install gh
else
    echo "[3/6] GitHub CLI: already installed"
fi

# --- 4. GitHub login ---
if ! gh auth status &>/dev/null; then
    echo "[4/6] Logging in to GitHub..."
    echo "      A browser will open. Log in with your personal account (Arkadiusz-Czubik)."
    echo ""
    gh auth login -h github.com -p https -w
else
    echo "[4/6] GitHub: already logged in"
fi

# --- 5. Clone macbook-setup ---
if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    echo "[5/6] Cloning macbook-setup repo..."
    gh repo clone Arkadiusz-Czubik/macbook-setup "$HOME/.local/share/chezmoi"
else
    echo "[5/6] macbook-setup: already cloned"
fi

# --- 6. Run bootstrap ---
echo "[6/6] Running bootstrap.sh..."
echo ""
bash "$HOME/.local/share/chezmoi/.setup/bootstrap.sh"
