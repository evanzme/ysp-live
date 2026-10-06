# 央视频全频道 IPTV 直播网关 (ysp-live-docker v8.1 旗舰版)

> **极简·纯粹·单端口**：专为 NAS（群晖/威联通/绿联/极空间）、软路由及 Linux 服务器设计的一键容器化部署方案。已完整内置 Python 主网关与 Node.js Web WASM 兜底双引擎，实现工业级四层故障平滑兜底。

---

## 🌟 核心特性

* **🚀 一键开机自启**：解压后仅需一条 `docker compose up -d` 即可在后台常驻运行。
* **🛡️ 内置双引擎全自动四层兜底**：
  * 第一防线：设备投屏真 4K/8K 超高清（原生 12Mbps 明文高速流，免解密）；
  * 第二防线：1080p JCE 动态解析通道；
  * 第三防线：bkliveinfo 备用通道；
  * 第四防线：Node.js Web WASM 兜底引擎，风控期秒级无缝接管。
* **🔒 纯单端口对外**：对外仅需映射宿主机单个端口 `:8767`，双引擎内部闭环协同，电视客户端无需配置复杂端口。
* **💾 数据持久化安全**：自动映射宿主机 `./data` 目录，持久化设备注册凭据与频道状态，重启容器无需重新认证。
* **📦 零外部依赖**：内置全部 64 路独立频道（央视 30 路 + 卫视 34 路），无需任何 yaml 配置文件。

---

## 🚀 快速上手部署

### 第一步：解压文件
将压缩包解压至 NAS 或服务器任意目录，例如：
```bash
unzip ysp-live-docker-v8.1.zip
cd ysp-live-docker-v8.1
```

目录结构如下：
```text
ysp-live-docker-v8.1/
├── Dockerfile          # 官方 Alpine 双引擎轻量镜像构建文件
├── docker-compose.yml  # 极简编排配置文件
├── ysp-live-v8.1.py    # Python 主网关核心
├── ysp-engine.js       # Node.js Web WASM 兜底引擎核心
└── README.md           # 使用说明书
```

### 第二步：一键构建并启动
在当前目录下执行：
```bash
docker compose up -d
```
> Docker 将自动基于 Python Alpine 构建轻量镜像，并在容器内部同时挂起双引擎协同服务。

### 第三步：检查运行状态
```bash
docker compose ps
docker compose logs -f
```
看到控制台输出 `ysp-live v8.1 启动成功: 64 个独立频道` 即表示部署成功。

---

## 📺 客户端播放器配置

将部署设备所在的局域网 IP（例如 `192.168.1.100`）配置到播放器：

* **全频道订阅 (M3U)**：`http://192.168.1.100:8767/all.m3u`（含 EPG、Logo、7天回看）
* **单频道播放**：`http://192.168.1.100:8767/cctv1.m3u8`
* **健康检查**：`http://192.168.1.100:8767/health`
* **实时诊断**：`http://192.168.1.100:8767/diag`

---

## ⚙️ 常见配置与进阶

### 1. 修改对外监听端口
若宿主机 `8767` 端口已被其他服务占用，只需修改 `docker-compose.yml` 中的端口映射：
```yaml
    ports:
      - "8080:8767"   # 将左侧宿主机端口改为 8080 即可
```

### 2. 持久化权限说明
容器会将设备运行凭据保存在当前目录下的 `./data` 文件夹。如 NAS 系统权限较为严格导致容器无法写入，可在宿主机执行：
```bash
chmod -R 777 ./data
```

### 3. 停止与重启
```bash
# 重启服务
docker compose restart

# 停止服务（双引擎自动干净终止，无残留）
docker compose down

# 重新构建最新代码
docker compose up -d --build
```
