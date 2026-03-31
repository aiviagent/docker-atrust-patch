# aTrust Docker 使用说明

## 首次启动 / 更新镜像后

```bash
# 1. 启动容器
./start_vpn.sh

# 2. 打补丁（必须在登录 VPN 之前执行）
./patch_atrust_container.sh

# 3. 用 VNC 登录 aTrust
open vnc://localhost:5901
# 密码: ai.trust
```

## 日常使用

容器已在运行且已打过补丁，直接用 SOCKS5 代理：

```
Host: 127.0.0.1  Port: 1080  Protocol: SOCKS5
```

## 补丁说明（patch_atrust_container.sh 做了什么）

| 问题 | 修复 |
|------|------|
| danted worker 进程以 uid=997(socks) 运行，xtunnel 无法通过 uid+inode 找到进程，丢弃所有 SOCKS 连接 | 将 danted 配置 `user.notprivileged` 改为 `root` |
| aTrustCore (uid=1234/sangfor) 连接 VPN 服务器的流量被 utun7 拦截，xtunnel 处理后 SSL 循环失败 | 添加策略路由 `ip rule add uidrange 1234-1234 table 2`，使 sangfor 进程走 eth0 绕过 VPN 隧道 |

## 文件说明

- `start_vpn.sh` — docker run 命令
- `patch_atrust_container.sh` — 补丁脚本，幂等，可重复执行
