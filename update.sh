#!/usr/bin/env bash
set -e
[ "$(id -u)" -eq 0 ] || exit 1

arch=$(uname -m)
case $arch in
  x86_64|amd64) arch=x86_64-unknown-linux-gnu ;;
  aarch64|arm64) arch=aarch64-unknown-linux-gnu ;;
  *) echo "Unsupported architecture"; exit 1 ;;
esac

ver=$(curl -fsSL https://api.github.com/repos/NodePassProject/Nowhere/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')
[ -n "$ver" ] || { echo "Failed to get latest version"; exit 1; }

tmp=$(mktemp -d)
curl -fsSL -o $tmp/np.tar.gz https://github.com/NodePassProject/Nowhere/releases/download/$ver/nowhere-$arch.tar.gz || {
  echo "Failed to download"; exit 1
}
tar -xzf $tmp/np.tar.gz -C $tmp
find $tmp -name nowhere -type f -executable | head -1 | xargs -I{} install -m 755 {} /usr/local/bin/nowhere
rm -rf $tmp

systemctl restart nowhere 2>/dev/null || true
echo "Updated to $ver"
