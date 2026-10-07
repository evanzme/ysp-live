# ysp-live

央视频全频道直播代理（64 路，含 4K / 8K、高码率央视、省级卫视与 7 天回看），基于上游 ysp-live v9.0 修改，
由 GitHub Actions 构建 `linux/amd64` + `linux/arm64` 镜像发布到 GHCR，适合在软路由（iStoreOS / OpenWrt）、NAS 上用 Docker 运行。

上游原版说明见 [README-DOCKER.md](README-DOCKER.md)（保持原样，便于和后续上游版本对比）。

## 与上游的区别

`ysp-live.py`、`ysp-engine.js` 与上游 v9.0 完全一致，本仓库只提供：

- GitHub Actions 构建的 `linux/amd64` + `linux/arm64` 镜像，设备上无需编译
- 适合软路由的 `docker-compose.yml`：host 网络模式、单设备配额 `YSP_LINKS_PER_DEVICE=4`、日志大小上限

背景：央视频会对单个设备做风控，一个设备成功获取约 4～13 个不同频道的高码率链接后，`live/v1/01` 会返回 HTTP 400，
或 VDN 返回「内部错误」。封禁针对设备身份，不针对 IP。上游 v9.0 起自带换设备机制：单设备配额（上游默认 6）、
后台常驻一台热备设备、达到配额或被拒时切换到热备设备并当场重试。实测单设备最少 4 个、多数 7～10 个后被拒，因此 compose 中配额设为 4。

注意事项（上游行为，未修改）：

- 配额计数只在内存里，重启后会复用 `./data` 中的旧设备并从 0 开始计数。重启后若很快出现风控，可删除 `./data/device-state-rs.json` 再启动。
- Node.js 兜底引擎监听 `0.0.0.0:8787`，它的 `/segment?url=` 和主程序的 `/engine_proxy?url=` 都能代理任意地址。只在可信的局域网中使用，不要把 8767 / 8787 端口映射到外网。

## 线路与兜底

频道按以下顺序获取，前一级失败自动落到下一级：

1. 设备协议 4K / 高码率（默认 26 个频道，可用 `YSP_ONLY_4K_DEVICE` 改为只走 3 个真 4K 频道）
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
- **首次打开高码率频道约需 3 秒**；热备设备未就绪又恰好需要换设备时可能需要十几秒。
- **4K / 8K 频道码率很高**（CCTV-4K 约 36 Mbps），播放设备网络需稳定在 50 Mbps 以上，并建议开启播放器的硬件解码。
- 只有 CCTV-4K、CCTV-8K、CCTV-16 4K 是真 4K / 8K。其余央视频道的「高码率」是约 12 Mbps 的 1080i50（H.264，SDR），比普通 1080p 源清晰，但分辨率仍是 1080。

## 配置

在 `docker-compose.yml` 的 `environment` 中设置：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `YSP_LINKS_PER_DEVICE` | `4`（compose 中设置；不设置为上游默认 6） | 每个设备获取多少个不同的高码率频道后切换到热备设备；`0` 为不主动切换（被拒时仍会切换） |
| `YSP_ONLY_4K_DEVICE` | 关闭 | 设为 `1` 时只有 CCTV-4K、CCTV-8K、CCTV-16 4K 走设备协议，其余走 1080p |
| `TZ` | `Asia/Shanghai` | 日志时区 |

默认 26 路高码率频道：`cctv1`～`cctv5p`、`cctv7`～`cctv17`、`cctv4k`、`cctv8k`、`cctv164k`、`cgtn`、`cgtnfr`、`cgtnru`、`cgtnar`、`cgtnes`、`cgtndoc`。

修改后执行 `docker compose up -d` 生效。

## 更新

```bash
cd /opt/ysp-live-docker && docker compose pull && docker compose up -d
```

`./data` 中只保存当前设备身份，删除不影响使用，下次启动会注册新设备。

## 日志说明

| 日志 | 含义 |
|---|---|
| `[设备池] 当前设备已获取 4 个高码率链接，达到配额上限 (4)，平滑切换热备设备…` | 正常轮换 |
| `[设备池] 已无缝切换至热备设备 (...)`、`热备设备已在后台就绪` | 切换完成，后台已补充下一台热备设备 |
| `[容灾] 检测到设备风控限制 (...)，立即启用热备设备现场重试` | 设备被拒，已换设备重试，通常不会降级 |
| `[xxx] 4K 播放暂时受限 (...)，平滑回退 1080p (冷却 15s)` | 本次未拿到高码率链接，临时用 1080p 播放，冷却后重试 |
| `[xxx] 1080p 地址已过期，已重新拉取`、`空闲超时，已停止后台拉取` | 1080p 线路的正常刷新与闲置回收 |

## 排查

1. 浏览器打开 `http://<路由器IP>:8767/all.m3u`，能看到频道列表说明服务正常。
2. 打开 `/diag`：显示主设备是否有效、当前配额（如 `配额=2/4`）、热备设备状态、各频道刷新情况，末尾附最近 30 条运行日志。
3. 统计风控错误：`docker logs ysp-live 2>&1 | grep -cE "风控|受限"`。
4. 若路由器开了 OpenClash / PassWall 等代理，确认路由器本机出口是国内 IP：`curl -s https://myip.ipip.net`。

## 构建与同步上游

推送到 `main` 分支或打 `v*` 标签时，[.github/workflows/docker.yml](.github/workflows/docker.yml) 会构建多架构镜像并推送到
`ghcr.io/evanzme/ysp-live`（`latest`、`sha-<提交>`、标签名）。

上游发布新版本时：

1. 用上游的 `ysp-live.py`、`ysp-engine.js`、`README.md`（存为 `README-DOCKER.md`）覆盖本仓库文件，提交「Update to upstream vX.Y」。`Dockerfile` 只参考上游的依赖变化，不直接覆盖。
2. 确认 `python3 -m py_compile ysp-live.py` 通过。
3. 推送后等 Actions 完成，在设备上执行更新命令。
