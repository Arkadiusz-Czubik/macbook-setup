#!/bin/bash
# Run Claude Code in yolo mode (bypassPermissions) inside an isolated container
#
# Usage:
#   ./run-yolo.sh personal                    # current dir, personal account (max)
#   ./run-yolo.sh work                        # current dir, work account (teams)
#   ./run-yolo.sh personal /path/to/project   # specific project, personal account

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse arguments ---
PROFILE="${1:-}"
PROJECT_DIR="${2:-$(pwd)}"

if [ "$PROFILE" != "personal" ] && [ "$PROFILE" != "work" ]; then
    echo "Usage: $0 <personal|work> [/path/to/project]"
    echo ""
    echo "  personal  — uses ~/.claude-personal config (max plan)"
    echo "  work      — uses ~/.claude-work config (teams plan)"
    exit 1
fi

CONFIG_DIR="$HOME/.claude-$PROFILE"
IMAGE_NAME="claude-yolo"

# --- Verify config dir exists ---
if [ ! -f "$CONFIG_DIR/.claude.json" ]; then
    echo "ERROR: $CONFIG_DIR/.claude.json not found."
    echo "Run 'clp' or 'clw' first and sign in to create auth tokens."
    exit 1
fi

# --- Check Docker ---
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running. Start Docker Desktop first."
    exit 1
fi

# --- Build image ---
echo "Building devcontainer image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

echo ""
echo "=== Claude Code YOLO Mode ==="
echo "Profile:   $PROFILE"
echo "Project:   $PROJECT_DIR"
echo "Config:    $CONFIG_DIR (read-only)"
echo "Isolation: Docker container (non-root, network firewall)"
echo "Permissions: bypassPermissions (full auto)"
echo ""

docker run -it --rm \
    --name "claude-yolo-$PROFILE" \
    --cap-add NET_ADMIN \
    -v "$PROJECT_DIR:/workspace" \
    -v "$CONFIG_DIR/.claude.json:/home/dev/.claude.json:ro" \
    "$IMAGE_NAME" \
    bash -c "sudo /usr/local/bin/firewall.sh && claude --dangerously-skip-permissions"
