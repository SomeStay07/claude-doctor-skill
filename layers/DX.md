# Слой 5: Опыт разработчика — "Всё автоматизировано"

Без DX-слоя разработчик вручную вспоминает команды, забывает закоммитить, узнаёт о сломанном API только в production. С Layer 5 — одна команда делает всё правильно, хуки напоминают, тесты ловят регрессии.

---

## 5a. Скиллы — slash-команды проекта (~15 мин) [cc]
<!-- glossary: скиллы = готовые команды (/test, /status), автоматизирующие рутинные задачи -->

- [ ] **Базовые скиллы** — `/test` + `/status` (минимум для любого проекта)
- [ ] **Проект-специфичные** — не шаблоны, а реальные команды проекта
- [ ] **Есть триггеры** — description содержит trigger phrases для авто-вызова
- [ ] **Есть аргументы** — `/test quick`, `/status git`, `/deploy check`

### Команды проверки

```bash
echo "=== Skills ==="
skills_dir=".claude/skills"
if [ -d "$skills_dir" ]; then
  skill_count=0
  for d in "$skills_dir"/*/; do
    [ ! -d "$d" ] && continue
    skill_file="$d/SKILL.md"
    if [ -f "$skill_file" ]; then
      skill_count=$((skill_count + 1))
      name=$(grep -m1 '^name:' "$skill_file" | sed 's/name:[[:space:]]*//')
      has_triggers=$(grep -c 'Triggers:' "$skill_file" 2>/dev/null)
      has_triggers=${has_triggers:-0}
      has_args=$(grep -c 'ARGUMENTS' "$skill_file" 2>/dev/null)
      has_args=${has_args:-0}
      has_tools=$(grep -c '^allowed-tools:' "$skill_file" 2>/dev/null)
      has_tools=${has_tools:-0}
      if [ "$has_triggers" -gt 0 ] && [ "$has_args" -gt 0 ]; then
        echo "  ✅ /$name (triggers + args)"
      elif [ "$has_triggers" -gt 0 ]; then
        echo "  ⚠️ /$name (triggers, но нет \$ARGUMENTS handling)"
      else
        echo "  ⚠️ /$name (нет triggers — Claude не вызовет автоматически)"
      fi
      [ "$has_tools" -eq 0 ] && echo "     ⚠️ нет allowed-tools — наследует ВСЕ инструменты"
    fi
  done
  echo "  📊 Итого: $skill_count skills"
else
  echo "  ❌ No .claude/skills/ directory"
fi

# Check core skills:
echo "=== Core skills ==="
for skill in "test" "status"; do
  found=false
  for d in "$skills_dir"/*/; do
    [ ! -d "$d" ] && continue
    skill_file="$d/SKILL.md"
    if [ -f "$skill_file" ]; then
      skill_name=$(grep -m1 '^name:' "$skill_file" | sed 's/name:[[:space:]]*//')
      case "$skill_name" in
        *test*) [ "$skill" = "test" ] && found=true ;;
        *status*) [ "$skill" = "status" ] && found=true ;;
      esac
    fi
  done
  if [ "$found" = true ]; then
    echo "  ✅ /$skill"
  else
    echo "  ⚠️ MISSING: /$skill"
  fi
done

# launch.json для Claude Preview:
if [ -f .claude/launch.json ]; then
  echo "  ✅ .claude/launch.json (Claude Preview)"
elif [ -f package.json ] && grep -qE '"(dev|start|serve)"' package.json 2>/dev/null; then
  echo "  🔵 Нет .claude/launch.json — Claude Preview не запустит dev-сервер"
fi
```

### Минимальный набор skills

| Skill | Что делает | Почему нужен |
|-------|-----------|--------------|
| `/test` | Запускает тесты с правильными флагами | Не нужно помнить `pytest tests/ -v --tb=short` |
| `/status` | Показывает состояние проекта | Git, тесты, зависимости, конфиг — одним взглядом |

**Для зрелых проектов:**

| Skill | Что делает | Почему нужен |
|-------|-----------|--------------|
| `/deploy` | Pre-flight + деплой | Не забудешь прогнать тесты перед пушем |
| `/checkpoint` | Точка отката (stash/commit/tag) | Безопасное начало рискованных изменений |
| `/memory` | Управление памятью проекта | Сохраняет знания, удаляет дубликаты |

### Что делает хороший skill

**Обязательно:**
- `name` + `description` с trigger phrases (Claude использует для авто-вызова)
- `allowed-tools` ограничены до нужного минимума
- `$ARGUMENTS` handling — поддержка подкоманд
- Реальные команды проекта (не шаблонные `npm test`)

**Нельзя:**
- Generic команды без специфики проекта
- Отсутствие error handling в bash скриптах
- Хардкодные пути вместо переменных

> https://docs.anthropic.com/en/docs/claude-code/skills

---

## 5b. Stop хук — напоминание при выходе (~5 мин) [quality]
<!-- glossary: stop hook = скрипт, напоминающий сохранить работу при завершении сессии Claude -->

- [ ] **Хук существует** — `Stop` hook в `.claude/settings.json`
- [ ] **Проверяет uncommitted** — `git status --porcelain`
- [ ] **Напоминает про память** — напоминает `/memory update`
- [ ] **Защита от рекурсии** — переменная `STOP_HOOK_ACTIVE` предотвращает бесконечный цикл

### Команды проверки

```bash
echo "=== Stop hook ==="
stop_settings=""
for sf in .claude/settings.local.json .claude/settings.json; do
  [ -f "$sf" ] && grep -q '"Stop"' "$sf" 2>/dev/null && stop_settings="$sf" && break
done
if [ -n "$stop_settings" ]; then
  echo "  ✅ Stop hook configured"
  python3 -c "
import json, sys, shlex
data = json.load(open(sys.argv[1]))
for h in data.get('hooks', {}).get('Stop', []):
    for hook in h.get('hooks', []):
        cmd = hook.get('command', '')
        if cmd:
            parts = shlex.split(cmd)
            print(parts[-1] if len(parts) > 1 else cmd)
" "$stop_settings" 2>/dev/null | while read -r script_path; do
    resolved=$(echo "$script_path" | sed "s|\\\$CLAUDE_PROJECT_DIR|$PWD|g")
    if [ -f "$resolved" ]; then
      echo "     script: $(basename "$resolved")"
      grep -q "porcelain" "$resolved" 2>/dev/null && echo "     uncommitted check: ✅" || echo "     uncommitted check: ⚠️ missing"
      grep -q "memory" "$resolved" 2>/dev/null && echo "     memory reminder: ✅" || echo "     memory reminder: ⚠️ missing"
      grep -q "STOP_HOOK_ACTIVE" "$resolved" 2>/dev/null && echo "     loop protection: ✅" || echo "     loop protection: ⚠️ missing"
    else
      echo "     ⚠️ script not found: $resolved"
    fi
  done
elif [ -f .claude/settings.local.json ] || [ -f .claude/settings.json ]; then
  echo "  ⚠️ No Stop hook — при выходе не напомнит про незакоммиченные изменения"
else
  echo "  ❌ No .claude/settings.json"
fi
```

### Правильный Stop hook

Хороший Stop hook делает 3 вещи:
1. **Проверяет uncommitted changes** — не уйдёшь с потерянной работой
2. **Напоминает про memory** — сохрани знания пока контекст свежий
3. **Защита от рекурсии** — `STOP_HOOK_ACTIVE` предотвращает бесконечный цикл

> https://docs.anthropic.com/en/docs/claude-code/hooks

---

## 5c. Юнит-тесты — существуют и проходят (~10 мин) [cc]

- [ ] **Директория тестов** — `tests/`, `test/`, `__tests__/` существует
- [ ] **Тесты проходят** — test runner exits 0
- [ ] **Покрытие модулей** — для каждого source модуля есть тест

### Команды проверки

```bash
echo "=== Unit tests ==="

# Find test directory:
test_dir=""
for d in tests test __tests__ spec; do
  if [ -d "$d" ]; then
    test_dir="$d"
    break
  fi
done

if [ -n "$test_dir" ]; then
  test_count=$(find "$test_dir" \( -name "*.py" -o -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✅ $test_dir/ ($test_count test files)"
else
  echo "  ❌ No test directory found"
fi

# Find source directories:
src_dirs=""
for d in src app lib bot server backend api core pkg cmd internal services packages; do
  [ -d "$d" ] && src_dirs="${src_dirs:+$src_dirs }$d"
done

# Coverage ratio (Python):
if [ -n "$test_dir" ] && [ -n "$src_dirs" ]; then
  echo "=== Test coverage ==="
  missing=0
  total=0
  while read -r f; do
    base=$(basename "$f" .py)
    total=$((total + 1))
    if ! find "$test_dir" -name "*${base}*" -name "*.py" 2>/dev/null | grep -q .; then
      echo "  ⚠️ MISSING tests: $f"
      missing=$((missing + 1))
    fi
  done < <(find $src_dirs -name "*.py" ! -name "__init__.py" ! -path "*__pycache__*" 2>/dev/null)
  covered=$((total - missing))
  if [ "$total" -gt 0 ]; then
    pct=$((covered * 100 / total))
    echo "  📊 Coverage: $covered/$total modules ($pct%)"
  fi
fi

# Coverage ratio (TypeScript/JavaScript):
if [ -n "$test_dir" ] && [ -n "$src_dirs" ]; then
  ts_files=$(find $src_dirs -name "*.ts" -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ts_files" -gt 0 ]; then
    echo "=== TypeScript test coverage ==="
    ts_missing=0
    while read -r f; do
      base=$(basename "$f" .ts)
      if ! find . \( -name "${base}.test.ts" -o -name "${base}.spec.ts" \) 2>/dev/null | grep -q .; then
        echo "  ⚠️ MISSING tests: $f"
        ts_missing=$((ts_missing + 1))
      fi
    done < <(find $src_dirs -name "*.ts" -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" 2>/dev/null)
    ts_covered=$((ts_files - ts_missing))
    pct=$((ts_covered * 100 / ts_files))
    echo "  📊 Coverage: $ts_covered/$ts_files modules ($pct%)"
  fi
fi
```

### Антипаттерны покрытия

- **`__init__.py` без тестов** — это нормально, не считаем
- **`models.py` без тестов** — ОК если dataclass-only, плохо если есть логика
- **100% file coverage ≠ 100% code coverage** — файл может иметь тест, но тест покрывает 10% функций

---

## 5d. Smoke-тесты — быстрая проверка "работает?" (~10 мин) [advanced]
<!-- glossary: smoke test = быстрый тест "приложение вообще запускается?" — занимает секунды -->

- [ ] **Импорт работает** — основной модуль импортируется без ошибок
- [ ] **Конфиг парсится** — конфигурация загружается
- [ ] **Быстрая команда** — есть команда для быстрой проверки (<5 секунд)

### Команды проверки

```bash
echo "=== Smoke tests ==="

# Python project?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  # Find main module:
  main_module=""
  for m in src app lib bot server backend api core; do
    if [ -d "$m" ] && [ -f "$m/__init__.py" ] || [ -d "$m" ]; then
      main_module="$m"
      break
    fi
  done

  if [ -n "$main_module" ]; then
    # ⚠️ НЕ запускай import автоматически — может иметь side effects
    # (запуск серверов, подключение к БД, отправка писем)
    if [ -f "$main_module/__init__.py" ]; then
      echo "  🔵 import $main_module — проверь в Фазе 5 (может иметь side effects)"
      echo "     → python3 -c \"import $main_module\""
    else
      echo "  ⚠️ $main_module/ не имеет __init__.py — не Python-пакет"
    fi
  fi
fi

# Node.js project?
if [ -f package.json ]; then
  # ⚠️ НЕ запускай require автоматически — может запустить сервер
  echo "  🔵 Проверь вручную в Фазе 5: node -e \"require('./src/index.js')\""
fi

# Quick test command?
echo "=== Quick test ==="
if [ -f Makefile ] && grep -q '^test:' Makefile 2>/dev/null; then
  echo "  ✅ make test"
elif [ -f package.json ] && grep -q '"test"' package.json 2>/dev/null; then
  echo "  ✅ npm test"
elif [ -d tests ] || [ -d test ]; then
  echo "  ✅ pytest / test runner available"
else
  echo "  ⚠️ No quick test command found"
fi
```

> https://docs.anthropic.com/en/docs/claude-code/skills

---

> Продвинутые проверки (5e Dependabot, 5f установщик хуков, 5g оптимизация скиллов) → [DX-EXTRA.md](DX-EXTRA.md)
