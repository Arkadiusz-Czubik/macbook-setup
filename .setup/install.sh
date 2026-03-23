#!/bin/bash
# =============================================================================
# INSTALL SCRIPT — ściąga seed.sh i odpala go
# =============================================================================
#
# Na świeżym Macu wystarczy jedna linia:
#   curl -fsSL https://raw.githubusercontent.com/Arkadiusz-Czubik/macbook-setup/main/.setup/install.sh | bash
#
# =============================================================================

set -e

SEED_URL="https://raw.githubusercontent.com/Arkadiusz-Czubik/macbook-setup/main/.setup/seed.sh"
TMP_SEED="/tmp/macbook-seed.sh"

curl -fsSL "$SEED_URL" -o "$TMP_SEED"
chmod +x "$TMP_SEED"
exec bash "$TMP_SEED"
