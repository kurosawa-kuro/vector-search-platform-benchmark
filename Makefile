.PHONY: setup build run dev test fmt lint clean \
	local-bootstrap local-preflight local-up local-status local-smoke \
	local-verify-recovery local-down

# Application
APP_NAME := <your-project>

# 初期セットアップ (依存取得・ビルド)
setup: deps build
	@echo "Setup complete."

deps:
	@echo "TODO: 依存をインストール (例: npm install / cargo fetch / pip install -r requirements.txt)"

# ビルド
build:
	@echo "TODO: ビルドコマンドを記述"

# 実行
run:
	@echo "TODO: 実行コマンドを記述"

# 開発 (ホットリロード)
dev:
	@echo "TODO: 開発サーバー / watch コマンドを記述"

# テスト
test:
	@echo "TODO: テストコマンドを記述"

# 整形
fmt:
	@echo "TODO: フォーマッタを記述"

# 静的解析
lint:
	@echo "TODO: リンタを記述"

# クリーンアップ
clean:
	@echo "TODO: 成果物削除コマンドを記述"

# Local Kubernetes + ECK foundation
local-bootstrap:
	@./infra/local/bootstrap-kind.sh

local-preflight: local-bootstrap
	@./infra/local/preflight.sh

local-up:
	@./infra/local/up.sh

local-status:
	@./infra/local/status.sh

local-smoke:
	@./infra/local/smoke.sh

local-verify-recovery:
	@./infra/local/verify-recovery.sh

local-down:
	@./infra/local/down.sh
