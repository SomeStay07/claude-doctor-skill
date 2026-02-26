# Doctor Skill — development helpers

FILES = SKILL.md GUARDRAILS.md CHECKLIST.md \
        layers/SECURITY.md layers/SECURITY-EXTRA.md \
        layers/FOUNDATION.md layers/FOUNDATION-EXTRA.md \
        layers/QUALITY.md layers/QUALITY-EXTRA.md layers/QUALITY-PROD.md \
        layers/INTELLIGENCE.md \
        layers/CONTEXT.md \
        layers/DX.md layers/DX-EXTRA.md \
        layers/MATURITY.md

.PHONY: help check lines lint

help: ## Show available targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | column -ts '	'

check: ## Verify all files exist and are non-empty
	@echo "=== File Check ==="
	@ok=0; fail=0; \
	for f in $(FILES); do \
		if [ -f "$$f" ] && [ -s "$$f" ]; then \
			echo "  ✅ $$f"; ok=$$((ok + 1)); \
		else \
			echo "  ❌ $$f"; fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "$$ok / $$(( ok + fail )) files OK"; \
	[ "$$fail" -eq 0 ] || exit 1

lines: ## Count lines + boundary enforcement
	@echo "=== Line Counts ==="
	@fail=0; \
	for f in $(FILES); do \
		[ -f "$$f" ] || continue; \
		n=$$(wc -l < "$$f"); \
		case "$$f" in \
			SKILL.md)       limit=250 ;; \
			GUARDRAILS.md)  limit=400 ;; \
			*)              limit=400 ;; \
		esac; \
		if [ "$$n" -gt "$$limit" ]; then \
			printf "  ❌ %-30s %4d / %d\n" "$$f" "$$n" "$$limit"; \
			fail=$$((fail + 1)); \
		else \
			printf "  ✅ %-30s %4d / %d\n" "$$f" "$$n" "$$limit"; \
		fi; \
	done; \
	echo ""; \
	[ "$$fail" -eq 0 ] && echo "All within limits" || { echo "$$fail file(s) over limit"; exit 1; }

lint: ## Lint markdown (requires markdownlint-cli)
	@command -v markdownlint >/dev/null 2>&1 || { echo "Install: npm i -g markdownlint-cli"; exit 1; }
	markdownlint $(FILES) --disable MD013 MD033 MD041
