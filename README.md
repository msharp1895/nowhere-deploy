# Nowhere Deploy

[Nowhere](https://github.com/NodePassProject/Nowhere) Portal 一键部署脚本（适配Nowhere 3.0）。

域名解析到本机后，输入域名和端口，自动申请 Let's Encrypt 证书并启动 Portal 服务。

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
