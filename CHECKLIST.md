# Чеклист аудита Doctor — 6 слоёв (0-5)

Оценивай каждый пункт:
- `✅ Норма` — работает как надо
- `⚠️ Слабо` — есть, но неполное/некорректное
- `❌ Отсутствует` — не настроено

**Для каждой находки ⚠️/❌ ОБЯЗАТЕЛЬНО объясни ПОЧЕМУ это важно исправить** — кратко, с аргументом или ссылкой. Не просто "исправь", а "исправь, потому что...".

---

## Слой 0: Безопасность и защита

Первое что проверяем. Если секреты утекут — всё остальное не имеет значения.

**Краткая сводка** (11 проверок):
- [ ] Git инициализирован + есть коммиты + remote backup
- [ ] SAST — bandit/eslint-plugin-security/semgrep настроен (AI-код = 45% уязвимостей)
- [ ] Секретные файлы не в git (`.env`, `.mcp.json`, `*.pem`, `*.key`, `.npmrc`, `.pypirc`, `*.tfstate`)
- [ ] `.gitignore` покрывает ВСЕ категории: секреты, runtime, IDE, Claude Code (под стек)
- [ ] Нет хардкод секретов в исходном коде, конфигах, CI, Dockerfile, ноутбуках
- [ ] `.env.example` — существует, документирован, сгруппирован, без реальных секретов, синхронизирован с `.env`
- [ ] Права доступа: `.env` имеет `chmod 600`
- [ ] Нет известных уязвимостей в зависимостях (`pip-audit` / `npm audit`)
- [ ] Превенция: pre-commit scan (gitleaks) + CI scan + GitHub secret scanning
- [ ] Docker-безопасность — `.dockerignore`, нет COPY .env, нет хардкод ENV секретов, non-root USER
- [ ] Клиентские секреты — нет API-ключей в `NEXT_PUBLIC_*` / `VITE_*` / `REACT_APP_*`

**Детали с командами проверки и планом действий при утечке**: [SECURITY.md](layers/SECURITY.md)

---

## Слой 1: Фундамент — "Можно работать"

Слой 0 = не навредить. Слой 1 = Claude и разработчик могут продуктивно работать.

**Краткая сводка** (5 проверок):
- [ ] CLAUDE.md — существует, < 300 строк, есть Quick Start + Architecture + Critical Rules + Known Issues, команды работают
- [ ] Файл зависимостей — `requirements.txt` / `package.json` / `Cargo.toml` / `go.mod` существует и не пустой (20 стеков)
- [ ] Скрипты сборки — Makefile / package.json / justfile с: test, lint, format, run, clean, help
- [ ] Структура проекта — нет mega-файлов >500 строк, код в папках, entry point понятен
- [ ] Актуальность зависимостей — нет критически устаревших зависимостей, lock file существует

**Детали с командами проверки и примерами**: [FOUNDATION.md](layers/FOUNDATION.md)

> `.gitignore` и `.env.example` проверяются в Слое 0 (Безопасность) — там же проверяется покрытие runtime/IDE/Claude Code паттернов.

---

## Слой 2: Ворота качества — "Код не сломается"

Автоматические проверки на 3 уровнях: Claude пишет → PostToolUse, git commit → pre-commit, GitHub → CI.

**Краткая сводка** (11 проверок):
- [ ] Линтер + Форматтер — ruff / eslint настроен, `make format` работает
- [ ] PostToolUse хук — syntax check + auto-format при каждом Edit/Write Claude
- [ ] Pre-commit хук — lint + secrets scan перед коммитом (staged files only)
- [ ] CI workflow — 🔵 опционально для соло-проектов, важно для команд
- [ ] Обработка ошибок — нет bare except / empty catch, ошибки логируются а не глотаются
- [ ] Pre-push хук — тесты запускаются перед `git push` (не каждый коммит, а перед отправкой)
- [ ] Защита веток — PR workflow, запрет прямого push в main, feature branches
- [ ] Проверка типов — mypy / pyright / tsc --strict настроен, аннотации типов есть
- [ ] Покрытие кода — pytest-cov / istanbul настроен, threshold ≥60%
- [ ] Нет print() в продакшене — `logging` вместо `print()`, structured logging
- [ ] PreToolUse хуки — pattern reminders + блокировка опасных команд (merge, rm -rf)

**Детали с командами проверки и примерами**: [QUALITY.md](layers/QUALITY.md) + [QUALITY-EXTRA.md](layers/QUALITY-EXTRA.md)

---

## Слой 3: Интеллект агентов — "Claude работает умнее"

Без агентов и правил Claude решает каждую задачу с нуля. С ними — применяет проверенные стратегии.

**Краткая сводка** (2 проверки):
- [ ] Агенты — базовая тройка (code-reviewer, debugger, software-architect) в `.claude/agents/`, с descriptions и tool restrictions
- [ ] Доменные правила — `.claude/rules/` с `paths:` frontmatter, покрывают async/security/framework

**Детали с командами проверки и примерами**: [INTELLIGENCE.md](layers/INTELLIGENCE.md)

---

## Слой 4: Контекст и память — "Claude помнит и видит"

Без контекста Claude каждую сессию начинает с нуля. Со Слоем 4 — долгосрочная память и прямой доступ к инструментам.

**Краткая сводка** (5 проверок):
- [ ] MCP-серверы — `.mcp.json` с серверами под стек проекта (DB → postgres, code → serena, web → tavily), credentials в `"env"` блоке
- [ ] Плагины — context7 (актуальные доки), episodic-memory (память между сессиями)
- [ ] Файлы памяти — MEMORY.md / `.serena/memories/` с решениями, gotchas, паттернами (не дневник)
- [ ] SessionStart compact хук — контекст-ремайндер после compaction (критичные правила проекта)
- [ ] Хук уведомлений — macOS/Linux оповещение когда Claude ждёт ввода

**Детали с командами проверки и примерами**: [CONTEXT.md](layers/CONTEXT.md)

---

## Слой 5: Опыт разработчика — "Всё автоматизировано"

Без DX-слоя разработчик вручную вспоминает команды. Со Слоем 5 — одна команда делает всё правильно.

**Краткая сводка** (7 проверок):
- [ ] Скиллы — `/test` + `/status` минимум, с triggers и $ARGUMENTS handling
- [ ] Установщик хуков — scripts/install-hooks.sh + make hooks, symlinks в .git/hooks/
- [ ] Оптимизация скиллов — disable-model-invocation: true на command-runner скиллах (/test, /status)
- [ ] Dependabot / Renovate — автообновление зависимостей, weekly/monthly schedule
- [ ] Stop хук — напоминание про uncommitted changes + memory при выходе
- [ ] Юнит-тесты — существуют, проходят, покрывают source модули
- [ ] Smoke-тесты — быстрая проверка "приложение запускается?" (<5 секунд)

**Детали с командами проверки и примерами**: [DX.md](layers/DX.md)
