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
#   3. Klonuje macbook-setup repo (publiczne, bez auth)
#   4. Odpala bootstrap.sh (reszta automatycznie)
# =============================================================================

set -e

echo ""
echo "============================================"
echo "  MacBook Setup — Starting from scratch"
echo "============================================"
echo ""

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p &>/dev/null; then
    echo "[1/4] Installing Xcode Command Line Tools..."
    echo "      A dialog will pop up. Click 'Install' and wait."
    xcode-select --install
    echo ""
    echo ">>> Press any key when Xcode CLT installation finishes."
    read -n 1
else
    echo "[1/4] Xcode Command Line Tools: already installed"
fi

# --- 2. Homebrew ---
if ! command -v brew &>/dev/null; then
    echo "[2/4] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "[2/4] Homebrew: already installed"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3. Clone macbook-setup (public repo, no auth needed) ---
if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    echo "[3/4] Cloning macbook-setup repo..."
    git clone https://github.com/Arkadiusz-Czubik/macbook-setup.git "$HOME/.local/share/chezmoi"
else
    echo "[3/4] macbook-setup: already cloned (updating...)"
    cd "$HOME/.local/share/chezmoi" && git pull
fi

# --- 4. Run bootstrap ---
echo "[4/4] Running bootstrap.sh..."
echo ""
bash "$HOME/.local/share/chezmoi/.setup/bootstrap.sh"
