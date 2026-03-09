# Mikudrome

自用自托管音乐服务器 + 流媒体播放器（支持 MV）。

---

## 技术栈

* **Server:** Go 1.26+ · SQLite（pure Go：modernc.org/sqlite）· REST API
* **Client:** Flutter 3.x · `video_player`

---

## 环境要求

| 依赖      | 版本     |
| ------- | ------ |
| Go      | ≥ 1.26 |
| Flutter | 3.x    |

```bash
go version
flutter doctor
```

---

## 快速开始

### Docker 部署（推荐）

```bash
# 使用 docker-compose
docker-compose up -d

# 或使用 docker build
docker build -t mikudrome .
docker run -d -p 8080:8080 \
  -v $(pwd)/media:/app/media \
  -v $(pwd)/data:/app/data \
  mikudrome
```

访问 http://localhost:8080 使用 Web 客户端。

### 本地运行

```bash
make build    # 构建后端 + Flutter Web
make run      # 启动服务，访问 http://localhost:8080
```

后端会同时提供 REST API 和托管 `build/web` 静态文件，访问根路径即可使用 Web 客户端。

### 开发模式

```bash
make run      # 终端 1：启动后端
make dev      # 终端 2：Flutter 热重载（web-server）
```

---

## Makefile 命令

```bash
make help     # 查看全部命令
```
---

## 环境变量

| 变量         | 默认值            | 说明       |
| ---------- | -------------- | -------- |
| MEDIA_ROOT | ./media        | 媒体目录     |
| DB_PATH    | ./mikudrome.db | 数据库路径    |
| HTTP_ADDR  | :8080          | 监听地址     |
| WEB_ROOT   | ./build/web    | Flutter Web 构建目录 |

示例：

```bash
MEDIA_ROOT=/path/to/media WEB_ROOT=/opt/mikudrome/web make run
```

---

## 扫描规则

- **曲目**：`Song.flac` / `Song.mp3` 等；同名 `.mp4`/`.mkv` 视为 MV。
- **专辑**：目录结构为 `media/艺术家/专辑名/`，其下音频会归入同一专辑；封面为同目录下的 `Cover.jpg`。

---

## 客户端 API 配置

Web 与后端同源部署时（`make run`），无需配置。移动端/桌面端或前后端分离部署时，需在 `lib/api/config.dart` 中修改 `ApiConfig.defaultBaseUrl` 为实际后端地址（如 `http://192.168.1.100:8080`）。

---

## API

| Method | Endpoint                   |
| ------ | -------------------------- |
| GET    | `/api/tracks`              |
| GET    | `/api/tracks/:id`          |
| GET    | `/api/albums`              |
| GET    | `/api/albums/:id`          |
| GET    | `/api/albums/:id/cover`    |
| GET    | `/api/stream/:id/audio`    |
| GET    | `/api/stream/:id/video`    |
| GET    | `/api/db/backup`           |

---

## 目录结构

```
mikudrome/
├── cmd/server/       # 后端入口
├── internal/         # 后端内部包（api, config, scanner, store）
├── lib/              # Flutter 前端
│   ├── api/          # API 统一管理（endpoints, config, client）
│   ├── models/
│   ├── screens/
│   └── widgets/
├── build/web/        # flutter build web 输出（由后端托管）
├── Makefile
├── go.mod
└── pubspec.yaml
```

---

## License

MIT
