# ysp-live v7.2 Docker 版（纯 Python，单端口极简部署，含 7 天回看）

## 准备

把这几个文件放在同一个目录：
- `Dockerfile`
- `docker-compose.yml`
- `ysp-live.py`
- `README-DOCKER.md`

## 构建与运行

```bash
cd 这个目录
docker compose up -d --build
```

看日志确认设备协议就绪：

```bash
docker logs -f ysp-live
```

看到 `设备协议就绪` 就是好了（首次约 5~10 秒）。
持久化设备身份与缓存会自动保存在当前目录的 `./data` 文件夹中，容器重建/重启不会丢失设备注册。

## 使用

- 首页：`http://localhost:8767/`
- 聚合订阅：`http://localhost:8767/all.m3u`（含 7 天回看与精准 EPG）
- 诊断信息：`http://localhost:8767/diag`

## 停止 / 重启

```bash
docker compose down      # 停止并删除容器（数据保存在 ./data，不丢失）
docker compose restart   # 重启
```

## Linux / 群晖 / 软路由 NAS 性能建议

对于 NAS / Linux 用户，建议在 `docker-compose.yml` 中开启 `network_mode: host`，免去 Docker bridge NAT 损耗，获得极致的 4K 超高清码流吞吐。

## v7.2 核心特性与修复

1. **全面回归黄金 6.2 稳定高码率底座，彻底解决 4K 与高码率频道播放失败**：
   - 彻底移除实验性激进刷新与缓存突变机制，恢复 6.2 经过严格验证的稳定调度机制，缓存生命周期保持为 600 秒标准周期，杜绝频繁请求导致的央视频 API 风控限流与冷却报错。
   - 针对 4K 超高清（CCTV-4K、CCTV-16 4K、CCTV-8K）与 26 路高码率频道，启动即预热，全天候平缓保活，长时间连续播放稳定不掉线。
2. **原生 7 天时移与节目回看（Catchup & Timeshift）**：
   - 央视全高清（CCTV-1~10、13）以及全部 31 路省级卫视、CGTN 系列、CETV-1、国学共 53 路频道，原生支持 **7 天（168 小时）** 无限制节目回看与进度条倒退快进。
   - `all.m3u` 订阅已规范配置 `catchup="append" catchup-days="7"`。TiviMate、APTV、OTT Navigator 等主流 IPTV 播放器导入后自动出现回看日历/图标，点击任一过往节目即可秒开重播。
   - 兼容 `playseek`、`utc/lutc`、`start/end`、`starttime/endtime` 等主流时间轴协议；回看切片直连央视频官方回看 CDN，本地服务器零带宽与零内存消耗。
   - 智能安全降级保护：若播放器误传时移参数至不支持回看的频道（如 4K 频道）或上游回看异常，自动平滑降级至直播流播放，绝不返回 404 报错，保证播放永不中断。
3. **多源精准轻量 EPG 与 64 频道补齐**：
   - 全面适配双源轻量高精准 EPG 源（`live.fanmingming.com/e.xml` 与 `epg.112114.xyz/pp.xml.gz`），体积小加载快。
   - 全部 64 频道 100% 完整映射 `tvg-id`（补齐 CCTV-8K、CGTN英语、CETV1），按 `央视频道`、`卫视频道`、`数字频道` 分组呈现。
4. **单端口部署与自动保活**：
   - 仅需暴露 8767 端口即可承载 M3U8 清单及 TS 分片中继，无端口冲突；心跳每 30 秒全天候发送，Session 到期前 5 分钟静默换新。

## 注意

- 必须在**家庭宽带**下跑，设备注册会被机房 IP 拒绝。
  Docker Desktop 默认 NAT 出去走的就是你家宽带，没问题；但不要把这个镜像放到 VPS/云服务器上跑，26 路设备协议频道会失效。
