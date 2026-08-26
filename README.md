# Nowhere Deploy

[Nowhere](https://github.com/NodePassProject/Nowhere) Portal 一键部署。DNS 指到本机，输入域名和端口，申请证书并输出 Anywhere 用的 `nowhere://` 链接。

Debian/Ubuntu + root。申请证书会占用 **80 端口**（临时停 nginx/caddy/apache，完成后拉起）。重装保留原密码。

## 安装
```bash
curl -fsSL -o /tmp/install.sh "https://raw.githubusercontent.com/msharp1895/nowhere-deploy/main/install.sh?$(date +%s)" && sudo bash /tmp/install.sh
```
## 更新
```bash
curl -fsSL -o /tmp/update.sh "https://raw.githubusercontent.com/msharp1895/nowhere-deploy/main/update.sh?$(date +%s)" && sudo bash /tmp/update.sh
```
## 卸载
```bash
curl -fsSL -o /tmp/uninstall.sh "https://raw.githubusercontent.com/msharp1895/nowhere-deploy/main/uninstall.sh?$(date +%s)" && sudo bash /tmp/uninstall.sh
```
