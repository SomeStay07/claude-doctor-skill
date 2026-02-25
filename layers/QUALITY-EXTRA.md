# Слой 2 (продолжение): Продвинутые проверки качества

Основные проверки: [QUALITY.md](QUALITY.md)

---

## 2h. Проверка типов — ловим баги до запуска

AI-код часто untyped — нет аннотаций типов, нет проверки. Результат: 2.27x больше null reference ошибок, неправильные аргументы функций, невозможность рефакторить.

- [ ] **Type checker настроен** — mypy / pyright (Python) / tsc --strict (TypeScript)
- [ ] **Запускается в CI или pre-commit** — не ручной запуск
- [ ] **Конфиг существует** — `mypy.ini` / `pyrightconfig.json` / `tsconfig.json` с strict

### Команды проверки

```bash
echo "=== Type checking ==="

# Python?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  mypy_found=false
  pyright_found=false

  if command -v mypy &>/dev/null || [ -f .venv/bin/mypy ]; then
    mypy_found=true
    echo "  ✅ mypy installed"
  fi
  if command -v pyright &>/dev/null || [ -f .venv/bin/pyright ]; then
    pyright_found=true
    echo "  ✅ pyright installed"
  fi

  if [ "$mypy_found" = false ] && [ "$pyright_found" = false ]; then
    echo "  ⚠️ No type checker — pip install mypy"
    echo "     AI-код без типов: 2.27x больше null reference ошибок"
  fi

  # Config?
  if [ -f mypy.ini ] || [ -f .mypy.ini ]; then
    echo "  ✅ mypy config found"
  elif [ -f pyproject.toml ] && grep -q '\[tool.mypy\]' pyproject.toml 2>/dev/null; then
    echo "  ✅ mypy config in pyproject.toml"
  elif [ -f pyrightconfig.json ]; then
    echo "  ✅ pyright config found"
  elif [ "$mypy_found" = true ] || [ "$pyright_found" = true ]; then
    echo "  ⚠️ Type checker installed but no config — using loose defaults"
    echo "     → Создай mypy.ini: [mypy]\\nstrict = true"
  fi

  # Type annotations presence:
  src_dirs=""
  for d in bot src app lib; do
    [ -d "$d" ] && src_dirs="$src_dirs $d"
  done
  if [ -n "$src_dirs" ]; then
    total_funcs=$(grep -rn "def " --include="*.py" $src_dirs 2>/dev/null | wc -l | tr -d ' ')
    typed_funcs=$(grep -rn "def .*->.*:" --include="*.py" $src_dirs 2>/dev/null | wc -l | tr -d ' ')
    if [ "$total_funcs" -gt 0 ]; then
      pct=$((typed_funcs * 100 / total_funcs))
      echo "  📊 Type annotations: $typed_funcs/$total_funcs functions ($pct%)"
      if [ "$pct" -lt 30 ]; then
        echo "     ⚠️ Мало аннотаций — mypy не сможет поймать баги"
      fi
    fi
  fi
fi

# TypeScript?
if [ -f tsconfig.json ]; then
  echo "  ✅ tsconfig.json found"
  if grep -q '"strict"[[:space:]]*:[[:space:]]*true' tsconfig.json 2>/dev/null; then
    echo "  ✅ strict mode enabled"
  else
    echo "  ⚠️ strict mode NOT enabled — пропускает null checks, implicit any"
    echo "     → Добавь \"strict\": true в tsconfig.json"
  fi
  # Check for any:
  any_count=$(grep -rn ": any" --include="*.ts" --include="*.tsx" src/ app/ 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
  if [ "$any_count" -gt 10 ]; then
    echo "  ⚠️ $any_count uses of ': any' — типизация обходится"
  fi
fi
```

### Type checker по стеку

| Стек | Инструмент | Конфиг | Strict mode |
|------|------------|--------|-------------|
| Python | mypy | `mypy.ini` / `pyproject.toml` | `strict = true` |
| Python | pyright | `pyrightconfig.json` | `"typeCheckingMode": "strict"` |
| TypeScript | tsc | `tsconfig.json` | `"strict": true` |
| Rust | cargo | встроено | всегда strict |
| Go | go vet | встроено | всегда strict |

> https://mypy.readthedocs.io/en/stable/getting_started.html

---

## 2i. Покрытие кода тестами — тесты реально покрывают код

Тесты существуют != тесты покрывают код. Можно иметь 500 тестов и 10% покрытия. Coverage gate не даёт мержить код без тестов.

- [ ] **Инструмент покрытия настроен** — pytest-cov (Python) / istanbul/c8 (Node) / tarpaulin (Rust)
- [ ] **Порог установлен** — минимум 60-70% для мерж
- [ ] **Отчёт в CI** — coverage отчёт видно в PR

### Команды проверки

```bash
echo "=== Code coverage ==="

# Python?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if pip show pytest-cov &>/dev/null 2>&1 || grep -q "pytest-cov" requirements*.txt pyproject.toml 2>/dev/null; then
    echo "  ✅ pytest-cov installed"
  else
    echo "  ⚠️ No pytest-cov — pip install pytest-cov"
    echo "     Без coverage: тесты могут покрывать 10% кода и ты не узнаешь"
  fi

  # Check for coverage config:
  cov_config=false
  if [ -f .coveragerc ]; then
    cov_config=true
    echo "  ✅ .coveragerc config"
  elif [ -f pyproject.toml ] && grep -q '\[tool.coverage\]' pyproject.toml 2>/dev/null; then
    cov_config=true
    echo "  ✅ coverage config in pyproject.toml"
  elif [ -f setup.cfg ] && grep -q '\[coverage' setup.cfg 2>/dev/null; then
    cov_config=true
    echo "  ✅ coverage config in setup.cfg"
  fi

  # Check for fail_under threshold:
  if [ "$cov_config" = true ]; then
    if grep -rq "fail_under" .coveragerc pyproject.toml setup.cfg 2>/dev/null; then
      threshold=$(grep -r "fail_under" .coveragerc pyproject.toml setup.cfg 2>/dev/null | head -1 | grep -oE '[0-9]+')
      echo "  ✅ Coverage threshold: ${threshold}%"
    else
      echo "  ⚠️ No fail_under threshold — coverage может падать незаметно"
    fi
  fi

  # Check CI for coverage:
  for f in $(find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null); do
    if grep -qiE 'coverage|pytest-cov|--cov' "$f" 2>/dev/null; then
      echo "  ✅ Coverage in CI: $(basename "$f")"
    fi
  done
fi

# Node.js?
if [ -f package.json ]; then
  if grep -qE '"c8"|"istanbul"|"nyc"|"vitest.*coverage"' package.json 2>/dev/null; then
    echo "  ✅ Coverage tool in package.json"
  else
    echo "  ⚠️ No coverage tool — npm i -D c8 (или vitest с --coverage)"
  fi

  # Check for coverage threshold in package.json or jest config:
  if grep -qE '"coverageThreshold"' package.json jest.config.* 2>/dev/null; then
    echo "  ✅ Coverage threshold configured"
  fi
fi
```

### Пороги покрытия

| Уровень | Порог | Для кого |
|---------|-------|----------|
| Начинающий | 40% | Лучше чем 0%, приучает писать тесты |
| Средний | 60-70% | Баланс между покрытием и скоростью |
| Продвинутый | 80%+ | Критичные проекты, библиотеки |

**Совет**: начни с 40%, повышай постепенно. Резкий 80% порог = все тесты будут `assert True`.

> https://testing.googleblog.com/2020/08/code-coverage-best-practices.html

---

## 2j. Нет print() / console.log в production

AI обожает `print()` для дебага. В production нужен `logging` с уровнями (DEBUG/INFO/WARNING/ERROR), ротацией, structured output. `print()` не имеет уровней, не пишет в файл, не показывает timestamp.

- [ ] **Нет print() в исходниках** — только `logging.xxx()` в production коде
- [ ] **Нет console.log** — только structured logging (winston/pino) в Node.js production
- [ ] **Logging настроен** — уровни, format, handlers

### Команды проверки

```bash
echo "=== Production logging ==="

# Python — print() in source:
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  src_dirs=""
  for d in bot src app lib; do
    [ -d "$d" ] && src_dirs="$src_dirs $d"
  done
  if [ -n "$src_dirs" ]; then
    print_count=$(grep -rn "^\s*print(" --include="*.py" $src_dirs 2>/dev/null | grep -v "#" | grep -v "test" | wc -l | tr -d ' ')
    if [ "$print_count" -gt 5 ]; then
      echo "  🟠 $print_count print() statements in production code"
      grep -rn "^\s*print(" --include="*.py" $src_dirs 2>/dev/null | grep -v "#" | grep -v "test" | head -5 | while read -r line; do
        echo "     $line"
      done
      echo "     → Замени на logging.info()/logging.debug()"
    elif [ "$print_count" -gt 0 ]; then
      echo "  ⚠️ $print_count print() statements (немного, но лучше logging)"
    else
      echo "  ✅ No print() in production code"
    fi

    # Check logging is configured:
    if grep -rq "import logging" --include="*.py" $src_dirs 2>/dev/null; then
      echo "  ✅ logging module used"
    else
      echo "  ⚠️ logging module not imported — возможно весь вывод через print()"
    fi
  fi
fi

# Node.js — console.log in source:
if [ -f package.json ]; then
  src_dirs=""
  for d in src app lib; do
    [ -d "$d" ] && src_dirs="$src_dirs $d"
  done
  if [ -n "$src_dirs" ]; then
    console_count=$(grep -rn "console\.\(log\|info\|warn\|error\)" --include="*.ts" --include="*.js" $src_dirs 2>/dev/null | grep -v "test" | grep -v "spec" | wc -l | tr -d ' ')
    if [ "$console_count" -gt 10 ]; then
      echo "  🟠 $console_count console.* calls in production code"
      echo "     → Используй winston/pino вместо console.log"
    elif [ "$console_count" -gt 0 ]; then
      echo "  ⚠️ $console_count console.* calls (ОК для dev, плохо для production)"
    else
      echo "  ✅ No console.log in production code"
    fi

    # Check for structured logging:
    if grep -qE '"winston"|"pino"|"bunyan"|"log4js"' package.json 2>/dev/null; then
      echo "  ✅ Structured logging library found"
    fi
  fi
fi
```

### Почему logging лучше print

| | `print()` | `logging` |
|---|-----------|-----------|
| Уровни | Нет | DEBUG/INFO/WARNING/ERROR/CRITICAL |
| Timestamp | Нет | Автоматически |
| Файл | Только stdout | Файл + stdout + rotation |
| Фильтрация | Нельзя | По уровню, модулю |
| Production | Спам в stdout | Structured JSON для мониторинга |

> https://docs.python.org/3/howto/logging.html

---

## 2k. PreToolUse hooks — предотвращение ошибок ДО записи

PostToolUse ловит ошибки ПОСЛЕ записи. PreToolUse **предотвращает** их — блокирует опасные команды и напоминает правила до того, как Claude напишет код.

- [ ] **Напоминания по шаблонам** — PreToolUse для Edit|Write с domain-specific подсказками (async rules, cookie format, etc.)
- [ ] **Блокировка опасных команд** — PreToolUse для Bash блокирует `gh pr merge`, `git merge main`, `rm -rf` без явного разрешения
- [ ] **Привязка к путям** — reminders срабатывают только для нужных файлов (не шумят на каждый edit)

### Команды проверки

```bash
echo "=== PreToolUse hooks ==="
settings=".claude/settings.json"

if [ ! -f "$settings" ]; then
  echo "  ❌ No .claude/settings.json"
else
  # Check for PreToolUse hooks:
  pre_hooks=$(python3 -c "
import json
data = json.load(open('$settings'))
hooks = data.get('hooks', {}).get('PreToolUse', [])
for h in hooks:
    matcher = h.get('matcher', '(any)')
    for hook in h.get('hooks', []):
        cmd = hook.get('command', '')
        cmd_short = cmd.split('/')[-1] if '/' in cmd else cmd[:60]
        print(f'  📋 matcher={matcher} → {cmd_short}')
" 2>/dev/null)

  if [ -n "$pre_hooks" ]; then
    echo "$pre_hooks"

    # Check for pattern reminders (Edit|Write):
    if echo "$pre_hooks" | grep -q "Edit\|Write"; then
      echo "  ✅ Pattern reminders for Edit|Write"
    else
      echo "  ⚠️ No pattern reminders for Edit|Write — Claude пишет код без подсказок"
    fi

    # Check for dangerous command blocking (Bash):
    if echo "$pre_hooks" | grep -q "Bash"; then
      echo "  ✅ Dangerous command blocking for Bash"
    else
      echo "  ⚠️ No Bash command blocking — Claude может случайно merge/delete"
    fi
  else
    echo "  ⚠️ No PreToolUse hooks"
    echo "     PostToolUse ловит ПОСЛЕ ошибки, PreToolUse ПРЕДОТВРАЩАЕТ"
    echo "     → Добавь pattern reminders (async rules, security) + command blocker (merge, rm -rf)"
  fi
fi
```

### Два типа PreToolUse hooks

**1. Напоминания по шаблонам** (matcher: `Edit|Write`) — не блокируют, только напоминают:
```bash
#!/bin/bash
# check-patterns.sh — domain-specific reminders
file_path="$CLAUDE_FILE_PATH"
if [[ "$file_path" =~ bot/.*\.py$ ]]; then
  echo "Reminders: no sync I/O in async, no bare except, logging not print()"
fi
exit 0  # НЕ блокирует — только советует
```

**2. Блокировщики команд** (matcher: `Bash`) — реально блокируют опасные команды:
```bash
#!/bin/bash
# block-dangerous.sh — prevent accidental merges/deletes
if echo "$CLAUDE_BASH_COMMAND" | grep -qiE '(gh\s+pr\s+merge|git\s+merge\s+(main|master)|rm\s+-rf)'; then
  echo "BLOCKED: This command requires explicit user permission"
  exit 2  # Блокирует выполнение
fi
exit 0
```

**Exit codes**: `exit 0` = разрешить (с advisory output), `exit 2` = заблокировать.

> https://docs.anthropic.com/en/docs/claude-code/hooks
