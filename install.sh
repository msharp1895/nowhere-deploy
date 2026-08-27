#!/usr/bin/env bash
set -e

BIN=/usr/local/bin/nowhere
SVC=nowhere
UNIT=/etc/systemd/system/$SVC.service
CERT_DIR=/etc/nowhere/certs
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

[ "$(id -u)" -eq 0 ] || exit 1

read -p "Domain: " DOMAIN
DOMAIN=$(echo "$DOMAIN" | xargs)
[ -n "$DOMAIN" ] || exit 1

read -p "Port: " PORT
PORT=$(echo "$PORT" | xargs)
[ -n "$PORT" ] || exit 1

PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

progress() {
  echo -ne "${CYAN}[$1/6] $2...${NC}\r"
}

progress 1 "Installing dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq curl tar ca-certificates socat >/dev/null 2>&1 || true
echo -ne "\033[2K"

progress 2 "Downloading Nowhere"
arch=$(uname -m)
case $arch in
  x86_64|amd64) arch=x86_64-unknown-linux-gnu ;;
  aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
  *) echo -e "\n${RED}Unsupported architecture: $arch${NC}"; exit 1 ;;
esac
ver=$(curl -fsSL https://api.github.com/repos/NodePassProject/Nowhere/releases/latest 2>/dev/null | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
[ -n "$ver" ] || { echo -e "\n${RED}Failed to get latest version${NC}"; exit 1; }
tmp=$(mktemp -d)
curl -fsSL -o $tmp/np.tar.gz https://github.com/NodePassProject/Nowhere/releases/download/$ver/nowhere-$arch.tar.gz 2>/dev/null || {
  echo -e "\n${RED}Failed to download Nowhere${NC}"; exit 1
}
tar -xzf $tmp/np.tar.gz -C $tmp >/dev/null 2>&1
find $tmp -name nowhere -type f -executable | head -1 | xargs -I{} install -m 755 {} $BIN
rm -rf $tmp
echo -ne "\033[2K"

progress 3 "Installing acme.sh"
[ -f /root/.acme.sh/acme.sh ] || curl -fsSL https://get.acme.sh 2>/dev/null | sh >/dev/null 2>&1
. /root/.acme.sh/acme.sh.env 2>/dev/null || true
echo -ne "\033[2K"

progress 4 "Requesting certificate"
mkdir -p $CERT_DIR && chmod 700 $CERT_DIR
systemctl stop nginx apache2 caddy 2>/dev/null || true
if ! ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength 2048 --force --server letsencrypt >/dev/null 2>&1; then
  echo -e "\n${RED}Certificate request failed. Check domain DNS and port 80.${NC}"
  exit 1
fi
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --key-file $CERT_DIR/key.pem \
  --fullchain-file $CERT_DIR/fullchain.pem \
  --reloadcmd "systemctl restart $SVC" >/dev/null 2>&1 || true
chmod 600 $CERT_DIR/*.pem
echo -ne "\033[2K"

progress 5 "Creating service"
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
systemctl daemon-reload >/dev/null 2>&1
systemctl enable --now $SVC >/dev/null 2>&1
echo -ne "\033[2K"

progress 6 "Done"
sleep 1
echo -ne "\033[2K"

if ! systemctl is-active --quiet $SVC; then
  echo -e "\n${RED}Service failed to start. Check: journalctl -u $SVC -n 30${NC}"
  exit 1
fi

echo
echo -e "${GREEN}nowhere://${PASSWORD}@${DOMAIN}:${PORT}?up=udp&down=udp#Nowhere${NC}"
echo
