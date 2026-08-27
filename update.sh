#!/usr/bin/env bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "请用 root 运行" >&2; exit 1; }
[ -x /usr/local/bin/nowhere ] || { echo "未安装，请先 install.sh" >&2; exit 1; }

case "$(uname -m)" in
  x86_64|amd64) arch=x86_64-unknown-linux-gnu ;;
  aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
  *) echo "不支持的架构: $(uname -m)" >&2; exit 1 ;;
esac

json=$(curl -fL --connect-timeout 8 --max-time 20 -H "User-Agent: nowhere-deploy" \
  https://api.github.com/repos/NodePassProject/Nowhere/releases/latest 2>/dev/null || true)
ver=$(printf '%s' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
if [ -n "$ver" ]; then
  url="https://github.com/NodePassProject/Nowhere/releases/download/${ver}/nowhere-${arch}.tar.gz"
else
  ver=latest
  url="https://github.com/NodePassProject/Nowhere/releases/latest/download/nowhere-${arch}.tar.gz"
fi

tmp=$(mktemp -d)
curl -fL --connect-timeout 10 --max-time 120 --retry 2 -o "$tmp/np.tar.gz" "$url" \
  || { rm -rf "$tmp"; echo "下载失败（GitHub 超时或无法访问）" >&2; exit 1; }
tar -xzf "$tmp/np.tar.gz" -C "$tmp"
bin=$(find "$tmp" -name nowhere -type f | head -1)
[ -n "$bin" ] || { rm -rf "$tmp"; echo "压缩包里没有 nowhere" >&2; exit 1; }
install -m 755 "$bin" /usr/local/bin/nowhere
rm -rf "$tmp"
systemctl restart nowhere
echo "Updated to $ver"
