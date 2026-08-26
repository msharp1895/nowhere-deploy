#!/usr/bin/env bash
set -euo pipefail
BIN=/usr/local/bin/nowhere
SVC=nowhere
UNIT=/etc/systemd/system/$SVC.service
DIR=/etc/nowhere
CERT=$DIR/certs
ENV=$DIR/portal.env
ACME=/root/.acme.sh/acme.sh
G='\033[1;32m'; C='\033[1;36m'; R='\033[1;31m'; N='\033[0m'
err() { echo -e "\n${R}$*${N}" >&2; exit 1; }
progress() { echo -ne "\033[2K\r${C}[$1/6] $2...${N}"; }
ok() { echo -ne "\033[2K\r"; }

[ "$(id -u)" -eq 0 ] || err "请用 root 运行"
command -v apt-get >/dev/null || err "仅支持 Debian/Ubuntu"

PASS=""; DOMAIN0=""; PORT0=""
if [ -f "$ENV" ]; then . "$ENV"; PASS=${NOWHERE_PASSWORD-}; DOMAIN0=${NOWHERE_DOMAIN-}; PORT0=${NOWHERE_PORT-}; fi
if [ -z "$PASS" ] && [ -f "$UNIT" ]; then PASS=$(sed -n 's/.*portal:\/\/\([^@]*\)@:.*/\1/p' "$UNIT" | head -1); fi

read -r -p "Domain${DOMAIN0:+ [$DOMAIN0]}: " DOMAIN
DOMAIN=$(echo "${DOMAIN:-$DOMAIN0}" | xargs)
[ -n "$DOMAIN" ] || err "Domain 不能为空"
read -r -p "Port${PORT0:+ [$PORT0]}: " PORT
PORT=$(echo "${PORT:-$PORT0}" | xargs)
[[ "$PORT" =~ ^[1-9][0-9]{0,4}$ && "$PORT" -le 65535 && "$PORT" -ne 80 ]] || err "Port 须为 1-65535，且不能是 80"
[ -n "$PASS" ] || PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

web=()
restore() { for s in "${web[@]+"${web[@]}"}"; do systemctl start "$s" 2>/dev/null || true; done; }
trap restore EXIT

progress 1 "Installing dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl tar ca-certificates socat
ok

progress 2 "Downloading Nowhere"
case "$(uname -m)" in
  x86_64|amd64) arch=x86_64-unknown-linux-gnu ;;
  aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
  *) err "不支持的架构: $(uname -m)" ;;
esac
json=$(curl -fsSL -H "User-Agent: nowhere-deploy" https://api.github.com/repos/NodePassProject/Nowhere/releases/latest)
ver=$(printf '%s' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
[ -n "$ver" ] || err "无法获取版本"
digest=$(printf '%s' "$json" | sed 's/},{/}\n{/g' | grep -F "nowhere-$arch.tar.gz" | sed -n 's/.*"digest": *"sha256:\([^"]*\)".*/\1/p' | head -1)
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/np.tar.gz" "https://github.com/NodePassProject/Nowhere/releases/download/$ver/nowhere-$arch.tar.gz"
if [ -n "$digest" ]; then
  [ "$(sha256sum "$tmp/np.tar.gz" | awk '{print $1}')" = "$digest" ] || { rm -rf "$tmp"; err "校验失败"; }
fi
tar -xzf "$tmp/np.tar.gz" -C "$tmp"
bin=$(find "$tmp" -name nowhere -type f | head -1)
[ -n "$bin" ] || { rm -rf "$tmp"; err "压缩包里没有 nowhere"; }
install -m 755 "$bin" "$BIN"
rm -rf "$tmp"
ok

progress 3 "Installing acme.sh"
[ -x "$ACME" ] || curl -fsSL https://get.acme.sh | sh >/dev/null
[ -x "$ACME" ] || err "acme.sh 安装失败"
. /root/.acme.sh/acme.sh.env 2>/dev/null || true
ok

progress 4 "Requesting certificate"
mkdir -p "$CERT"; chmod 700 "$DIR" "$CERT"
if [ "$DOMAIN" != "$DOMAIN0" ] || [ ! -s "$CERT/fullchain.pem" ] || [ ! -s "$CERT/key.pem" ]; then
  for s in nginx apache2 caddy; do
    if systemctl is-active --quiet "$s" 2>/dev/null; then web+=("$s"); systemctl stop "$s"; fi
  done
  "$ACME" --issue -d "$DOMAIN" --standalone --keylength 2048 --server letsencrypt \
    || err "证书申请失败：检查 DNS 和 80 端口"
fi
"$ACME" --install-cert -d "$DOMAIN" --key-file "$CERT/key.pem" --fullchain-file "$CERT/fullchain.pem" \
  --reloadcmd "systemctl restart $SVC"
chmod 600 "$CERT"/*.pem
restore; web=()
ok

progress 5 "Creating service"
umask 077
printf 'NOWHERE_PASSWORD=%s\nNOWHERE_DOMAIN=%s\nNOWHERE_PORT=%s\nNOWHERE_VERSION=%s\n' \
  "$PASS" "$DOMAIN" "$PORT" "$ver" >"$ENV"
chmod 600 "$ENV"
cat >"$UNIT" <<EOF
[Unit]
Description=Nowhere Portal
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
EnvironmentFile=$ENV
ExecStart=$BIN portal://\${NOWHERE_PASSWORD}@:\${NOWHERE_PORT}?net=mix\&tls=2\&crt=$CERT/fullchain.pem\&key=$CERT/key.pem\&log=info
Restart=always
RestartSec=3
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$SVC"
ok

progress 6 "Done"
ok
systemctl is-active --quiet "$SVC" || err "启动失败: journalctl -u $SVC -n 30"
echo -e "${G}nowhere://${PASS}@${DOMAIN}:${PORT}?up=udp&down=udp#Nowhere${N}"
