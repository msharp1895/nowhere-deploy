#!/usr/bin/env bash
set -e

KOMARI_PORT=25774

[ "$(id -u)" -eq 0 ] || { echo "请使用 sudo 运行"; exit 1; }

[ -f /etc/nowhere/certs/fullchain.pem ] && [ -f /etc/nowhere/certs/key.pem ] || {
  echo "未找到 Nowhere 证书: /etc/nowhere/certs/"
  exit 1
}

# 从证书自动获取域名
DOMAIN=$(openssl x509 -in /etc/nowhere/certs/fullchain.pem -noout -text 2>/dev/null | grep -oP 'DNS:\K[^, ]+' | head -1)
[ -z "$DOMAIN" ] && DOMAIN=$(openssl x509 -in /etc/nowhere/certs/fullchain.pem -noout -subject 2>/dev/null | grep -oP 'CN\s*=\s*\K[^/]+')
[ -n "$DOMAIN" ] || { echo "无法从证书识别域名"; exit 1; }

echo "检测到域名: $DOMAIN"

echo "[1/3] 安装 Nginx"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq nginx >/dev/null

echo "[2/3] 复制证书给 Nginx"
mkdir -p /etc/nginx/ssl/komari
cp /etc/nowhere/certs/key.pem /etc/nginx/ssl/komari/key.pem
cp /etc/nowhere/certs/fullchain.pem /etc/nginx/ssl/komari/fullchain.pem
chmod 600 /etc/nginx/ssl/komari/*.pem

echo "[3/3] 配置 Nginx HTTPS"
cat > /etc/nginx/sites-available/komari << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate     /etc/nginx/ssl/komari/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/komari/key.pem;

    location / {
        proxy_pass http://127.0.0.1:${KOMARI_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_buffering off;
        client_max_body_size 50M;
    }
}
EOF

ln -sf /etc/nginx/sites-available/komari /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

echo
echo "完成 → https://${DOMAIN}"
