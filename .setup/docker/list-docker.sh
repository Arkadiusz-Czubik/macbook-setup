#!/bin/bash
# Show current Docker state — volumes, networks, containers, images
# Useful before backup to see what you have

echo "=== Volumes ==="
docker volume ls --format 'table {{.Name}}\t{{.Driver}}'
echo ""

echo "=== Custom Networks ==="
docker network ls --format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}' | grep -v -E '^(bridge|host|none)\s'
echo ""

echo "=== Containers ==="
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo ""

echo "=== Images ==="
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -v '<none>'
echo ""

echo "=== Backups ==="
if [ -d "$HOME/docker-backups" ]; then
    ls -1d "$HOME/docker-backups"/*/ 2>/dev/null | while read dir; do
        SIZE=$(du -sh "$dir" | cut -f1)
        echo "  $(basename "$dir")  ($SIZE)"
    done
else
    echo "  No backups yet."
fi
