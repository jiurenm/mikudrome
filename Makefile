# Mikudrome - 开发与构建命令
# 环境变量: MEDIA_ROOT, DB_PATH, HTTP_ADDR, WEB_ROOT, API_BASE_URL

.PHONY: help build run dev clean \
	backend-build backend-run backend-test \
	frontend-get frontend-build frontend-run frontend-analyze frontend-test-vm \
	frontend-test-media-session-browser verify-media-session \
	frontend-apk frontend-appbundle frontend-ios \
	frontend-windows frontend-macos frontend-linux

BIN_DIR  := bin
BIN_NAME := mikudrome
WEB_ROOT := build/web

# 默认目标
help:
	@echo "Mikudrome Makefile"
	@echo ""
	@echo "开发:"
	@echo "  make run          - 启动后端（托管 build/web 静态文件）"
	@echo "  make dev          - 前端开发模式（flutter run -d web-server，需另开终端跑 make run）"
	@echo ""
	@echo "构建:"
	@echo "  make build        - 构建后端二进制 + Flutter Web"
	@echo "  make backend      - 仅构建后端"
	@echo "  make frontend     - 仅构建前端 Web"
	@echo ""
	@echo "移动端:"
	@echo "  make apk          - Android APK (build/app/outputs/flutter-apk/)"
	@echo "  make appbundle    - Android App Bundle (build/app/outputs/bundle/)"
	@echo "  make ios          - iOS (需 macOS + Xcode)"
	@echo ""
	@echo "桌面端:"
	@echo "  make windows      - Windows (需 Windows)"
	@echo "  make macos        - macOS (需 macOS)"
	@echo "  make linux        - Linux"
	@echo ""
	@echo "其他:"
	@echo "  make test         - 运行后端测试"
	@echo "  make test-vm      - 运行 Flutter VM-safe 测试（排除浏览器专用测试）"
	@echo "  make test-media-session-browser - 运行浏览器专用 Media Session 测试"
	@echo "  make verify-media-session - 顺序运行 VM-safe + 浏览器 Media Session 验证"
	@echo "  make analyze      - Flutter 静态分析"
	@echo "  make clean        - 清理构建产物"
	@echo ""
	@echo "环境变量: MEDIA_ROOT DB_PATH HTTP_ADDR WEB_ROOT API_BASE_URL"

# === 一键构建 ===
build: frontend backend
	@echo "Build complete: $(BIN_DIR)/$(BIN_NAME) + $(WEB_ROOT)/"

# === 开发运行 ===
run: backend
	@echo "Starting server (serves API + $(WEB_ROOT))..."
	@MEDIA_ROOT="$${MEDIA_ROOT:-./media}" \
	 DB_PATH="$${DB_PATH:-./mikudrome.db}" \
	 HTTP_ADDR="$${HTTP_ADDR:-:8080}" \
	 WEB_ROOT="$${WEB_ROOT:-$(WEB_ROOT)}" \
	 go run ./cmd/server

dev:
	@echo "Flutter dev mode (web-server). Backend: make run"
	flutter run -d web-server --dart-define=API_BASE_URL=$${API_BASE_URL:-http://127.0.0.1:8080}

# === 后端 ===
backend: backend-build

backend-build:
	@mkdir -p $(BIN_DIR)
	go build -o $(BIN_DIR)/$(BIN_NAME) ./cmd/server
	@echo "Backend: $(BIN_DIR)/$(BIN_NAME)"

backend-run: backend-build
	@MEDIA_ROOT="$${MEDIA_ROOT:-./media}" \
	 DB_PATH="$${DB_PATH:-./mikudrome.db}" \
	 HTTP_ADDR="$${HTTP_ADDR:-:8080}" \
	 WEB_ROOT="$${WEB_ROOT:-$(WEB_ROOT)}" \
	 ./$(BIN_DIR)/$(BIN_NAME)

backend-test:
	go test ./...

# === 前端 ===
frontend: frontend-get frontend-build

frontend-get:
	flutter pub get

frontend-build: frontend-get
	flutter build web --dart-define=API_BASE_URL=$${API_BASE_URL:-}
	@echo "Frontend: $(WEB_ROOT)/"

frontend-run:
	flutter run -d chrome

frontend-analyze:
	flutter analyze lib/

frontend-test-vm: frontend-get
	flutter test

test-vm: frontend-test-vm

frontend-test-media-session-browser: frontend-get
	flutter test --platform chrome test/services/web_media_session_web_test.dart

test-media-session-browser: frontend-test-media-session-browser

verify-media-session: frontend-test-vm frontend-test-media-session-browser

# === 移动端 ===
apk: frontend-get
	flutter build apk
	@echo "APK: build/app/outputs/flutter-apk/app-release.apk"

appbundle: frontend-get
	flutter build appbundle
	@echo "App Bundle: build/app/outputs/bundle/release/app-release.aab"

ios: frontend-get
	flutter build ios
	@echo "iOS: build/ios/iphoneos/Runner.app"

# === 桌面端 ===
windows: frontend-get
	flutter build windows
	@echo "Windows: build/windows/runner/Release/"

macos: frontend-get
	flutter build macos
	@echo "macOS: build/macos/Build/Products/Release/"

linux: frontend-get
	flutter build linux
	@echo "Linux: build/linux/x64/release/bundle/"

# === 通用 ===
test: backend-test

analyze: frontend-analyze

clean:
	rm -rf $(BIN_DIR)
	flutter clean
	@echo "Cleaned."
