#!/bin/bash
# Restore Docker volumes and networks from backup
#
# Usage:
#   ./restore-docker.sh /path/to/backup              # restore all
#   ./restore-docker.sh /path/to/backup volume-name   # restore single volume

set -e

BACKUP_PATH="${1:-}"
SINGLE_VOLUME="${2:-}"

if [ -z "$BACKUP_PATH" ] || [ ! -d "$BACKUP_PATH" ]; then
    echo "Usage: $0 <backup-path> [volume-name]"
    echo ""
    echo "Available backups:"
    ls -d ~/docker-backups/*/ 2>/dev/null || echo "  No backups found in ~/docker-backups/"
    exit 1
fi

echo "=== Docker Restore ==="
echo "Source: $BACKUP_PATH"
echo ""

# --- Check what's in the backup ---
if [ ! -d "$BACKUP_PATH/volumes" ]; then
    echo "ERROR: No volumes directory in backup."
    exit 1
fi

# --- 1. Restore networks ---
if [ -z "$SINGLE_VOLUME" ] && [ -f "$BACKUP_PATH/networks.txt" ]; then
    echo "[1/2] Restoring networks..."
    while read -r net; do
        if ! docker network inspect "$net" &>/dev/null; then
            # Extract subnet from backup if available
            SUBNET=$(jq -r '.[0].IPAM.Config[0].Subnet // empty' "$BACKUP_PATH/network-$net.json" 2>/dev/null)
            if [ -n "$SUBNET" ]; then
                docker network create --subnet="$SUBNET" "$net" >/dev/null 2>&1 || true
            else
                docker network create "$net" >/dev/null 2>&1 || true
            fi
            echo "  Created: $net"
        else
            echo "  Exists: $net (skipped)"
        fi
    done < "$BACKUP_PATH/networks.txt"
else
    echo "[1/2] Networks: skipped (single volume restore)"
fi

# --- 2. Restore volumes ---
echo "[2/2] Restoring volumes..."

if [ -n "$SINGLE_VOLUME" ]; then
    # Restore single volume
    ARCHIVE="$BACKUP_PATH/volumes/$SINGLE_VOLUME.tar.gz"
    if [ ! -f "$ARCHIVE" ]; then
        echo "ERROR: Volume backup not found: $ARCHIVE"
        echo ""
        echo "Available volumes in this backup:"
        ls "$BACKUP_PATH/volumes/" | sed 's/.tar.gz$//'
        exit 1
    fi

    VOLUMES_TO_RESTORE="$SINGLE_VOLUME"
else
    # Restore all volumes
    VOLUMES_TO_RESTORE=$(ls "$BACKUP_PATH/volumes/" 2>/dev/null | sed 's/.tar.gz$//')
fi

for vol in $VOLUMES_TO_RESTORE; do
    ARCHIVE="$BACKUP_PATH/volumes/$vol.tar.gz"

    if docker volume inspect "$vol" &>/dev/null; then
        echo "  $vol: already exists. Overwrite? (y/N)"
        read -r answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "  $vol: skipped"
            continue
        fi
        # Stop containers using this volume
        CONTAINERS=$(docker ps -a --filter "volume=$vol" -q)
        if [ -n "$CONTAINERS" ]; then
            echo "  Stopping containers using $vol..."
            docker stop $CONTAINERS 2>/dev/null || true
        fi
    else
        docker volume create "$vol" >/dev/null
    fi

    echo "  Restoring $vol..."
    docker run --rm \
        -v "$vol:/target" \
        -v "$(cd "$BACKUP_PATH/volumes" && pwd):/backup:ro" \
        alpine sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null; tar xzf /backup/$vol.tar.gz -C /target"

    echo "  $vol: restored"
done

echo ""
echo "=== Restore complete ==="
echo ""
echo "Restored from: $BACKUP_PATH"
echo ""
echo "Next steps:"
echo "  - Pull images:  cat $BACKUP_PATH/images.txt | xargs -L1 docker pull"
echo "  - Start services with docker compose"
