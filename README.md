# Nowhere Deploy

[Nowhere](https://github.com/NodePassProject/Nowhere) Portal 一键部署脚本。  
dns到域名，输入域名，设置端口，自动申请证书并生成链接。

## 安装

```bash
curl -fsSL -o /tmp/install.sh "https://raw.githubusercontent.com/msharp1895/nowhere-deploy/main/install.sh?$(date +%s)" && sudo bash /tmp/install.sh
更新（只更新二进制，配置不变）
Bashcurl -fsSL -o /tmp/update.sh "https://raw.githubusercontent.com/msharp1895/nowhere-deploy/main/update-nowhere.sh?$(date +%s)" && sudo bash /tmp/update.sh
