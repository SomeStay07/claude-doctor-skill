# Чеклист аудита Doctor — 6 слоёв (0-5)

Оценивай каждый пункт:
- `✅ Норма` — работает как надо
- `⚠️ Слабо` — есть, но неполное/некорректное
- `❌ Отсутствует` — не настроено

**Для каждой находки ⚠️/❌ ОБЯЗАТЕЛЬНО объясни ПОЧЕМУ это важно исправить** — кратко, с аргументом или ссылкой. Не просто "исправь", а "исправь, потому что...".

---

## Теги чеков

Каждый чек имеет тег, определяющий с какого уровня зрелости он считается в скор:

| Тег | Значение | С какого уровня | Кол-во |
|-----|----------|-----------------|--------|
| `[core]` | Универсальный, нужен всем | Starter 🌱 | 18 |
| `[quality]` | Ворота качества | Growing 🌿 | 9 |
| `[advanced]` | Зрелые практики | Mature 🌳 | 7 |
| `[cc]` | Claude Code specific | Pro ⚡ | 12 |
| | | **Итого** | **46** |

Чеки за пределами текущего уровня отображаются как `🔮 Бонус`, но **НЕ считаются** в скор.

---

## Слой 0: Безопасность и защита

Первое что проверяем. Если секреты утекут — всё остальное не имеет значения.

**Краткая сводка** (13 проверок):
- [ ] `[core]` Git инициализирован + есть коммиты + remote backup
- [ ] `[core]` SAST — bandit/eslint-plugin-security/semgrep настроен (AI-код = 45% уязвимостей)
- [ ] `[core]` Секретные файлы не в git (`.env`, `.mcp.json`, `*.pem`, `*.key`, `.npmrc`, `.pypirc`, `*.tfstate`)
- [ ] `[core]` `.gitignore` покрывает ВСЕ категории: секреты, runtime, IDE, Claude Code (под стек)
- [ ] `[core]` Нет хардкод секретов в исходном коде, конфигах, CI, Dockerfile, ноутбуках
- [ ] `[core]` `.env.example` — существует, документирован, сгруппирован, без реальных секретов, синхронизирован с `.env`
- [ ] `[advanced]` Права доступа: `.env` имеет `chmod 600`
- [ ] `[core]` Нет известных уязвимостей в зависимостях (`pip-audit` / `npm audit`)
- [ ] `[core]` Превенция: pre-commit scan (gitleaks) + CI scan + GitHub secret scanning
- [ ] `[advanced]` Docker-безопасность — `.dockerignore`, нет COPY .env, нет хардкод ENV секретов, non-root USER
- [ ] `[advanced]` Клиентские секреты — нет API-ключей в `NEXT_PUBLIC_*` / `VITE_*` / `REACT_APP_*`
- [ ] `[core]` AI API cost protection — billing alerts, max_tokens в вызовах, dev/prod ключи раздельные
- [ ] `[advanced]` Backup strategy — managed DB backup или backup script, git remote + данные

**Детали с командами проверки и планом действий при утечке**: [SECURITY.md](layers/SECURITY.md) + [SECURITY-EXTRA.md](layers/SECURITY-EXTRA.md)

---

## Слой 1: Фундамент — "Можно работать"

Слой 0 = не навредить. Слой 1 = Claude и разработчик могут продуктивно работать.

**Краткая сводка** (7 проверок):
- [ ] `[core]` CLAUDE.md — существует, < 300 строк, есть Quick Start + Architecture + Critical Rules + Known Issues, команды работают
- [ ] `[core]` Файл зависимостей — `requirements.txt` / `package.json` / `Cargo.toml` / `go.mod` существует и не пустой (20 стеков)
- [ ] `[quality]` Скрипты сборки — Makefile / package.json / justfile с: test, lint, format, run, clean, help
- [ ] `[core]` Структура проекта — нет mega-файлов >500 строк, код в папках, entry point понятен
- [ ] `[quality]` Актуальность зависимостей — нет критически устаревших зависимостей, lock file существует
- [ ] `[core]` README.md — существует, описывает проект, есть Quick Start для людей (не путать с CLAUDE.md)
- [ ] `[quality]` Миграции БД — alembic/prisma/knex настроен (только если проект имеет БД)

**Детали с командами проверки и примерами**: [FOUNDATION.md](layers/FOUNDATION.md) + [FOUNDATION-EXTRA.md](layers/FOUNDATION-EXTRA.md)

> `.gitignore` и `.env.example` проверяются в Слое 0 (Безопасность) — там же проверяется покрытие runtime/IDE/Claude Code паттернов.

---

## Слой 2: Ворота качества — "Код не сломается"

Автоматические проверки на 3 уровнях: Claude пишет → PostToolUse, git commit → pre-commit, GitHub → CI.

**Краткая сводка** (12 проверок):
- [ ] `[core]` Линтер + Форматтер — ruff / eslint настроен, `make format` работает
- [ ] `[cc]` PostToolUse хук — syntax check + auto-format при каждом Edit/Write Claude
- [ ] `[core]` Pre-commit хук — lint + secrets scan перед коммитом (staged files only)
- [ ] `[advanced]` CI workflow — 🔵 опционально для соло-проектов, важно для команд
- [ ] `[core]` Обработка ошибок — нет bare except / empty catch, ошибки логируются а не глотаются
- [ ] `[quality]` Pre-push хук — тесты запускаются перед `git push` (не каждый коммит, а перед отправкой)
- [ ] `[advanced]` Защита веток — PR workflow, запрет прямого push в main, feature branches
- [ ] `[quality]` Проверка типов — mypy / pyright / tsc --strict настроен, аннотации типов есть
- [ ] `[quality]` Покрытие кода — pytest-cov / istanbul настроен, threshold ≥60%
- [ ] `[core]` Нет print() в продакшене — `logging` вместо `print()`, structured logging
- [ ] `[cc]` PreToolUse хуки — pattern reminders + блокировка опасных команд (merge, rm -rf)
- [ ] `[quality]` Error monitoring — Sentry/LogRocket/Axiom настроен, SENTRY_DSN в env

**Детали с командами проверки и примерами**: [QUALITY.md](layers/QUALITY.md) + [QUALITY-EXTRA.md](layers/QUALITY-EXTRA.md) + [QUALITY-PROD.md](layers/QUALITY-PROD.md)

---

## Слой 3: Интеллект агентов — "Claude работает умнее"

Без агентов и правил Claude решает каждую задачу с нуля. С ними — применяет проверенные стратегии.

**Краткая сводка** (2 проверки):
- [ ] `[cc]` Агенты — базовая тройка (code-reviewer, debugger, software-architect) в `.claude/agents/`, с descriptions и tool restrictions
- [ ] `[cc]` Доменные правила — `.claude/rules/` с `paths:` frontmatter, покрывают async/security/framework

**Детали с командами проверки и примерами**: [INTELLIGENCE.md](layers/INTELLIGENCE.md)

---

## Слой 4: Контекст и память — "Claude помнит и видит"

Без контекста Claude каждую сессию начинает с нуля. Со Слоем 4 — долгосрочная память и прямой доступ к инструментам.

**Краткая сводка** (5 проверок):
- [ ] `[cc]` MCP-серверы — `.mcp.json` с серверами под стек проекта (DB → postgres, code → serena, web → tavily), credentials в `"env"` блоке
- [ ] `[cc]` Плагины — context7 (актуальные доки), episodic-memory (память между сессиями)
- [ ] `[cc]` Файлы памяти — MEMORY.md / `.serena/memories/` с решениями, gotchas, паттернами (не дневник)
- [ ] `[cc]` SessionStart compact хук — контекст-ремайндер после compaction (критичные правила проекта)
- [ ] `[cc]` Хук уведомлений — macOS/Linux оповещение когда Claude ждёт ввода

**Детали с командами проверки и примерами**: [CONTEXT.md](layers/CONTEXT.md)

---

## Слой 5: Опыт разработчика — "Всё автоматизировано"

Без DX-слоя разработчик вручную вспоминает команды. Со Слоем 5 — одна команда делает всё правильно.

**Краткая сводка** (7 проверок):
- [ ] `[cc]` Скиллы — `/test` + `/status` минимум, с triggers и $ARGUMENTS handling
- [ ] `[quality]` Stop хук — напоминание про uncommitted changes + memory при выходе
- [ ] `[cc]` Юнит-тесты — существуют, проходят, покрывают source модули <!-- [cc]: диагностический скрипт запускается внутри CC-сессии, проверяет покрытие модулей чтобы Claude мог валидировать свой сгенерированный код -->
- [ ] `[advanced]` Smoke-тесты — быстрая проверка "приложение запускается?" (<5 секунд)
- [ ] `[cc]` Dependabot / Renovate — автообновление зависимостей, weekly/monthly schedule <!-- [cc]: проверяет наличие .github/dependabot.yml или renovate.json — CC-specific DX, т.к. Claude Code активно добавляет зависимости и нужен автоматический контроль их актуальности -->
- [ ] `[core]` Установщик хуков — scripts/install-hooks.sh + make hooks, symlinks в .git/hooks/
- [ ] `[quality]` Оптимизация скиллов — disable-model-invocation: true на command-runner скиллах (/test, /status)

**Детали с командами проверки и примерами**: [DX.md](layers/DX.md) + [DX-EXTRA.md](layers/DX-EXTRA.md)

---

## Применимые чеки по уровню зрелости

| Уровень | Применимые теги | Чеков в скоре | Остальные |
|---------|----------------|---------------|-----------|
| Starter 🌱 | `[core]` | 18 | 🔮 Бонус |
| Growing 🌿 | `[core]` + `[quality]` | 27 | 🔮 Бонус |
| Mature 🌳 | `[core]` + `[quality]` + `[advanced]` | 34 | 🔮 Бонус |
| Pro ⚡ | Все теги | 46 | — |
