# 多阶段构建 Dockerfile
# Stage 1: 构建 Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# Stage 2: 构建 Go 后端
FROM golang:1.26-alpine AS go-builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o mikudrome ./cmd/server

# Stage 3: 最终运行镜像
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata ffmpeg yt-dlp

WORKDIR /app

# 从构建阶段复制产物
COPY --from=go-builder /app/mikudrome .
COPY --from=flutter-builder /app/build/web ./build/web

# 创建数据目录
RUN mkdir -p /app/media /app/data

# 环境变量
ENV MEDIA_ROOT=/app/media \
    DB_PATH=/app/data/mikudrome.db \
    HTTP_ADDR=:8080 \
    WEB_ROOT=/app/build/web \
    TZ=Asia/Shanghai

# 暴露端口
EXPOSE 8080

# 数据卷
VOLUME ["/app/media", "/app/data"]

# 启动服务
CMD ["./mikudrome"]
