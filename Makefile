.PHONY: lint
lint:
	@for f in scripts/*.sh scripts/lib/*.sh; do bash -n "$$f"; done
	@python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/calc_patchzone.py").read_text())'
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -S warning scripts/*.sh scripts/lib/*.sh; else echo 'shellcheck not installed; skipped'; fi
