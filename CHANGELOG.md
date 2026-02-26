# Changelog

## v3.0.1 — Feedback Fixes (7 improvements from real-world usage)

Фиксы на основе фидбека от реального запуска Доктора на production монорепо.

### False positive fixes
- `.pub` файлы (SSH public keys) не считаются секретами — исключены из 0c (SECURITY.md)
- `install-hooks.sh` не требуется при Husky/Lefthook с `prepare` скриптом (DX-EXTRA.md)
- CLAUDE.md > 300 строк допустим для монорепо с 5+ сервисами и `.claude/rules/` — адаптивный порог (FOUNDATION.md)
- Notification hook — 🔵 max если внешний мониторинг (Conductor/tmux) (GUARDRAILS.md)

### Severity adjustments
- SAST 🟠→🟡 при наличии кастомных security rules (`.claude/rules/security.md`, leak validators) (SECURITY.md)
- PostToolUse ⚠️→🔵 при наличии PreToolUse hooks (QUALITY.md)

### Count accuracy
- `console.log` count исключает DEV-guarded строки (`import.meta.env.DEV`, `isDev`, `__DEV__`) (QUALITY-EXTRA.md)
- NestJS `@nestjs/common` учитывается как structured logging (QUALITY-EXTRA.md)

### Updated
- install.sh: version 3.0.1
- GUARDRAILS.md: 4 новых false positive правила

## v3.0.0 — Stable Release

Doctor is field-tested and production-ready. 89 bugs found and fixed across 4 rounds of real-world testing on 3 projects (Python/Docker, Python/Makefile, Swift/iOS).

### What's new in v3.0.0
- **README fully rewritten** — cleaner structure, real output examples, monorepo FAQ, timing info
- **All old development branches cleaned up** — only `main` remains
- **install.sh**: version 3.0.0

### Since v2.0.0 (cumulative)
- 89 bug fixes across v2.4.0 → v2.5.3 (4 rounds of field testing)
- Monorepo support: `apps/` in src_dirs, `find -maxdepth 3` for configs
- `settings.local.json` + `settings.json` dual-file hook detection
- pnpm/yarn/npm audit by lockfile detection
- Exit code propagation fixes (`if/fi` instead of `[ ] &&`)
- `grep -c` zero-count fix across 13 locations
- Build artifact exclusions (`dist/`, `build/`, `target/`, `coverage/`, `*.spec.*`)
- Symlink-aware hook analysis (grep follows symlinks)
- `shlex.split` for hook command path extraction
- PostToolUse hook loop with `break` for multi-settings-file iteration

## v2.5.3 — Field Tested Round 4 (5 fixes)

Четвёртый раунд на 3 проектах. Баги всё тоньше — монорепо edge cases и exit code propagation.

### 🟠 Important fixes
- PostToolUse hook loop без `break` — ложный warning для settings.local.json (QUALITY.md)
- Monorepo `.env.example` не найден — fallback через `find -maxdepth 3` (SECURITY.md, MATURITY.md)
- Monorepo `vite.config.*`/`next.config.*` не найдены — `find -maxdepth 3` fallback (SECURITY-EXTRA.md)
- `src_dirs` subshell duplication в CONTEXT.md 4a — заменён на стандартный паттерн

### 🟡 Minor fixes
- `[ -gt 3 ] &&` exit code propagation → `if/fi` (QUALITY.md)

### Updated
- install.sh: version 2.5.3

## v2.5.2 — Field Tested Round 3 (5 fixes, 10 files)

Третий раунд тестирования на cherry-cast, telegram-crypto-info, telegram-ios-academy.

### 🔴 Critical fixes
- `apps/` отсутствовал в `src_dirs` — монорепо (Turborepo/NestJS) с `apps/api/`, `apps/bot/` полностью игнорировались (8 файлов, 14 мест)

### 🟠 Important fixes
- `dist/`, `build/`, `target/`, `coverage/` не исключались из grep scan secrets — false positives из build artifacts (SECURITY.md)
- `*.spec.*` не исключались — Jest/Vitest тестовые файлы с фейковыми данными давали false positives (SECURITY.md)
- Stop hook `"$CLAUDE_PROJECT_DIR"` — кавычки оставались в resolved path → `tr -d '"'"'` (DX.md)

### 🟡 Minor fixes
- `make help | head -3 && echo "works"` — pipe exit code от `head` всегда 0 → `if make help` (FOUNDATION.md)

### Updated
- install.sh: version 2.5.2

## v2.5.1 — Field Tested Round 2 (8 fixes)

Повторное тестирование v2.5.0 на тех же 3 проектах выявило 8 дополнительных багов.

### 🔴 Critical fixes
- `settings.local.json` без hooks shadows `settings.json` — теперь проверяются ОБА файла для каждого hook-чека (CONTEXT.md, DX.md, QUALITY-EXTRA.md)
- `readlink` relative path → content analysis молча пропускалась для symlink-хуков — убран readlink, grep follows symlinks (QUALITY.md)
- Stop hook — полная команда `python3 '/path'` как file path → `shlex.split` извлекает скрипт (DX.md)

### 🟠 Important fixes
- `ls *.pem *.key` glob fail exit 1 → цикл + find (SECURITY.md)
- `npm audit` без pnpm/yarn → определение пакетного менеджера по lockfile (SECURITY.md)
- CI exit code 1 propagation от `[ == false ] &&` → `if/fi` (QUALITY.md)

### 🟡 Minor fixes
- Trailing `'` в `cmd.split('/')[-1]` → `.strip("'\"")` (QUALITY-EXTRA.md)
- `[ -gt 10 ] &&` exit 1 без else → `if/fi` (QUALITY-EXTRA.md)

### Updated
- install.sh: version 2.5.1

## v2.5.0 — Field Tested (9 fixes from real-world testing)

Протестировано на 3 реальных проектах: cherry-cast (Python/Docker), telegram-crypto-info (Python/Makefile), telegram-ios-academy-foundation-pro (pnpm monorepo).

### 🔴 Critical fixes
- `settings.local.json` ignored — Doctor checked only `settings.json`, missing Claude Code's preferred local config (CONTEXT.md, DX.md, QUALITY-EXTRA.md, MATURITY.md)
- `grep -c ... || echo 0` produces "0\n0" — grep outputs "0" AND exits 1, so `|| echo 0` appends extra "0" (SECURITY.md, FOUNDATION.md, INTELLIGENCE.md, SECURITY-EXTRA.md, DX-EXTRA.md — 13 locations)

### 🟠 Important fixes
- `.env.example` flagged as leaked secret — added `grep -vE '\.(example|sample|template)'` filter (SECURITY.md)
- Docker `ENV VAR=${BUILD_ARG}` flagged as hardcoded secret — added `grep -v '=\${'` filter (SECURITY-EXTRA.md)
- Hook detection missed `.py` hooks — `.claude/hooks/*.sh` → `.claude/hooks/*` (QUALITY.md)

### 🟡 Minor fixes
- Missing AI API keys: GEMINI, MISTRAL, DEEPSEEK, COHERE, REPLICATE (SECURITY-EXTRA.md)
- Monorepo Prisma migrations not found — added `find -maxdepth 4 -name migrations` fallback (FOUNDATION-EXTRA.md)
- Linter detection missed installed-but-unconfigured linters — added `command -v` fallback (MATURITY.md)
- Skill classifier false positives on complex skills — raised thresholds, added more LLM keywords, added total_lines check (DX-EXTRA.md)

### Updated
- install.sh: version 2.5.0

## v2.4.1 — Precision Hotfix (12 fixes)

### 🔴 Critical fixes
- Extra `done` causing syntax error in TypeScript coverage check (DX.md)
- `sast_in_ci` subshell variable — `find | while` → `while < <(find)` process substitution (SECURITY.md)

### 🟠 Important fixes
- `find -name -o` without `\( \)` grouping — `.yml` files silently skipped (SECURITY.md, QUALITY.md, QUALITY-EXTRA.md)
- `grep -v "test"` too broad — matches `contest`, `attestation` → `--exclude-dir=test` (QUALITY-EXTRA.md)
- `grep "test"` in package.json false positive → `grep -qE '"test"\s*:'` (FOUNDATION.md)
- Aggressive `trap cleanup ERR` removed — partial install better than no install (install.sh)
- Dead `2>/dev/null` on `[ -f ]` removed (SECURITY-EXTRA.md)

### 🟡 Minor fixes
- `grep -c` multi-file → `cat | grep -c` (DX-EXTRA.md)
- GNU sed `\b\w\U&` → portable `awk toupper()` for macOS (FOUNDATION.md)
- `python3 -c "open('$var')"` → `sys.argv[1]` safe pattern (DX.md, QUALITY-EXTRA.md, CONTEXT.md)
- Missing eslint config formats: `.yml`, `.yaml`, `.ts`, `.mts` (QUALITY.md)
- Makefile help regex: `[a-z]+` → `[a-zA-Z_-]+` for targets with hyphens

### Updated
- install.sh: version 2.4.1

## v2.4.0 — Precision (50 fixes + new detections)

### 🔴 Critical fixes
- **W19**: Division by zero in scoring — when layer has 0 applicable checks, weight redistributed proportionally (MATURITY.md)
- **W4**: `mega_found` subshell variable — `find | while` → `while ... < <(find)` process substitution (FOUNDATION.md)
- **W1/W27**: `src_dirs` leading space — `"$src_dirs $d"` → `${src_dirs:+$src_dirs }$d` across 15+ locations

### 🟠 Important fixes
- **W46/W47**: BSD grep — `grep \|` → `grep -E |` in QUALITY.md (2 remaining locations)
- **W5**: Bare `exit 0` replaced with `if/else/fi` in SECURITY.md
- **W6**: Unsafe `for f in $(find ...)` → `find | while read -r f` (SECURITY.md, QUALITY-EXTRA.md)
- **W7**: `find -o` without grouping → `find \( -o \)` (FOUNDATION.md)
- **W13/W44**: SAST detection — removed generic "security", added gosec/trivy/grype (SECURITY.md)
- **W9**: `"$src_dirs"` quoted → unquoted `$src_dirs` for word splitting (DX.md)
- **W10**: Hardcoded `src/ app/` → dynamic `$src_dirs` (QUALITY-EXTRA.md)
- **W11/W24**: `grep "async"` → language-specific `async def`/`import asyncio` (INTELLIGENCE.md)
- **W25**: React detection — Python `from react` → JS `from 'react'` (INTELLIGENCE.md)
- **W12**: `grep "telegram"` → restricted to dependency files (INTELLIGENCE.md)

### 🟡 Minor fixes (38)
- **W8**: Unreliable multi-line catch detection removed (QUALITY.md)
- **W15**: Redundant `grep -v "test"` removed (QUALITY.md)
- **W18**: `.env` without `.env.example` no longer counts as has_env (MATURITY.md)
- **W20**: "5 фаз" → "6 фаз" (SKILL.md)
- **W22**: `""` → `placeholder` in fake data grep (QUALITY.md)
- **W28**: Managed DB grep restricted to config files (SECURITY-EXTRA.md)
- **W30**: Layer mapping `(0=Безопасность...5=DX)` added (SKILL.md)
- **W31b**: Raw regex → human-readable labels in output (FOUNDATION.md)
- **W32**: `/doctor layer 0` example added (SKILL.md)
- **W33b/W48**: `command -v python3` guard added (CONTEXT.md)
- **W34**: SKILL.md → GUARDRAILS.md reference fixed (README.md)
- **W36**: FP-rule: empty layers 3-4 for Starter/Growing = normal (GUARDRAILS.md)
- **W39**: SKILL.md description corrected (README.md)
- **W42**: Missing files added to Contributing table (README.md)
- **W45**: `command -v curl` check added (install.sh)
- **W46b**: `trap cleanup ERR` added (install.sh)
- Canonical `src_dirs` pattern documented (GUARDRAILS.md)
- SKILL.md compressed: threshold → ref MATURITY.md, checklist → inline (-8 lines)
- FOUNDATION.md compressed: dependency entries 3/line (-12 lines)
- CHECKLIST.md: comments on why 5c/5e are `[cc]` tagged

### New detections (informational)
- **Biome**: `biome.json` / `biome.jsonc` in linter detection (MATURITY.md, QUALITY.md)
- **Deno**: `deno.json` / `deno.jsonc` (MATURITY.md)
- **Bun**: `bunfig.toml` (MATURITY.md)
- **Monorepo tools**: `turbo.json`, `nx.json`, `lerna.json`, `pnpm-workspace.yaml` (MATURITY.md)
- **Toolchain versioning**: `.tool-versions`, `.mise.toml`, `.rtx.toml`, `.python-version`, `.node-version`, `.nvmrc` (MATURITY.md)
- **LICENSE**: informational check for LICENSE/LICENCE/COPYING files (FOUNDATION.md)

### Updated
- install.sh: version 2.4.0
- Tag counts unchanged: 18 core + 9 quality + 7 advanced + 12 cc = 46

## v2.3.0 — Quality Release (10 bug fixes)

### Bug fixes
- **W20**: BSD grep on macOS — `grep \|` → `grep -E |` for CLAUDE.md section detection (FOUNDATION.md)
- **W35**: Memory file path — replaced broken `tr '/' '-'` hash with `find`-based discovery (CONTEXT.md)
- **W45**: `readlink -f` portability — replaced with `readlink` (macOS-compatible) (QUALITY.md)
- **W25/W44**: Source directory detection — expanded from 4 to 14 directories across 10 layer files
- **W7**: False positive list — added uv, pnpm, bun, husky, monorepo patterns (GUARDRAILS.md)
- **W11**: Error monitoring tag — `[core]` → `[quality]`, Starter 19→18 checks (CHECKLIST.md, QUALITY-PROD.md)
- **W43**: N/A scoring rule — explicit "N/A excludes from both score AND max" (MATURITY.md)
- **W39**: Growing→Mature boundary — softened to accept tests+linter+env without CI (MATURITY.md)
- **W26**: Empty catch detection — now catches multi-line `catch(e) {\n}` blocks (QUALITY.md)
- **W37**: Smoke test safety — import no longer runs automatically, deferred to Phase 5 (DX.md)

### Updated
- Maturity counts: Starter 18, Growing 27, Mature 34, Pro 46
- install.sh: version 2.3.0
- BSD grep `\|` → `-E |` across all layer files

## v2.2.0 — Vibe Coder Essentials

### New checks (42 → 46)
- **0l. AI API cost protection** `[core]` — detects AI API keys, checks max_tokens in API calls, dev/prod key separation
- **0m. Backup strategy** `[advanced]` — detects managed DB providers, backup scripts, warns if DB exists without backups
- **1g. DB migrations** `[quality]` — detects database presence, checks for migration tools (alembic/prisma/drizzle/knex)
- **2l. Error monitoring** `[quality]` — detects Sentry/LogRocket/Highlight SDK, checks SENTRY_DSN in .env.example

### New files
- **FOUNDATION-EXTRA.md** — advanced foundation checks (1g DB migrations)
- **QUALITY-PROD.md** — production quality checks (2l error monitoring)

### Improvements to existing checks
- **3a. Agents** — recommends `model: haiku` for read-only agents without model field
- **5a. Skills** — checks `allowed-tools` in skills, detects missing `.claude/launch.json` for frontend projects

### Updated
- Maturity counts: Starter 19, Growing 27, Mature 34, Pro 46
- install.sh: downloads 15 files (was 13), version 2.2.0
- Makefile: FILES includes FOUNDATION-EXTRA.md + QUALITY-PROD.md
- README.md: all counts updated, repository structure updated
- CHECKLIST.md: tag table updated (19 core + 8 quality + 7 advanced + 12 cc = 46)

## v2.1.0 — Modular Architecture

### New files
- **GUARDRAILS.md** — output format, error recovery, self-check, false positives (extracted from SKILL.md)
- **SECURITY-EXTRA.md** — advanced security checks 0j-0k + incident response (split from SECURITY.md)
- **DX-EXTRA.md** — advanced DX checks 5e-5g (split from DX.md)
- **Makefile** — `make check`, `make lines`, `make lint`

### Changes
- All layer files now under 400-line limit; SKILL.md under 250
- Added effort estimation `(~N мин)` to all 42 check headers
- Fixed CHECKLIST.md Layer 5 tag mismatches (6 tags corrected)
- Added source links to 8 checks missing them (SECURITY 0c-0i, DX 5f)
- MATURITY.md tag table deduplicated (→ ref to CHECKLIST.md)
- FOUNDATION.md 1b: compressed stack detection, replaced `python3 -c` with `node -p`
- install.sh: downloads all 13 files (was 10)
- README.md: corrected foundation check count, updated architecture section

### Fixes
- Guarded empty `src_dirs` in DX.md 5c TypeScript coverage check
- Removed dead `bare` variable in QUALITY.md 2e

## v2.0.0 — Adaptive Scoring

- 42 checks across 6 layers with tag-based maturity system
- 4 maturity levels: Starter, Growing, Mature, Pro
- Weighted scoring with layer priorities
- `/doctor quick` — top-3 critical checks
