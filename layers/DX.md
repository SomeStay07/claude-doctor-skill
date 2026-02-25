# Слой 5: Опыт разработчика — "Всё автоматизировано"

Без DX-слоя разработчик вручную вспоминает команды, забывает закоммитить, узнаёт о сломанном API только в production. С Layer 5 — одна команда делает всё правильно, хуки напоминают, тесты ловят регрессии.

---

## 5a. Skills — slash-команды проекта

- [ ] **Core skills exist** — `/test` + `/status` (минимум для любого проекта)
- [ ] **Skills are project-specific** — не шаблоны, а реальные команды проекта
- [ ] **Skills have triggers** — description содержит trigger phrases для авто-вызова
- [ ] **Skills have arguments** — `/test quick`, `/status git`, `/deploy check`

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
      if [ "$has_triggers" -gt 0 ] && [ "$has_args" -gt 0 ]; then
        echo "  ✅ /$name (triggers + args)"
      elif [ "$has_triggers" -gt 0 ]; then
        echo "  ⚠️ /$name (triggers, но нет $ARGUMENTS handling)"
      else
        echo "  ⚠️ /$name (нет triggers — Claude не вызовет автоматически)"
      fi
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

## 5b. Stop hook — напоминание при выходе

- [ ] **Hook exists** — `Stop` hook в `.claude/settings.json`
- [ ] **Checks uncommitted** — `git status --porcelain`
- [ ] **Reminds memory** — напоминает `/memory update`
- [ ] **No infinite loops** — защита от рекурсии (`STOP_HOOK_ACTIVE`)

### Команды проверки

```bash
echo "=== Stop hook ==="
settings=".claude/settings.json"
if [ -f "$settings" ]; then
  if grep -q '"Stop"' "$settings" 2>/dev/null; then
    echo "  ✅ Stop hook configured"
    # Find stop hook scripts (search for .sh files referenced in Stop section):
    # Extract command value from JSON (handles $CLAUDE_PROJECT_DIR):
    python3 -c "
import json
data = json.load(open('$settings'))
hooks = data.get('hooks', {}).get('Stop', [])
for h in hooks:
    for hook in h.get('hooks', []):
        cmd = hook.get('command', '')
        if cmd:
            print(cmd)
" 2>/dev/null | while read -r stop_cmd; do
      resolved=$(echo "$stop_cmd" | sed "s|\"\\\$CLAUDE_PROJECT_DIR\"|$PWD|g" | sed "s|\\\$CLAUDE_PROJECT_DIR|$PWD|g" | sed 's|"||g')
      if [ -f "$resolved" ]; then
        echo "     script: $(basename "$resolved")"
        grep -q "porcelain" "$resolved" 2>/dev/null && echo "     uncommitted check: ✅" || echo "     uncommitted check: ⚠️ missing"
        grep -q "memory" "$resolved" 2>/dev/null && echo "     memory reminder: ✅" || echo "     memory reminder: ⚠️ missing"
        grep -q "STOP_HOOK_ACTIVE" "$resolved" 2>/dev/null && echo "     loop protection: ✅" || echo "     loop protection: ⚠️ missing"
      else
        echo "     ⚠️ script not found: $resolved"
      fi
    done
  else
    echo "  ⚠️ No Stop hook — при выходе не напомнит про незакоммиченные изменения"
  fi
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

## 5c. Unit tests — существуют и проходят

- [ ] **Test directory exists** — `tests/`, `test/`, `__tests__/`
- [ ] **Tests actually run** — test runner exits 0
- [ ] **Coverage ratio** — для каждого source модуля есть тест

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
  test_count=$(find "$test_dir" -name "*.py" -o -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✅ $test_dir/ ($test_count test files)"
else
  echo "  ❌ No test directory found"
fi

# Find source directories:
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

# Coverage ratio (Python):
if [ -n "$test_dir" ] && [ -n "$src_dirs" ]; then
  echo "=== Test coverage ==="
  missing=0
  total=0
  for f in $(find $src_dirs -name "*.py" ! -name "__init__.py" ! -path "*__pycache__*" 2>/dev/null); do
    base=$(basename "$f" .py)
    total=$((total + 1))
    if ! find "$test_dir" -name "*${base}*" -name "*.py" 2>/dev/null | grep -q .; then
      echo "  ⚠️ MISSING tests: $f"
      missing=$((missing + 1))
    fi
  done
  covered=$((total - missing))
  if [ "$total" -gt 0 ]; then
    pct=$((covered * 100 / total))
    echo "  📊 Coverage: $covered/$total modules ($pct%)"
  fi
fi

# Coverage ratio (TypeScript/JavaScript):
if [ -n "$test_dir" ]; then
  ts_files=$(find $src_dirs -name "*.ts" -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ts_files" -gt 0 ]; then
    echo "=== TypeScript test coverage ==="
    ts_missing=0
    for f in $(find $src_dirs -name "*.ts" -not -name "*.test.*" -not -name "*.spec.*" -not -name "*.d.ts" 2>/dev/null); do
      base=$(basename "$f" .ts)
      if ! find . -name "${base}.test.ts" -o -name "${base}.spec.ts" 2>/dev/null | grep -q .; then
        echo "  ⚠️ MISSING tests: $f"
        ts_missing=$((ts_missing + 1))
      fi
    done
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

## 5d. Smoke tests — быстрая проверка "работает?"

- [ ] **Import check** — основной модуль импортируется без ошибок
- [ ] **Config loads** — конфигурация парсится
- [ ] **Quick command** — есть команда для быстрой проверки (<5 секунд)

### Команды проверки

```bash
echo "=== Smoke tests ==="

# Python project?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  # Find main module:
  main_module=""
  for m in bot src app; do
    if [ -d "$m" ] && [ -f "$m/__init__.py" ] || [ -d "$m" ]; then
      main_module="$m"
      break
    fi
  done

  if [ -n "$main_module" ]; then
    # Test import:
    if python3 -c "import $main_module" 2>/dev/null; then
      echo "  ✅ import $main_module works"
    else
      echo "  ❌ import $main_module fails"
    fi
  fi

  # Test config:
  if [ -f "${main_module}/config.py" ]; then
    if python3 -c "from ${main_module}.config import load_config; load_config()" 2>/dev/null; then
      echo "  ✅ config loads OK"
    else
      echo "  ⚠️ config load fails (missing .env or config.yaml?)"
    fi
  fi
fi

# Node.js project?
if [ -f package.json ]; then
  if node -e "require('./src/index.js')" 2>/dev/null || node -e "require('./dist/index.js')" 2>/dev/null; then
    echo "  ✅ main module loads"
  fi
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

## 5e. Dependabot / Renovate — автообновление зависимостей

Layer 1e проверяет freshness один раз. Но без автоматизации через месяц всё опять устареет. Dependabot/Renovate создают PR автоматически при выходе новых версий.

- [ ] **Dependabot or Renovate configured** — `.github/dependabot.yml` или `renovate.json`
- [ ] **Covers the right ecosystem** — pip/npm/cargo/docker/github-actions
- [ ] **Schedule reasonable** — не daily (слишком шумно), weekly или monthly

### Команды проверки

```bash
echo "=== Dependency auto-update ==="

dependabot_found=false

# Dependabot:
if [ -f .github/dependabot.yml ] || [ -f .github/dependabot.yaml ]; then
  dependabot_found=true
  echo "  ✅ Dependabot configured"
  # Check ecosystems:
  ecosystems=$(grep -c "package-ecosystem" .github/dependabot.yml .github/dependabot.yaml 2>/dev/null | tail -1 | cut -d: -f2 | tr -d ' ')
  echo "     Ecosystems: $ecosystems"
  # Check schedule:
  schedule=$(grep "interval:" .github/dependabot.yml .github/dependabot.yaml 2>/dev/null | head -1 | sed 's/.*interval:[[:space:]]*//')
  echo "     Schedule: $schedule"
fi

# Renovate:
if [ -f renovate.json ] || [ -f renovate.json5 ] || [ -f .renovaterc ] || [ -f .renovaterc.json ]; then
  dependabot_found=true
  echo "  ✅ Renovate configured"
fi
if [ -f package.json ] && grep -q '"renovate"' package.json 2>/dev/null; then
  dependabot_found=true
  echo "  ✅ Renovate in package.json"
fi

if [ "$dependabot_found" = false ]; then
  # Check if on GitHub:
  if git remote -v 2>/dev/null | grep -q "github.com"; then
    echo "  ⚠️ No dependency auto-update — зависимости устареют незаметно"
    echo "     → Создай .github/dependabot.yml (бесплатно на GitHub)"
    echo ""
    echo "     Минимальный конфиг:"

    # Suggest ecosystems based on project:
    if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
      echo "     - package-ecosystem: pip"
    fi
    if [ -f package.json ]; then
      echo "     - package-ecosystem: npm"
    fi
    if [ -f Cargo.toml ]; then
      echo "     - package-ecosystem: cargo"
    fi
    if [ -f go.mod ]; then
      echo "     - package-ecosystem: gomod"
    fi
    if [ -d .github/workflows ]; then
      echo "     - package-ecosystem: github-actions"
    fi
  else
    echo "  🔵 Not on GitHub — Dependabot не доступен, используй Renovate"
  fi
fi
```

### Сравнение Dependabot и Renovate

| | Dependabot | Renovate |
|---|-----------|----------|
| Цена | Бесплатно (GitHub only) | Бесплатно (любой Git) |
| Настройка | Минимальная | Гибкая (automerge, grouping) |
| Качество PR | Базовое | Лучше (changelogs, grouping) |
| Ecosystems | 15+ | 50+ |
| Self-hosted | Нет | Да |

**Для начинающих**: Dependabot — создал файл, готово.
**Для зрелых проектов**: Renovate — automerge для patch, grouping для minor.

### Шаблон минимального dependabot.yml

```yaml
version: 2
updates:
  - package-ecosystem: "pip"     # или npm, cargo, gomod
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
```

> https://docs.github.com/en/code-security/dependabot

---

## 5f. Hook installer — `make hooks` для онбординга

Git hooks живут в `.git/hooks/` — они НЕ коммитятся. Новый разработчик клонирует → хуки не работают. Решение: committable скрипты в `scripts/` + installer + `make hooks`.

- [ ] **Hook scripts in repo** — `scripts/pre-commit.sh`, `scripts/pre-push.sh` в version control
- [ ] **Install script exists** — `scripts/install-hooks.sh` создаёт symlinks
- [ ] **Makefile target** — `make hooks` для одной команды

### Команды проверки

```bash
echo "=== Hook installer ==="

# Check for committable hook scripts:
hook_scripts=0
for f in scripts/pre-commit.sh scripts/pre-commit scripts/pre-push.sh scripts/pre-push hooks/pre-commit.sh hooks/pre-push.sh; do
  if [ -f "$f" ]; then
    hook_scripts=$((hook_scripts + 1))
    echo "  ✅ $f (committable)"
  fi
done

if [ "$hook_scripts" -eq 0 ]; then
  # Check if hooks exist but only in .git/hooks/
  git_hooks=0
  [ -f .git/hooks/pre-commit ] && [ ! -L .git/hooks/pre-commit ] && git_hooks=$((git_hooks + 1))
  [ -f .git/hooks/pre-push ] && [ ! -L .git/hooks/pre-push ] && git_hooks=$((git_hooks + 1))
  if [ "$git_hooks" -gt 0 ]; then
    echo "  🟠 $git_hooks hooks in .git/hooks/ but NOT in scripts/ — не коммитятся!"
    echo "     → Перемести в scripts/ и создай symlinks"
  else
    echo "  ⚠️ No committable hook scripts"
  fi
fi

# Check for install script:
install_found=false
for f in scripts/install-hooks.sh scripts/setup-hooks.sh scripts/install-hooks; do
  if [ -f "$f" ]; then
    install_found=true
    echo "  ✅ $f"
    break
  fi
done
if [ "$install_found" = false ]; then
  echo "  ⚠️ No install-hooks script"
fi

# Check for Makefile target:
if [ -f Makefile ]; then
  if grep -qE '^hooks:' Makefile 2>/dev/null; then
    echo "  ✅ make hooks target"
  else
    echo "  ⚠️ No 'make hooks' target — новый разработчик не найдёт установку"
  fi
fi

# Check symlinks (best practice):
for hook in pre-commit pre-push; do
  if [ -L ".git/hooks/$hook" ]; then
    target=$(readlink ".git/hooks/$hook")
    echo "  ✅ .git/hooks/$hook → $target (symlink)"
  elif [ -f ".git/hooks/$hook" ]; then
    echo "  ⚠️ .git/hooks/$hook — копия, не symlink (обновления scripts/ не применятся)"
  fi
done
```

### Правильная структура

```
scripts/
├── pre-commit.sh     # committable, in git
├── pre-push.sh       # committable, in git
└── install-hooks.sh  # creates symlinks
```

**install-hooks.sh:**
```bash
#!/bin/bash
HOOKS_DIR="$(git rev-parse --show-toplevel)/.git/hooks"
SCRIPTS_DIR="$(git rev-parse --show-toplevel)/scripts"
ln -sf "$SCRIPTS_DIR/pre-commit.sh" "$HOOKS_DIR/pre-commit"
ln -sf "$SCRIPTS_DIR/pre-push.sh" "$HOOKS_DIR/pre-push"
echo "✅ Hooks installed (symlinks)"
```

**Makefile:**
```makefile
hooks: ## Install git hooks (symlinks to scripts/)
	bash scripts/install-hooks.sh
```

Symlinks лучше копий: обновил `scripts/pre-commit.sh` → хук автоматически обновился.

---

## 5g. Skill optimization — `disable-model-invocation`

Скиллы типа `/test` и `/status` только запускают shell-команды — им не нужен LLM. С `disable-model-invocation: true` они работают быстрее и не тратят токены.

- [ ] **Command-runner skills optimized** — `/test`, `/status`, `/deploy` имеют `disable-model-invocation: true`
- [ ] **Only for pure-shell skills** — скиллы с анализом (doctor, memory) НЕ должны иметь этот флаг

### Команды проверки

```bash
echo "=== Skill optimization ==="
skills_dir=".claude/skills"

if [ ! -d "$skills_dir" ]; then
  echo "  🔵 No skills — пропускаем"
else
  optimized=0
  unoptimized=0

  for d in "$skills_dir"/*/; do
    [ ! -d "$d" ] && continue
    skill_file="$d/SKILL.md"
    [ ! -f "$skill_file" ] && continue

    name=$(grep -m1 '^name:' "$skill_file" | sed 's/name:[[:space:]]*//')
    has_disable=$(grep -c 'disable-model-invocation.*true' "$skill_file" 2>/dev/null)

    # Is this a command-runner skill? (check if it mostly runs bash)
    bash_lines=$(grep -cE '(bash|python|pytest|make |npm |git )' "$skill_file" 2>/dev/null || echo 0)
    analysis_lines=$(grep -cE '(анализ|analyze|diagnos|review|think|plan)' "$skill_file" 2>/dev/null || echo 0)

    if [ "$has_disable" -gt 0 ]; then
      optimized=$((optimized + 1))
      echo "  ✅ /$name — disable-model-invocation: true (экономия токенов)"
    elif [ "$bash_lines" -gt 3 ] && [ "$analysis_lines" -lt 2 ]; then
      unoptimized=$((unoptimized + 1))
      echo "  🟡 /$name — command-runner, но без disable-model-invocation"
      echo "     → Добавь 'disable-model-invocation: true' в frontmatter"
    else
      echo "  🔵 /$name — требует LLM (ОК без оптимизации)"
    fi
  done

  echo "  📊 Optimized: $optimized, Could optimize: $unoptimized"
fi
```

### Когда использовать disable-model-invocation

| Skill | disable-model-invocation? | Почему |
|-------|--------------------------|--------|
| `/test` | ✅ true | Только `pytest` — LLM не нужен |
| `/status` | ✅ true | Только `git status` + `env` checks |
| `/deploy` | ✅ true | Pre-flight checks + push |
| `/doctor` | ❌ false | Анализирует результаты, пишет отчёт |
| `/memory` | ❌ false | Обрабатывает текст, делает выводы |
| `/checkpoint` | ✅ true | Только `git stash/commit/tag` |

**Экономия**: ~30% токенов на каждый вызов command-runner скилла.

> https://docs.anthropic.com/en/docs/claude-code/skills
