BUILD_DIR=.
DIST_DIR=./dist/vpe-flask-app

# Build the package using uv
.PHONY: build
build:
	@echo "Building package..."
	uv build $(BUILD_DIR) --out-dir $(DIST_DIR)
	@echo "Build complete. Packages are located in $(DIST_DIR)."

# Static checks
.PHONY: check
check:
	ruff check

.PHONY: fix
fix:
	ruff check --fix

.PHONY: run
run:
	uv run python growatt_usb.py
