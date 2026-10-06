# ysp-live

央视频全频道直播代理（64 路，含 4K / 8K、高码率央视、省级卫视与 7 天回看），基于上游 ysp-live v8.1 修改，
由 GitHub Actions 构建 `linux/amd64` + `linux/arm64` 镜像发布到 GHCR，适合在软路由（iStoreOS / OpenWrt）、NAS 上用 Docker 运行。

上游原版说明见 [README-DOCKER.md](README-DOCKER.md)（保持原样，便于和后续上游版本对比）。

## 与上游的区别

上游让同一个设备身份去获取全部 26 路高码率频道。实测央视频会对单个设备做风控：
一个设备成功获取约 4～13 个不同频道的 4K 链接后，`live/v1/01` 就会一直返回 HTTP 400，或 VDN 返回「内部错误」，
之后所有频道只能回退 1080p，且每次请求要等约 40 秒，播放器直接超时。加大请求间隔没有帮助（15 秒间隔下 4 个就被封）。
封禁针对设备身份，不针对 IP：同一出口 IP 换一个新设备立即恢复。

本仓库的改动：

| 改动 | 说明 |
|---|---|
| 主动换设备 | 每个设备获取 `YSP_LINKS_PER_DEVICE`（默认 4）个 4K 链接后，自动注册新设备 |
| 被拒立即换设备 | 遇到 `live/v1/01 HTTP 400` 或 VDN 内部错误时立即换设备（10 秒内最多一次），新注册的设备一上来就不可用时也适用 |
| 启动时换新设备 | 计数只在内存里，重启后无法得知旧设备剩余额度，因此每次启动都用新设备 |
| 失败兜底 | 连续失败 `YSP_IDENTITY_RESET_THRESHOLD`（默认 3）次后重置身份并删除设备文件（上游此功能默认关闭，且重置后仍复用旧设备） |
| 高码率频道可配置 | 通过 `YSP_HIGHRATE_CHANNELS` 指定走 4K / 高码率接口的频道 |
| 4K 分片可缓存 | 上游分片缓存单片上限 15MB，而 CCTV-4K 一个 3～4 秒的分片约 16～21MB，4K 实际从不缓存；单片上限提高到 40MB |
| 兜底引擎只监听本机 | 上游 Node.js 兜底引擎默认监听 `0.0.0.0:8787`，且 `/segment?url=` 与主程序的 `/engine_proxy?url=` 都能代理任意地址；改为引擎只监听 `127.0.0.1`，`/engine_proxy` 只转发到本机引擎 |

已缓存的链接自带获取时设备的签名，换设备后在过期（10 分钟）前仍可继续播放。

## 线路与兜底

频道按以下顺序获取，前一级失败自动落到下一级：

1. 设备协议 4K / 高码率（`YSP_HIGHRATE_CHANNELS` 中的频道）
2. 1080p JCE 解析
3. bkliveinfo 备用线路
4. 网页版兜底引擎（容器内的 Node.js 进程 `ysp-engine.js`，只在前三级都拿不到播放列表时使用）

## 部署

> 必须运行在**家庭宽带**下。设备注册会被机房 IP 拒绝，不要部署到 VPS / 云服务器。

只需要一个 `docker-compose.yml`，镜像已经构建好，无需在设备上编译。

```bash
mkdir -p /opt/ysp-live-docker && cd /opt/ysp-live-docker
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/evanzme/ysp-live/main/docker-compose.yml
docker compose pull && docker compose up -d
```

查看日志，出现 `真4K 频道预热就绪` 即启动完成（约 30 秒）：

```bash
docker logs -f ysp-live
```

预热完成后日志会停止滚动，直到有人打开频道，这是正常的。

### iStoreOS / OpenWrt 说明

- 通过 SSH（`ssh root@路由器IP`）或后台「终端（TTYD）」执行上面的命令。
- 系统自带 `curl`，不需要安装 `git`。
- 若提示 `docker: 'compose' is not a docker command`，把命令里的 `docker compose` 换成 `docker-compose`。
- 若无法访问 `raw.githubusercontent.com`，可在电脑上下载 `docker-compose.yml` 后用 `scp -O` 传到路由器。

## 使用

在播放器（APTV、TiviMate、OTT Navigator 等）中添加订阅：

```
http://<路由器局域网IP>:8767/all.m3u
```

注意填路由器的局域网 IP，不要用 `localhost` / `127.0.0.1`（那会指向播放设备自己）。

| 地址 | 内容 |
|---|---|
| `/` | 服务状态与入口（纯文本） |
| `/all.m3u` | 64 路聚合订阅，含 EPG 与 7 天回看 |
| `/<频道>.m3u8` | 单个频道，如 `/cctv4k.m3u8`、`/cctv13.m3u8` |
| `/all.m3u?group=卫视` | 只订阅某个分组（`央视` / `卫视`） |
| `/health` | JSON 健康信息：运行时间、设备会话、分片缓存命中率 |
| `/diag` | 诊断信息：设备会话状态、分片缓存与各频道刷新情况 |

### 播放建议

- **关闭 APTV 延迟检测**。订阅已带 `#EXT-X-APTV-LATENCY: FALSE`，APTV 会自动关闭；其他播放器若有类似功能也建议关掉。延迟检测会一次性请求全部频道，首次解析需要排队和换设备，后面的频道容易超时。
- **首次打开频道可能需要 3～20 秒**（恰好需要换设备时较慢），之后 10 分钟内为缓存，秒开。
- **4K / 8K 频道码率很高**（CCTV-4K 约 36 Mbps），播放设备网络需稳定在 50 Mbps 以上，并建议开启播放器的硬件解码。
- 只有 CCTV-4K、CCTV-8K、CCTV-16 4K 是真 4K / 8K。其余央视频道的「高码率」是约 12 Mbps 的 1080i50（H.264，SDR），比普通 1080p 源清晰，但分辨率仍是 1080。

## 配置

在 `docker-compose.yml` 的 `environment` 中设置：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `YSP_LINKS_PER_DEVICE` | `4` | 每个设备获取多少个 4K 链接后主动换设备；`0` 为不主动更换。日志中仍频繁出现 HTTP 400 时可改为 `3` |
| `YSP_IDENTITY_RESET_THRESHOLD` | `3` | 连续失败多少次后重置设备身份（兜底）；`0` 为关闭 |
| `YSP_HIGHRATE_CHANNELS` | 全部 26 路 | 走 4K / 高码率接口的频道，逗号分隔；其余频道走 1080p。例：`cctv4k,cctv8k,cctv164k,cctv5,cctv5p` |
| `YSP_CACHE_MB` | `100` | 分片内存缓存大小（MB）。多台设备同看 4K 时可调大，如 `300` |
| `TZ` | `Asia/Shanghai` | 日志时区 |

默认 26 路高码率频道：`cctv1`～`cctv5p`、`cctv7`～`cctv17`、`cctv4k`、`cctv8k`、`cctv164k`、`cgtn`、`cgtnfr`、`cgtnru`、`cgtnar`、`cgtnes`、`cgtndoc`。

修改后执行 `docker compose up -d` 生效。

## 更新

```bash
cd /opt/ysp-live-docker && docker compose pull && docker compose up -d
```

`./data` 中只保存当前设备身份，删除不影响使用（启动时本来就会换新设备）。

## 日志说明

| 日志 | 含义 |
|---|---|
| `设备 XXX 已获取 4 个 4K 链接，主动更换新设备` | 正常轮换 |
| `设备 XXX 请求被拒 (...)，主动更换新设备` | 设备被风控，已自动换新 |
| `4K/高码率 xxx 获取失败: ...，回退 1080p` | 本次未拿到高码率链接，临时用 1080p 播放，冷却后重试 |
| `地址疑似过期, 已重取`、`无人观看, 停止刷新` | 1080p 线路的正常刷新与闲置回收 |
| 空行或两条日志挤在同一行 | 多线程同时输出，不影响功能 |

## 排查

1. 浏览器打开 `http://<路由器IP>:8767/all.m3u`，能看到频道列表说明服务正常。
2. 打开 `/diag`：`Session: 有效` 表示设备会话正常；频道显示 `上次刷新=xx前` 表示已拿到链接。
3. 统计风控错误：`docker logs ysp-live 2>&1 | grep -cE "HTTP 400|VDN did not"`。
4. 若路由器开了 OpenClash / PassWall 等代理，确认路由器本机出口是国内 IP：`curl -s https://myip.ipip.net`。

## 构建与同步上游

推送到 `main` 分支或打 `v*` 标签时，[.github/workflows/docker.yml](.github/workflows/docker.yml) 会构建多架构镜像并推送到
`ghcr.io/evanzme/ysp-live`（`latest`、`sha-<提交>`、标签名）。

上游发布新版本时：

1. 用上游的 `ysp-live.py`、`ysp-engine.js`、`README.md`（存为 `README-DOCKER.md`）覆盖本仓库文件，单独提交一次「Update to upstream vX.Y」。`Dockerfile` 只参考上游的依赖变化，不直接覆盖。
   上游若整体重新排版了 `ysp-live.py`（如 v8.1），可用 `ast.unparse` 规范化前后两个版本再比较，只移植实际改动。
2. 重新应用本仓库对 `ysp-live.py` 的改动（可参考 `git log` 中上游提交之后的各次提交），确认 `python3 -m py_compile ysp-live.py` 通过。
3. 推送后等 Actions 完成，在设备上执行更新命令。
