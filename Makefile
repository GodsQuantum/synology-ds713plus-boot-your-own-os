.PHONY: lint test

lint:
	@for f in scripts/*.sh scripts/lib/*.sh; do bash -n "$$f"; done
	@python3 -c 'import ast, pathlib; ast.parse(pathlib.Path("scripts/calc_patchzone.py").read_text())'
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -S warning scripts/*.sh scripts/lib/*.sh; else echo 'shellcheck not installed; skipped'; fi
	@python3 tests/test_repo_consistency.py
	@python3 tests/test_public_hygiene.py
	@python3 tests/test_manifest.py
	@python3 tests/test_markdown_links.py
	@python3 tests/test_public_bridge.py
	@python3 bridge/test_v91_static.py
	@python3 bridge/test_v93_static.py
	@python3 tests/test_v93_writer.py
	@python3 bridge/test_v94_static.py
	@python3 tests/test_v94_writer.py
	@python3 tests/test_v94_stable_target.py
	@python3 bridge/test_v95_static.py
	@python3 tests/test_v95_writer.py

test: lint
