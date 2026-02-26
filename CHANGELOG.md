# Changelog

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
