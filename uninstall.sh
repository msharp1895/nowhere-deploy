#!/usr/bin/env bash
set -euo pipefail
UNIT=/etc/systemd/system/nowhere.service
DIR=/etc/nowhere
ACME=/root/.acme.sh/acme.sh
[ "$(id -u)" -eq 0 ] || { echo "请用 root 运行" >&2; exit 1; }
DOMAIN=""
[ -f "$DIR/portal.env" ] && . "$DIR/portal.env" && DOMAIN=${NOWHERE_DOMAIN-}
systemctl disable --now nowhere 2>/dev/null || true
rm -f "$UNIT" /usr/local/bin/nowhere
systemctl daemon-reload 2>/dev/null || true
rm -rf "$DIR"
[ -n "$DOMAIN" ] && [ -x "$ACME" ] && "$ACME" --remove -d "$DOMAIN" >/dev/null 2>&1 || true
echo "Nowhere 已卸载"
