# Mikudrome

自托管音乐服务器 + 流媒体播放器（支持 MV）。

---

## 技术栈

* **Server:** Go 1.21+ · SQLite（pure Go：modernc.org/sqlite）· REST API
* **Client:** Flutter 3.x · `video_player`

---

## 环境要求

| 依赖      | 版本     |
| ------- | ------ |
| Go      | ≥ 1.21 |
| Flutter | 3.x    |

```bash
go version
flutter doctor
```

---

## 启动

### 后端

```bash
go run ./cmd/server
```

默认监听：

```
http://localhost:8080
```

可选环境变量：

| 变量         | 默认值            | 说明    |
| ---------- | -------------- | ----- |
| MEDIA_ROOT | ./media        | 媒体目录  |
| DB_PATH    | ./mikudrome.db | 数据库路径 |
| HTTP_ADDR  | :8080          | 监听地址  |

示例：

```bash
MEDIA_ROOT=/path/to/media go run ./cmd/server
```

扫描规则：

```
Song.flac / Song.mp3
↓
Song.mp4 / Song.mkv（同名即识别为 MV）
```

---

### 前端

```bash
flutter pub get
flutter run
```

Web：

```bash
flutter run -d chrome
```

默认 API：

```
http://127.0.0.1:8080
```

---

## 构建（可选）

### 后端

```bash
go build -o bin/mikudrome ./cmd/server
```

### 前端

```bash
flutter build web
flutter build apk
flutter build ios
```

---

## API（MVP）

| Method | Endpoint                |
| ------ | ----------------------- |
| GET    | `/api/tracks`           |
| GET    | `/api/tracks/:id`       |
| GET    | `/api/stream/:id/audio` |
| GET    | `/api/stream/:id/video` |

---

## 目录结构

```
mikudrome/
├── cmd/server/
├── internal/
├── lib/
├── web/
├── go.mod
└── pubspec.yaml
```

---

## License

MIT
