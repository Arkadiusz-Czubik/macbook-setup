#!/bin/bash
# Network firewall for yolo devcontainer
# Only allows outbound to essential domains
# Run as root: sudo /usr/local/bin/firewall.sh

set -e

# Flush existing rules
iptables -F OUTPUT

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow DNS (needed to resolve domains below)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow established connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allowed domains — resolve and allow their IPs
ALLOWED_DOMAINS=(
    # Claude API
    "api.anthropic.com"
    "api.claude.ai"
    "sentry.io"
    "statsig.anthropic.com"
    # GitHub
    "github.com"
    "api.github.com"
    # Package registries
    "registry.npmjs.org"
    "pypi.org"
    "files.pythonhosted.org"
)

for domain in "${ALLOWED_DOMAINS[@]}"; do
    for ip in $(dig +short "$domain" 2>/dev/null); do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            iptables -A OUTPUT -d "$ip" -j ACCEPT
        fi
    done
done

# Block everything else
iptables -A OUTPUT -j DROP

echo "Firewall active. Allowed domains:"
printf '  %s\n' "${ALLOWED_DOMAINS[@]}"
