#!/bin/bash
# Apply fixes to a running docker-atrust container.
# Usage: ./patch_atrust_container.sh [container_name]
# Default container name: atrust

CONTAINER="${1:-atrust}"

set -e

echo "Patching container: $CONTAINER"

# Fix 1: danted.conf.sample — run danted workers as root (uid=0) instead of socks (uid=997).
# Without this, xtunnel can't find danted worker processes by uid+inode and drops all SOCKS connections.
docker exec "$CONTAINER" sed -i \
  's/user\.notprivileged: socks/user.notprivileged: root/' \
  /etc/danted.conf.sample

# Fix 2: vpn-config.sh — add uid policy route for aTrustCore (sangfor, uid=1234).
# Without this, aTrustCore's traffic to the VPN server goes through utun7, xtunnel intercepts
# it and the SSL connection loops/fails. Route uid=1234 via table 2 (eth0) to bypass utun7.
docker exec "$CONTAINER" grep -q "uidrange 1234-1234" /usr/local/bin/vpn-config.sh || \
  docker exec "$CONTAINER" sed -i \
    '/FAKE_LOGIN=sangfor/i\\t\t\tip rule add uidrange 1234-1234 table 2 2>\/dev\/null || true' \
    /usr/local/bin/vpn-config.sh

# Apply danted fix to the live config and restart danted (no full container restart needed).
docker exec "$CONTAINER" sed -i \
  's/user\.notprivileged: socks/user.notprivileged: root/' \
  /run/danted.conf 2>/dev/null || true
docker exec "$CONTAINER" sh -c "killall danted 2>/dev/null; sleep 1; danted -D -f /run/danted.conf"

# Apply ip rule immediately (idempotent).
docker exec "$CONTAINER" ip rule add uidrange 1234-1234 table 2 2>/dev/null || true

echo "Done. SOCKS proxy on port 1080 should be working now."
