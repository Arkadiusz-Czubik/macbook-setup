#!/bin/bash
# Entrypoint for yolo devcontainer

# TODO: re-enable firewall after fixing domain resolution
# sudo /usr/local/bin/firewall.sh 2>/dev/null

exec claude --dangerously-skip-permissions
