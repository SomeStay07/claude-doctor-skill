# Слой 4: Контекст и память — "Claude помнит и видит"

Без контекста Claude каждую сессию начинает с нуля: не помнит прошлых решений, не видит БД, не знает актуальные API. С Layer 4 — у Claude долгосрочная память и прямой доступ к инструментам проекта.

---

## 4a. MCP серверы — инструменты для Claude

- [ ] **Настроен** — `.mcp.json` существует с нужными серверами
- [ ] **Соответствует стеку проекта** — БД → postgres MCP, код → Serena, веб → Tavily/Brave
- [ ] **Нет мёртвых серверов** — все настроенные серверы реально запускаются
- [ ] **Ключи в безопасности** — API ключи в `"env"` блоке, не хардкодом в `"args"`
- [ ] **Ничего не упущено** — проект с БД должен иметь DB MCP и т.д.

### Команды проверки

```bash
echo "=== MCP серверы ==="
if [ -f .mcp.json ]; then
  echo "  ✅ .mcp.json exists"

  # List configured servers (parse JSON safely):
  python3 -c "
import json
try:
    data = json.load(open('.mcp.json'))
    servers = data.get('mcpServers', {})
    for name in servers:
        print(f'  📡 {name}')
    if not servers:
        print('  ⚠️ mcpServers is empty')
except Exception as e:
    print(f'  ❌ Failed to parse .mcp.json: {e}')
"

  # Check for hardcoded secrets in args (not env block):
  has_secrets=false
  grep -q 'args.*password' .mcp.json 2>/dev/null && has_secrets=true
  grep -q 'args.*token' .mcp.json 2>/dev/null && has_secrets=true
  grep -q 'args.*secret' .mcp.json 2>/dev/null && has_secrets=true
  grep -qE 'args.*api[_.-]key' .mcp.json 2>/dev/null && has_secrets=true
  if [ "$has_secrets" = true ]; then
    echo "  🔴 HARDCODED SECRETS in .mcp.json args! Move to 'env' block"
  else
    echo "  ✅ No hardcoded secrets in args"
  fi
else
  echo "  ❌ No .mcp.json"
fi

# Suggest MCP servers based on stack:
echo "=== Рекомендации ==="

# Find source directories dynamically:
src_dirs=""
for d in bot src app lib; do
  if [ -d "$d" ]; then
    if [ -z "$src_dirs" ]; then
      src_dirs="$d"
    else
      src_dirs="$src_dirs $d"
    fi
  fi
done

# DB?
if [ -n "$src_dirs" ]; then
  db_found=false
  grep -rq "DATABASE_URL" .env.example 2>/dev/null && db_found=true
  grep -rq "asyncpg" $src_dirs 2>/dev/null && db_found=true
  grep -rq "psycopg" $src_dirs 2>/dev/null && db_found=true
  grep -rq "prisma" $src_dirs 2>/dev/null && db_found=true
  if [ "$db_found" = true ]; then
    if grep -q "postgres" .mcp.json 2>/dev/null; then
      echo "  ✅ postgres MCP (проект использует PostgreSQL)"
    else
      echo "  🟠 РЕКОМЕНДУЕТСЯ: postgres MCP (проект использует PostgreSQL)"
    fi
  fi
fi

# Large codebase?
file_count=0
for ext in py ts js go rs; do
  if [ -n "$src_dirs" ]; then
    cnt=$(find $src_dirs -name "*.$ext" 2>/dev/null | wc -l | tr -d ' ')
    file_count=$((file_count + cnt))
  fi
done
if [ "$file_count" -gt 20 ]; then
  if grep -q "serena" .mcp.json 2>/dev/null; then
    echo "  ✅ serena (${file_count} source files — code intelligence полезна)"
  else
    echo "  🟡 РЕКОМЕНДУЕТСЯ: serena (${file_count} source files — symbol navigation)"
  fi
fi

# Web search? (Claude Code has built-in WebSearch/WebFetch — tavily/brave rarely needed)
if grep -qE "tavily|brave" .mcp.json 2>/dev/null; then
  echo "  🔵 tavily/brave MCP (Claude Code уже имеет встроенный WebSearch — MCP нужен только для Agent SDK)"
fi
```

### Рекомендуемые MCP-серверы по приоритету

| Приоритет | Сервер | Когда нужен | Установка |
|-----------|--------|-------------|-----------|
| 🔴 Обязательно | **postgres** | Проект с БД | `npx -y @modelcontextprotocol/server-postgres $DATABASE_URL` |
| 🟠 Важно | **serena** | Кодовая база >20 файлов | `uvx --from git+...serena start-mcp-server` |
| 🔵 Приятно | **github** | Работа с issues/PRs | `npx -y @modelcontextprotocol/server-github` |

> **tavily/brave НЕ нужен** — Claude Code имеет встроенные WebSearch + WebFetch (бесплатно, без ключа). Tavily/Brave MCP полезен только при сборке агентов через Claude Agent SDK, где встроенного поиска нет.

### Безопасность: ключи в `.mcp.json`

**Правильно** — ключи через `"env"` блок:
```json
{
  "tavily": {
    "command": "npx",
    "args": ["-y", "tavily-mcp@latest"],
    "env": { "TAVILY_API_KEY": "..." }
  }
}
```

**НЕПРАВИЛЬНО** — ключи в `"args"`:
```json
{
  "postgres": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://user:PASSWORD@host/db"]
  }
}
```

> `.mcp.json` НЕ читает `.env`. Либо хардкод в `"env"` блоке, либо connection string в `"args"` (для БД это допустимо, т.к. .mcp.json в .gitignore).

> https://docs.anthropic.com/en/docs/claude-code/mcp

---

## 4b. Плагины — расширения Claude Code

- [ ] **Context7 включён** — актуальная документация библиотек
- [ ] **Episodic memory включён** — память между сессиями
- [ ] **Нет лишних плагинов** — каждый плагин действительно используется

### Команды проверки

```bash
echo "=== Плагины ==="
plugins_found=false

# Check both settings.json and settings.local.json:
for settings_file in ".claude/settings.json" ".claude/settings.local.json"; do
  if [ -f "$settings_file" ]; then
    plugins_found=true
    echo "  📋 $settings_file:"
    # Extract enabled plugins (format: "name@source": true):
    plugin_list=$(grep -oE '"[a-zA-Z0-9_-]+@[^"]+": *true' "$settings_file" 2>/dev/null)
    if [ -n "$plugin_list" ]; then
      echo "$plugin_list" | while read -r plugin; do
        name=$(echo "$plugin" | sed 's/@.*//' | tr -d '"')
        echo "    ✅ $name"
      done
    else
      echo "    (enabledPlugins не найдены)"
    fi
  fi
done

if [ "$plugins_found" = false ]; then
  echo "  ⚠️ No .claude/settings.json found"
fi

# Check essentials (search across both files):
echo "=== Рекомендации ==="
if grep -rq "context7" .claude/settings.json .claude/settings.local.json 2>/dev/null; then
  echo "  ✅ context7 (актуальные доки библиотек)"
else
  echo "  🟠 РЕКОМЕНДУЕТСЯ: context7 (без него Claude использует знания до cutoff date)"
fi
if grep -rq "episodic-memory" .claude/settings.json .claude/settings.local.json 2>/dev/null; then
  echo "  ✅ episodic-memory (память между сессиями)"
else
  echo "  🟠 РЕКОМЕНДУЕТСЯ: episodic-memory (без него Claude забывает всё после сессии)"
fi
```

### Основные плагины

| Плагин | Что даёт | Почему важен |
|--------|----------|-------------|
| **context7** | Lookup документации библиотек | Без него Claude использует знания до cutoff — может предложить deprecated API |
| **episodic-memory** | Поиск по прошлым разговорам | Без него каждая сессия с нуля — повторяешь одни и те же объяснения |

**Полезные, но необязательные:**

| Плагин | Что даёт |
|--------|----------|
| **code-review** | Автоматический ревью PR |
| **commit-commands** | `/commit`, `/commit-push-pr` |
| **superpowers** | Расширенные workflow: TDD, debugging, brainstorming |

> https://docs.anthropic.com/en/docs/claude-code/extensions

---

## 4c. Файлы памяти — долгосрочный контекст

- [ ] **MEMORY.md существует** — user-level (`~/.claude/projects/*/memory/MEMORY.md`) или проектный
- [ ] **Регулярно обновляется** — нет стухших записей 6+ месяцев назад
- [ ] **Полезное содержимое** — решения, gotchas, паттерны (не дневник)
- [ ] **Serena memories** — `.serena/memories/` если serena plugin активен

### Команды проверки

```bash
echo "=== Файлы памяти ==="

# Check user-level MEMORY.md (Claude Code auto-memory):
# Claude stores it in ~/.claude/projects/<project-hash>/memory/MEMORY.md
project_dir=$(pwd)
project_hash=$(echo "$project_dir" | tr '/' '-')
user_memory="$HOME/.claude/projects/$project_hash/memory/MEMORY.md"
if [ -f "$user_memory" ]; then
  lines=$(wc -l < "$user_memory" | tr -d ' ')
  echo "  ✅ User MEMORY.md ($lines lines)"
  if [ "$lines" -gt 200 ]; then
    echo "     🟡 Длинный ($lines строк) — подрежь до 200, Claude видит только начало"
  fi
else
  echo "  ⚠️ No user-level MEMORY.md (Claude авто-создаёт при /memory)"
fi

# Check project-level memory files:
for f in ".claude/MEMORY.md" "MEMORY.md"; do
  if [ -f "$f" ]; then
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "  ✅ $f ($lines lines)"
    if [ "$lines" -gt 200 ]; then
      echo "     🟡 Длинный ($lines строк) — подрежь до 200"
    fi
  fi
done

# Check Serena memories:
if [ -d ".serena/memories" ]; then
  mem_count=$(find ".serena/memories" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✅ .serena/memories/ ($mem_count files)"
  find ".serena/memories" -name "*.md" 2>/dev/null | while read -r f; do
    lines=$(wc -l < "$f" | tr -d ' ')
    echo "     📝 $(basename "$f") ($lines lines)"
  done
else
  # Only warn if serena plugin is active:
  if grep -q "serena" .claude/settings.json 2>/dev/null; then
    echo "  ⚠️ No .serena/memories/ (serena plugin активен, но памяти нет)"
  fi
fi

# Check agent memory settings:
echo "=== Память агентов ==="
agents_dir=".claude/agents"
if [ -d "$agents_dir" ]; then
  for f in "$agents_dir"/*.md; do
    [ ! -f "$f" ] && continue
    name=$(grep -m1 '^name:' "$f" | sed 's/name:[[:space:]]*//')
    memory=$(grep -m1 '^memory:' "$f" | sed 's/memory:[[:space:]]*//')
    if [ -n "$memory" ]; then
      echo "  ✅ $name → memory: $memory"
    else
      echo "  🔵 $name → нет memory (каждая сессия с нуля)"
    fi
  done
fi
```

### Как выглядит хорошая память

**Должно быть:**
- Архитектурные решения и ПОЧЕМУ они приняты
- Gotchas и known issues (с solutions)
- Паттерны проекта (как добавлять новые модули, тесты)
- Ключевые ID/константы (chat IDs, API endpoints)

**НЕ должно быть:**
- Хронология "сегодня сделал X" (это лог, не память)
- Дублирование CLAUDE.md
- Устаревшие решения без пометки deprecated

### Типы памяти

| Тип | Где хранится | Для чего |
|-----|-------------|----------|
| **User MEMORY.md** | `~/.claude/projects/*/memory/` | Авто-память Claude: паттерны, решения, gotchas |
| **Serena memories** | `.serena/memories/` | Глубокий контекст: архитектура, тесты, интеграции |
| **Память агента** | `memory: user/project` в agent YAML | Per-agent контекст: debugger помнит баги, architect — решения |
| **CLAUDE.md** | Корень проекта | Критические правила (загружается КАЖДУЮ сессию) |

> Agent `memory: user` сохраняет в user-level storage. `memory: project` — в `.claude/agent-memory/`. Без `memory:` — агент забывает всё.

> https://docs.anthropic.com/en/docs/claude-code/memory

---

## 4d. SessionStart compact хук — контекст после compaction

Когда контекст Claude переполняется, происходит compaction — старые сообщения сжимаются. Claude забывает критичные правила проекта (monkey-patch, cookie format, async constraints). SessionStart хук с matcher `compact` инжектирует ремайндер ТОЛЬКО после compaction.

- [ ] **SessionStart хук существует** — с matcher `compact` в settings.json
- [ ] **Ремайндер специфичен для проекта** — содержит 3-5 критичных правил проекта
- [ ] **Краткий** — не длинный текст, а короткий prompt для восстановления контекста

### Команды проверки

```bash
echo "=== SessionStart compact хук ==="
settings=".claude/settings.json"

if [ ! -f "$settings" ]; then
  echo "  ❌ No .claude/settings.json"
else
  compact_hook=$(python3 -c "
import json
data = json.load(open('$settings'))
hooks = data.get('hooks', {}).get('SessionStart', [])
for h in hooks:
    if h.get('matcher') == 'compact':
        for hook in h.get('hooks', []):
            cmd = hook.get('command', '')
            print(cmd[:100])
" 2>/dev/null)

  if [ -n "$compact_hook" ]; then
    echo "  ✅ SessionStart compact хук найден"
    echo "     $compact_hook"
  else
    # Check if there's SessionStart at all:
    has_session=$(grep -q "SessionStart" "$settings" 2>/dev/null && echo "yes")
    if [ "$has_session" = "yes" ]; then
      echo "  ⚠️ SessionStart хук есть, но нет matcher 'compact'"
      echo "     → Добавь matcher: 'compact' чтобы ремайндер срабатывал только после compaction"
    else
      echo "  ⚠️ Нет SessionStart compact хука"
      echo "     После compaction Claude забудет критичные правила проекта"
      echo "     → Добавь одну строку с самыми важными gotchas проекта"
    fi
  fi
fi
```

### Как написать хороший compact ремайндер

**Должен содержать** (одна строка, 3-5 пунктов):
- Критичные init-шаги (monkey-patch, env loading)
- Формат данных (cookie format, HTML parse_mode)
- Anti-patterns (no sync I/O, no Markdown in prompt)
- Как запустить и проверить (`python test_digest.py`)

**Пример:**
```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "compact",
      "hooks": [{
        "type": "command",
        "command": "echo 'CONTEXT REMINDER: Apply monkey-patch FIRST. Cookie: space after semicolon. Telegram: HTML parse_mode. AI: no Markdown. Test: python test_digest.py'"
      }]
    }]
  }
}
```

**Не должен**: быть длинным (>200 символов), дублировать CLAUDE.md, содержать секреты.

> https://docs.anthropic.com/en/docs/claude-code/hooks

---

## 4e. Хук уведомлений — оповещение когда Claude ждёт

Без оповещения: Claude закончил работу и ждёт ввода, а юзер ушёл за кофе. С хуком уведомлений — macOS/Linux уведомление со звуком при каждом ожидании.

- [ ] **Хук уведомлений существует** — в settings.json
- [ ] **Кроссплатформенный** — macOS (osascript) или Linux (notify-send)
- [ ] **Со звуком** — звуковой сигнал чтобы заметить из другого окна

### Команды проверки

```bash
echo "=== Хук уведомлений ==="
settings=".claude/settings.json"

if [ ! -f "$settings" ]; then
  echo "  ❌ No .claude/settings.json"
else
  notif_hook=$(python3 -c "
import json
data = json.load(open('$settings'))
hooks = data.get('hooks', {}).get('Notification', [])
for h in hooks:
    for hook in h.get('hooks', []):
        cmd = hook.get('command', '')
        print(cmd[:80])
" 2>/dev/null)

  if [ -n "$notif_hook" ]; then
    echo "  ✅ Хук уведомлений найден"
    # Check for sound:
    if echo "$notif_hook" | grep -qiE "sound|notify-send|osascript"; then
      echo "  ✅ Системное уведомление"
    fi
  else
    echo "  🔵 Нет хука уведомлений (опционально, но экономит время)"
    echo "     Claude ждёт ввода, а ты не знаешь — уведомление решает"
  fi
fi
```

### Уведомления по ОС

**macOS:**
```json
{
  "hooks": {
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "osascript -e 'display notification \"Claude needs input\" with title \"Claude Code\" sound name \"Glass\"'"
      }]
    }]
  }
}
```

**Linux:**
```bash
notify-send "Claude Code" "Claude needs your input" --urgency=normal
# Для звука: paplay /usr/share/sounds/freedesktop/stereo/message.oga
```

> https://docs.anthropic.com/en/docs/claude-code/hooks
