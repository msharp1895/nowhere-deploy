#!/usr/bin/env bash
set -e
[ "$(id -u)" -eq 0 ] || exit 1

systemctl stop nowhere 2>/dev/null || true
systemctl disable nowhere 2>/dev/null || true
rm -f /etc/systemd/system/nowhere.service
systemctl daemon-reload

rm -f /usr/local/bin/nowhere
rm -rf /etc/nowhere
rm -rf /root/.acme.sh

echo "Nowhere 已卸载"
