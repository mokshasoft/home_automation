# Static checks
.PHONY: check
check:
	uv run ruff check

.PHONY: fix
fix:
	uv run ruff check --fix

.PHONY: format
format:
	uv run ruff format

.PHONY: run
run:
	uv run python main.py
