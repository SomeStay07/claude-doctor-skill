<div align="center">

# Doctor

**42 automated checks across 6 layers. Security first.**

*A Claude Code skill that scans any project and diagnoses automation gaps — missing security checks, broken hooks, absent tests, misconfigured CI. Then prescribes and applies project-specific fixes.*

[![Claude Code](https://img.shields.io/badge/Claude_Code-Skill-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMTIiIGN5PSIxMiIgcj0iMTAiIGZpbGw9IndoaXRlIi8+PC9zdmc+)](https://docs.anthropic.com/en/docs/claude-code/)
[![Checks](https://img.shields.io/badge/Checks-42-blue?style=for-the-badge)](https://github.com/SomeStay07/claude-doctor-skill#6-layers-42-checks)
[![Layers](https://img.shields.io/badge/Layers-6-orange?style=for-the-badge)](https://github.com/SomeStay07/claude-doctor-skill#6-layers-42-checks)
[![Stacks](https://img.shields.io/badge/Stacks-20+-teal?style=for-the-badge)](https://github.com/SomeStay07/claude-doctor-skill#multi-stack-support)
[![License: MIT](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-Channel-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/codeonvibes)

[What It Does](#what-it-does) · [6 Layers, 42 Checks](#6-layers-42-checks) · [Installation](#installation) · [Usage](#usage) · [How It Works](#how-it-works) · [Multi-Stack](#multi-stack-support)

```bash
curl -sSL https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main/install.sh | bash
```

---

</div>

## The Problem

You set up Claude Code in a new project and start coding. Everything seems fine — until you realize:

- Secrets are committed to git history
- `.env` files are world-readable (permissions `644`)
- No pre-commit hooks catch broken code before push
- No CI runs tests automatically
- Claude has no memory of past decisions across sessions

You don't know what you don't know. And fixing these gaps manually takes hours of research.

## What It Does

**Doctor** is a set of `.md` files that turns [Claude Code](https://docs.anthropic.com/en/docs/claude-code/) into a project automation auditor. Run `/doctor` and get a full health report with severity levels, explanations, and one-click fixes.

> **What's a Claude Code skill?** A skill is a `.md` file in `.claude/skills/` that gives Claude Code specialized behavior for a specific task. No plugins, no API keys — just text files with instructions. [Learn more](https://docs.anthropic.com/en/docs/claude-code/)

Every finding explains **WHY** it matters, with a source link.

### `/doctor scan` — Diagnose

<div align="center">
<br>
<img src="assets/demo-scan.gif" alt="doctor scan demo — diagnosing project health" width="800">
<br>
<sub>Phase 1-2: Study your project, run 42 checks, score each layer</sub>
<br><br>
</div>

### `/doctor fix` — Prescribe + Apply

<div align="center">
<br>
<img src="assets/demo-fix.gif" alt="doctor fix demo — applying fixes" width="800">
<br>
<sub>Phase 3-4: Severity-tagged findings with one-click fixes, then verification</sub>
<br><br>
</div>

## At a Glance

- 42 checks across 6 security & automation layers
- Auto-discovers your stack (20+ languages/frameworks)
- Every finding has severity + WHY + source link
- Applies project-specific fixes (not generic templates)
- Built-in false positive filtering
- Zero dependencies, zero config — just `.md` files
- Bilingual: English and Russian

| Feature | Doctor | [memory-skill](https://github.com/SomeStay07/claude-memory-skill) | [code-reviewer](https://github.com/SomeStay07/code-review-agent) |
|:--------|:------:|:------------:|:---------------:|
| Total checks | **42** | N/A | N/A |
| Layers | **6** | 1 | 1 |
| Auto-discovery (DCI) | **Yes** | Yes | No |
| Error recovery | **Yes** | No | Yes |
| Self-check | **Yes** | No | Yes |
| False positives list | **Yes** | No | Yes |
| Multi-stack | **20+** | No | TypeScript/React |
| Security audit | **11 checks** | No | Partial |
| One-line install | **Yes** | Yes | Yes |

## 6 Layers, 42 Checks

| Layer | Name | Checks | What It Covers |
|:------|:-----|:------:|:---------------|
| 0 | **Security** | 11 | Secrets in git, SAST, .gitignore, .env permissions, Docker security, client-side keys |
| 1 | **Foundation** | 5 | CLAUDE.md, dependency manifest, build scripts, project structure, dep freshness |
| 2 | **Quality Gates** | 11 | Linter, PostToolUse/PreToolUse hooks, pre-commit, CI, error handling, types, coverage |
| 3 | **Intelligence** | 2 | Agent trio (code-reviewer, debugger, architect), domain rules with paths |
| 4 | **Context** | 5 | MCP servers, plugins (context7, episodic-memory), memory files, SessionStart hook |
| 5 | **DX** | 7 | Skills (/test, /status), hook installer, Dependabot, stop hook, unit & smoke tests |

## Installation

### Option A: One command (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main/install.sh | bash
```

### Option B: Manual

```bash
mkdir -p .claude/skills/doctor/layers
cd .claude/skills/doctor

# Main files
curl -sO https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main/SKILL.md
curl -sO https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main/CHECKLIST.md

# Layer details
cd layers
for f in SECURITY FOUNDATION QUALITY QUALITY-EXTRA INTELLIGENCE CONTEXT DX; do
  curl -sO "https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main/layers/$f.md"
done
```

### Verify

```bash
ls .claude/skills/doctor/SKILL.md && echo "Doctor installed"
```

No configuration, API keys, or build step required.

> **Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code/) CLI installed and a project directory with source code.

## Usage

```bash
# In Claude Code, say:
/doctor              # Full audit — all 6 layers, all 42 checks
/doctor scan         # Diagnose only (phases 1-2, no file changes)
/doctor fix          # Prescribe + apply fixes (phases 3-4)
/doctor layer 0      # Security audit only
/doctor verify       # Health check after fixes (phase 5)
```

## How It Works

```
Phase 1: STUDY        Read project: deps, structure, .env, git, automation
                      Output: Project Profile table

Phase 2: DIAGNOSE     Run 42 checks from CHECKLIST.md
                      Score each layer: X/Y (N%)

Phase 3: PRESCRIBE    For each finding:
                      severity + what to fix + WHY + source link

Phase 4: TREAT        Ask user: "Fix all at once or one by one?"
                      Apply project-specific fixes (not templates)

Phase 5: VERIFY       Run tests, linter, check hooks
                      Output: HEALTH REPORT with total score
```

### Auto-Discovery (DCI)

Doctor automatically detects your stack at startup via Dynamic Context Injection:

```
package.json / requirements.txt / Cargo.toml    → stack detection
Makefile / justfile                               → build system
.claude/ / .mcp.json                              → Claude Code setup
Dockerfile / docker-compose.yml                   → containerization
.github/workflows/                                → CI/CD
```

No configuration needed. Works with 20+ stacks out of the box.

### Built-in Guardrails

- **Error Recovery** — handles missing git, no tests, no Docker, context overflow
- **Self-Check** — validates findings before output (no inflated severity, no duplicates)
- **False Positives** — won't flag missing CI in hobby projects, `print()` in CLI scripts, etc.
- **Definition of Done** — audit isn't complete until all layers scored and user asked about fixes

## Multi-Stack Support

Doctor adapts to whatever stack it finds:

| Stack | Linter | Formatter | Test Runner | SAST |
|:------|:-------|:----------|:------------|:-----|
| Python | ruff | ruff format | pytest | bandit |
| Node.js | eslint | prettier | jest/vitest | eslint-plugin-security |
| TypeScript | eslint + tsc | prettier | jest/vitest | eslint-plugin-security |
| Rust | clippy | rustfmt | cargo test | cargo-audit |
| Go | golangci-lint | gofmt | go test | gosec |
| Ruby | rubocop | rubocop | rspec | brakeman |
| Java | checkstyle | google-java-format | JUnit | SpotBugs |
| PHP | phpstan | php-cs-fixer | PHPUnit | psalm |

## Repository Structure

```
claude-doctor-skill/
├── SKILL.md           — Main skill file (entry point for Claude Code)
├── CHECKLIST.md       — Index of all 42 checks across 6 layers
├── layers/
│   ├── SECURITY.md      — Layer 0: 11 security checks + incident response
│   ├── FOUNDATION.md    — Layer 1: 5 foundation checks
│   ├── QUALITY.md       — Layer 2: 7 core quality gate checks
│   ├── QUALITY-EXTRA.md — Layer 2: 4 advanced quality checks
│   ├── INTELLIGENCE.md  — Layer 3: 2 agent intelligence checks
│   ├── CONTEXT.md       — Layer 4: 5 context & memory checks
│   └── DX.md            — Layer 5: 7 developer experience checks
├── assets/
│   ├── logo.svg         — Doctor logo
│   ├── demo-scan.gif    — Animated demo: /doctor scan
│   └── demo-fix.gif     — Animated demo: /doctor fix
├── install.sh         — One-line installer with verification
└── LICENSE
```

One skill. No build step. No dependencies. Install and use.

## Troubleshooting

| Issue | Cause | Fix |
|:------|:------|:----|
| Skill not triggered | File missing or wrong path | Verify `.claude/skills/doctor/SKILL.md` exists |
| Audit is too slow | Very large project | Use `/doctor layer <N>` to audit one layer at a time |
| False positive | Rule doesn't match your setup | Say "this is intentional" — Doctor skips it |
| No output | Older Claude Code version | Run `claude --version` and update to latest |

## See Also

**[Claude Memory Skill](https://github.com/SomeStay07/claude-memory-skill)** — persistent project memory for Claude Code. Remembers decisions, catches contradictions, cleans up stale context. Pairs well with Doctor: memory skill stores conventions, Doctor enforces them.

**[Code Reviewer Agent](https://github.com/SomeStay07/code-review-agent)** — automated code review with concrete fixes. Reviews your diff like a senior engineer — file, line, before/after. Doctor audits the project setup; Code Reviewer audits the code itself.

## Author

Made by [@SomeStay07](https://github.com/SomeStay07) · [Telegram Channel](https://t.me/codeonvibes)

## License

[MIT](LICENSE) — use it, modify it, ship it.
