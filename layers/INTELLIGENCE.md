# Слой 3: Интеллект агентов — "Claude работает умнее"

Без агентов и правил Claude решает каждую задачу с нуля. С ними — применяет проверенные стратегии, знает ловушки проекта, не повторяет ошибки.

---

## 3a. Агенты — специализированные помощники (~15 мин) [cc]
<!-- glossary: агенты = специализированные помощники Claude с ограниченными инструментами и фокусной задачей -->

- [ ] **Базовая тройка** — code-reviewer, debugger, software-architect в `.claude/agents/`
- [ ] **Описания понятны** — Claude использует `description` чтобы решить когда делегировать
- [ ] **Инструменты ограничены** — read-only агенты (reviewer) не имеют Edit/Write
- [ ] **Знание проекта** — агенты знают паттерны, ловушки и API проекта

### Команды проверки

```bash
echo "=== Агенты ==="
agents_dir=".claude/agents"
if [ -d "$agents_dir" ]; then
  echo "  ✅ Директория агентов существует"

  # Список агентов с ключевыми метаданными:
  for f in "$agents_dir"/*.md; do
    [ ! -f "$f" ] && continue
    name=$(grep -m1 '^name:' "$f" | sed 's/name:[[:space:]]*//')
    tools=$(grep -m1 '^tools:' "$f" | sed 's/tools:[[:space:]]*//')
    model=$(grep -m1 '^model:' "$f" | sed 's/model:[[:space:]]*//')
    # Описание: проверить наличие (может быть многострочным с |)
    has_desc=$(grep -c '^description' "$f" || echo 0)
    echo "  📋 $name"
    if [ "$has_desc" -gt 0 ]; then
      # Качество описания: примеры улучшают авто-делегацию
      has_examples=$(grep -c '<example>' "$f" 2>/dev/null || echo 0)
      if [ "$has_examples" -gt 0 ]; then
        echo "     desc: ✅ ($has_examples примеров)"
      else
        echo "     desc: ⚠️ есть, но без <example> — Claude хуже понимает когда делегировать"
      fi
    else
      echo "     desc: ❌ ОТСУТСТВУЕТ — Claude не будет знать когда делегировать"
    fi
    if [ -n "$tools" ]; then
      echo "     tools: $tools"
    else
      echo "     tools: наследует все (⚠️ reviewer не должен иметь Edit/Write)"
    fi
    if [ -n "$model" ]; then
      echo "     model: $model"
    else
      # Read-only агент без model: рекомендовать haiku
      if echo "$tools" | grep -qiE "^(Read|Grep|Glob|Bash)" 2>/dev/null; then
        if ! echo "$tools" | grep -qiE "Edit|Write" 2>/dev/null; then
          echo "     💡 Read-only агент — добавь model: haiku для экономии токенов"
        fi
      fi
    fi
  done

  # Проверка базовой тройки:
  echo "=== Базовая тройка ==="
  for agent in "code-reviewer" "debugger" "software-architect"; do
    if [ -f "$agents_dir/$agent.md" ]; then
      echo "  ✅ $agent"
    else
      echo "  ⚠️ ОТСУТСТВУЕТ: $agent"
    fi
  done
else
  echo "  ❌ Нет директории .claude/agents/"
fi
```

### Базовая тройка — минимальный набор

| Агент | Цель | Инструменты | Когда вызывать |
|-------|------|-------------|----------------|
| code-reviewer | Качество кода, безопасность | Read, Grep, Glob, Bash (только чтение!) | После написания кода, перед PR |
| debugger | Диагностика ошибок | Read, Edit, Bash, Grep, Glob | При ошибках, stack traces |
| software-architect | Анализ компромиссов | Read, Grep, Glob | При архитектурных решениях |

### Что делает хорошего агента

**Обязательно:**
- `name` + `description` с примерами и триггерами (Claude использует description для авто-делегации!)
- `tools` ограничены до минимума (reviewer ≠ writer)
- Знание проекта в prompt (API ловушки, паттерны, false positives)
- `<example>` блоки в description — Claude лучше понимает когда вызывать

**Запрещено:**
- Generic промпты без знания проекта (бесполезнее чем vanilla Claude)
- Все tools для read-only агента (reviewer с Edit = может случайно изменить код)
- Устаревшие инструкции (deprecated APIs, удалённые модули)

### Агенты по типу проекта

Базовая тройка покрывает 90% случаев. Дополнительные агенты — если есть специфика:

| Проект | Дополнительные агенты |
|--------|----------------------|
| API backend | api-tester, db-migration-reviewer |
| Frontend | accessibility-checker, component-reviewer |
| Data/ML | data-validator, model-evaluator |
| Telegram bot | telegram-api-checker |
| Crypto/DeFi | security-auditor (reentrancy, oracle attacks) |

→ https://docs.anthropic.com/en/docs/claude-code/sub-agents

---

## 3b. Доменные правила — контекстные подсказки (~15 мин) [cc]
<!-- glossary: доменные правила = контекстные подсказки, загружаемые когда Claude работает с определёнными файлами -->

- [ ] **Правила существуют** — директория `.claude/rules/` с `.md` файлами
- [ ] **Привязаны к файлам** — правила используют `paths:` frontmatter для нужных файлов
- [ ] **Покрывают ключевые домены** — async-паттерны, безопасность, фреймворк-специфичные
- [ ] **Разумный размер** — каждое правило < 50 строк, фокусированное

### Команды проверки

```bash
echo "=== Доменные правила ==="
rules_dir=".claude/rules"
if [ -d "$rules_dir" ]; then
  echo "  ✅ Директория правил существует"

  # Список правил с привязкой к путям и размером:
  for f in "$rules_dir"/*.md; do
    [ ! -f "$f" ] && continue
    name=$(basename "$f" .md)
    has_paths=$(grep -c '^paths:' "$f" 2>/dev/null || echo 0)
    lines=$(wc -l < "$f" | tr -d ' ')
    if [ "$has_paths" -gt 0 ]; then
      paths=$(grep -A5 '^paths:' "$f" | grep "'" | head -3 | tr -d "' -" | tr '\n' ', ')
      echo "  ✅ $name ($lines строк) → $paths"
    else
      echo "  ⚠️ $name ($lines строк) → ГЛОБАЛЬНОЕ (нет paths: — загружается всегда)"
    fi
    # Проверка размера:
    if [ "$lines" -gt 50 ]; then
      echo "     ⚠️ $lines строк — слишком длинное, Claude хуже следует >50 строк"
    fi
  done

  # Определение ожидаемых правил по стеку проекта:
  echo "=== Ожидаемые правила ==="

  # Поиск директорий исходного кода (не захардкожено):
  src_dirs=""
  for d in src app lib bot server backend api core pkg cmd internal services packages; do
    if [ -d "$d" ]; then
      src_dirs="${src_dirs:+$src_dirs }$d"
    fi
  done

  if [ -n "$src_dirs" ]; then
    # Async-проект?
    # Python async:
    if grep -rqE "^(import asyncio|async def )" --include="*.py" $src_dirs 2>/dev/null; then
      if [ -f "$rules_dir/python-async.md" ] || [ -f "$rules_dir/async.md" ]; then
        echo "  ✅ async-правила"
      else
        echo "  ⚠️ ОТСУТСТВУЕТ: async-правила (проект использует asyncio)"
      fi
    fi

    # Работа с секретами?
    if [ -f .env.example ] && grep -q "token\|api_key\|secret" .env.example 2>/dev/null; then
      if [ -f "$rules_dir/security.md" ]; then
        echo "  ✅ правила безопасности"
      else
        echo "  ⚠️ ОТСУТСТВУЕТ: правила безопасности (проект работает с секретами)"
      fi
    fi

    # Фреймворк-специфичные? (определение популярных фреймворков)
    if grep -rqE "(python-telegram-bot|aiogram|pyrogram|telebot|telegraf|grammy)" requirements.txt pyproject.toml package.json 2>/dev/null; then
      if [ -f "$rules_dir/telegram-bot.md" ] || [ -f "$rules_dir/telegram.md" ]; then
        echo "  ✅ telegram-правила"
      else
        echo "  ⚠️ ОТСУТСТВУЕТ: telegram-правила"
      fi
    fi
    if grep -rqE "from (fastapi|flask|django)" $src_dirs 2>/dev/null; then
      if [ -f "$rules_dir/api.md" ] || [ -f "$rules_dir/web.md" ]; then
        echo "  ✅ правила web-фреймворка"
      else
        echo "  ⚠️ ОТСУТСТВУЕТ: правила web-фреймворка (проект использует web framework)"
      fi
    fi
    if grep -rqE "(from ['\"]react|from ['\"]next|from ['\"]vue|require\(['\"]react|require\(['\"]next|require\(['\"]vue)" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" $src_dirs 2>/dev/null; then
      if [ -f "$rules_dir/frontend.md" ]; then
        echo "  ✅ frontend-правила"
      else
        echo "  ⚠️ ОТСУТСТВУЕТ: frontend-правила"
      fi
    fi
  fi
else
  echo "  ❌ Нет директории .claude/rules/"
fi
```

### Типичные правила по стеку

| Правило | Paths | Что проверяет |
|---------|-------|---------------|
| python-async | `bot/**/*.py` | `requests`→`aiohttp`, `time.sleep`→`asyncio.sleep`, `async with` для DB |
| security | `**/*.py`, `**/*.yaml` | Не логировать секреты, валидировать input, parameterized SQL |
| telegram-bot | `bot/telegram/**/*.py` | HTML parse_mode, message_thread_id, лимит 4096 символов |
| database | `bot/db/**/*.py` | Управление пулом, миграции схемы, execute() возвращает строку |
| testing | `tests/**/*.py` | Мокать внешние API, async-фикстуры, никаких реальных credentials |

### Анти-паттерны

- **Глобальные правила без paths** → загружаются при КАЖДОМ запуске Claude, даже если не нужны → замедляют ответ + priority saturation
- **Огромные правила (50+ строк)** → Claude хуже следует длинным инструкциям → разбей на фокусированные файлы
- **Дублирование с CLAUDE.md** → одно место для каждого правила: CLAUDE.md для общих, rules для файл-специфичных

### Зачем paths: а не глобальные правила?

```yaml
# ✅ Правильно — загружается только при редактировании bot/**/*.py
---
paths:
  - 'bot/**/*.py'
---
# Python Async Rules...

# ❌ Неправильно — загружается ВСЕГДА, даже при редактировании README
# (нет paths: frontmatter)
# Python Async Rules...
```

Claude Code загружает правила в контекст **только когда работает с matching файлами**. Без `paths:` правило глобальное — тратит контекст даже когда нерелевантно.

→ https://docs.anthropic.com/en/docs/claude-code/settings#rules
