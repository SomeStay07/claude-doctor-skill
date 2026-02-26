# Changelog

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
