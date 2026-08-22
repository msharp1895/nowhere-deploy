#!/usr/bin/env bash
set -e

PORT=24
BIN=/usr/local/bin/nowhere
SVC=nowhere
UNIT=/etc/systemd/system/$SVC.service
CERT_DIR=/etc/nowhere/certs
GREEN='\033[0;32m'
NC='\033[0m'

[ "$(id -u)" -eq 0 ] || { echo "请使用 root 运行"; exit 1; }

read -p "请输入域名: " DOMAIN
DOMAIN=$(echo "$DOMAIN" | xargs)
[ -n "$DOMAIN" ] || { echo "域名不能为空"; exit 1; }

PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl tar ca-certificates socat cron >/dev/null

arch=$(uname -m)
case $arch in
  x86_64|amd64) arch=x86_64-unknown-linux-gnu ;;
  aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
  *) echo "不支持的架构"; exit 1 ;;
esac

ver=$(curl -fsSL https://api.github.com/repos/NodePassProject/Nowhere/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
tmp=$(mktemp -d)
curl -fsSL -o $tmp/np.tar.gz https://github.com/NodePassProject/Nowhere/releases/download/$ver/nowhere-$arch.tar.gz
tar -xzf $tmp/np.tar.gz -C $tmp
find $tmp -name nowhere -type f -executable | head -1 | xargs -I{} install -m 755 {} $BIN
rm -rf $tmp

[ -f /root/.acme.sh/acme.sh ] || curl -fsSL https://get.acme.sh | sh -s email=admin@$DOMAIN
. /root/.acme.sh/acme.sh.env 2>/dev/null || true

mkdir -p $CERT_DIR && chmod 700 $CERT_DIR
systemctl stop nginx apache2 caddy 2>/dev/null || true

~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --keylength 2048 --force --server letsencrypt
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
  --key-file $CERT_DIR/key.pem \
  --fullchain-file $CERT_DIR/fullchain.pem \
  --reloadcmd "systemctl restart $SVC"
chmod 600 $CERT_DIR/*.pem

cmd="portal://${PASSWORD}@:${PORT}?net=mix&tls=2&crt=${CERT_DIR}/fullchain.pem&key=${CERT_DIR}/key.pem&log=info"

cat > $UNIT <<EOF
[Unit]
Description=Nowhere Portal
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN '$cmd'
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now $SVC
sleep 2

echo -e "${GREEN}nowhere://${PASSWORD}@${DOMAIN}:${PORT}?up=udp&down=udp#Nowhere${NC}"
