#!/usr/bin/env bash
set -euo pipefail
BIN=/usr/local/bin/nowhere
SVC=nowhere
ENV=/etc/nowhere/portal.env
err() { echo "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || err "请用 root 运行"
[ -x "$BIN" ] || err "未安装，请先 install.sh"
[ -f "$ENV" ] && . "$ENV" || true

case "$(uname -m)" in
  x86_64|amd64) arch=x86_64-unknown-linux-gnu ;;
  aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
  *) err "不支持的架构: $(uname -m)" ;;
esac
json=$(curl -fsSL -H "User-Agent: nowhere-deploy" https://api.github.com/repos/NodePassProject/Nowhere/releases/latest)
ver=$(printf '%s' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
[ -n "$ver" ] || err "无法获取版本"
if [ "${NOWHERE_VERSION-}" = "$ver" ] && systemctl is-active --quiet "$SVC"; then
  echo "Already on $ver"; exit 0
fi
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
if [ -f "$ENV" ]; then
  grep -q '^NOWHERE_VERSION=' "$ENV" && sed -i "s/^NOWHERE_VERSION=.*/NOWHERE_VERSION=$ver/" "$ENV" || echo "NOWHERE_VERSION=$ver" >>"$ENV"
fi
systemctl restart "$SVC"
systemctl is-active --quiet "$SVC" || err "启动失败: journalctl -u $SVC -n 30"
echo "Updated to $ver"
