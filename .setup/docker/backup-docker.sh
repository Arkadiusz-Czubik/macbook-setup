#!/bin/bash
# Backup all Docker volumes, networks, and compose state
#
# Usage:
#   ./backup-docker.sh                    # backup to ~/docker-backups/
#   ./backup-docker.sh /path/to/backup    # backup to custom location

set -e

BACKUP_DIR="${1:-$HOME/docker-backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

mkdir -p "$BACKUP_PATH/volumes"

echo "=== Docker Backup ==="
echo "Destination: $BACKUP_PATH"
echo ""

# --- 1. Volumes ---
echo "[1/4] Backing up volumes..."
VOLUMES=$(docker volume ls -q)

if [ -z "$VOLUMES" ]; then
    echo "  No volumes found."
else
    for vol in $VOLUMES; do
        echo "  $vol..."
        docker run --rm \
            -v "$vol:/source:ro" \
            -v "$BACKUP_PATH/volumes:/backup" \
            alpine tar czf "/backup/$vol.tar.gz" -C /source .
    done
    echo "  $(echo "$VOLUMES" | wc -l | tr -d ' ') volume(s) backed up."
fi

# --- 2. Networks (custom only, skip defaults) ---
echo "[2/4] Saving network definitions..."
docker network ls --format '{{.Name}}' | grep -v -E '^(bridge|host|none)$' > "$BACKUP_PATH/networks.txt" 2>/dev/null || true

for net in $(cat "$BACKUP_PATH/networks.txt" 2>/dev/null); do
    docker network inspect "$net" > "$BACKUP_PATH/network-$net.json" 2>/dev/null || true
done
echo "  $(wc -l < "$BACKUP_PATH/networks.txt" 2>/dev/null | tr -d ' ') custom network(s) saved."

# --- 3. Container list (for reference, not restored) ---
echo "[3/4] Saving container list..."
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "$BACKUP_PATH/containers.txt" 2>/dev/null || true
echo "  $(wc -l < "$BACKUP_PATH/containers.txt" 2>/dev/null | tr -d ' ') container(s) listed."

# --- 4. Image list (for reference) ---
echo "[4/4] Saving image list..."
docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' > "$BACKUP_PATH/images.txt" 2>/dev/null || true
echo "  $(wc -l < "$BACKUP_PATH/images.txt" 2>/dev/null | tr -d ' ') image(s) listed."

# --- Summary ---
TOTAL_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
echo ""
echo "=== Backup complete ==="
echo "Location: $BACKUP_PATH"
echo "Size: $TOTAL_SIZE"
echo ""
echo "Contents:"
ls -la "$BACKUP_PATH/"
echo ""
echo "To restore, run:"
echo "  $(dirname "$0")/restore-docker.sh $BACKUP_PATH"
