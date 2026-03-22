#!/bin/bash
# Run Claude Code in yolo mode (bypassPermissions) inside an isolated container
#
# Usage:
#   ./run-yolo.sh personal                    # current dir, personal account (max)
#   ./run-yolo.sh work                        # current dir, work account (teams)
#   ./run-yolo.sh personal /path/to/project   # specific project, personal account
#   ./run-yolo.sh personal --login            # login only (first time setup)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse arguments ---
PROFILE="${1:-}"
PROJECT_DIR="${2:-$(pwd)}"
LOGIN_ONLY=false

if [ "$PROFILE" != "personal" ] && [ "$PROFILE" != "work" ]; then
    echo "Usage: $0 <personal|work> [/path/to/project|--login]"
    echo ""
    echo "  personal  — uses personal account (max plan)"
    echo "  work      — uses work account (teams plan)"
    echo "  --login   — login only (run once to set up auth)"
    exit 1
fi

if [ "$PROJECT_DIR" = "--login" ]; then
    LOGIN_ONLY=true
    PROJECT_DIR="/tmp"
fi

IMAGE_NAME="claude-yolo"
VOLUME_NAME="claude-yolo-auth-$PROFILE"

# --- Check Docker ---
if ! docker info &>/dev/null; then
    echo "ERROR: Docker is not running. Start Docker Desktop first."
    exit 1
fi

# --- Build image ---
echo "Building devcontainer image..."
docker build -q -t "$IMAGE_NAME" "$SCRIPT_DIR"

# --- Check if auth volume exists ---
if ! docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    echo ""
    echo "First time setup for profile '$PROFILE'."
    echo "Creating auth volume '$VOLUME_NAME'."
    docker volume create "$VOLUME_NAME" >/dev/null
    LOGIN_ONLY=true
fi

if [ "$LOGIN_ONLY" = true ]; then
    echo ""
    echo "=== Login Mode ==="
    echo "Claude Code will start — run /login inside it."
    echo "After logging in, type /exit and run again without --login."
    echo ""
    docker run -it --rm \
        --name "claude-yolo-$PROFILE-login" \
        --entrypoint claude \
        -v "$VOLUME_NAME:/home/dev" \
        "$IMAGE_NAME"
    exit 0
fi

echo ""
echo "=== Claude Code YOLO Mode ==="
echo "Profile:   $PROFILE"
echo "Project:   $PROJECT_DIR"
echo "Auth:      Docker volume '$VOLUME_NAME'"
echo "Isolation: Docker container (non-root, network firewall)"
echo "Permissions: bypassPermissions (full auto)"
echo ""

docker run -it --rm \
    --name "claude-yolo-$PROFILE" \
    --cap-add NET_ADMIN \
    -v "$PROJECT_DIR:/workspace" \
    -v "$VOLUME_NAME:/home/dev" \
    "$IMAGE_NAME"
