# Слой 5: DX — продвинутые проверки

Автообновление зависимостей, установщик хуков, оптимизация скиллов.
Базовые проверки (5a-5d): [DX.md](DX.md)

---

## 5e. Автообновление зависимостей — Dependabot / Renovate (~10 мин) [cc]
<!-- glossary: Dependabot = GitHub-бот, автоматически обновляющий устаревшие зависимости -->

Layer 1e проверяет freshness один раз. Но без автоматизации через месяц всё опять устареет. Dependabot/Renovate создают PR автоматически при выходе новых версий.

- [ ] **Dependabot или Renovate настроен** — `.github/dependabot.yml` или `renovate.json`
- [ ] **Покрывает нужные экосистемы** — pip/npm/cargo/docker/github-actions
- [ ] **Разумное расписание** — не daily (слишком шумно), weekly или monthly

### Команды проверки

```bash
echo "=== Dependency auto-update ==="

dependabot_found=false

# Dependabot:
if [ -f .github/dependabot.yml ] || [ -f .github/dependabot.yaml ]; then
  dependabot_found=true
  echo "  ✅ Dependabot configured"
  # Check ecosystems:
  ecosystems=$(cat .github/dependabot.yml .github/dependabot.yaml 2>/dev/null | grep -c "package-ecosystem" | tr -d ' ')
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

## 5f. Установщик хуков — `make hooks` для онбординга (~10 мин) [core]

Git hooks живут в `.git/hooks/` — они НЕ коммитятся. Новый разработчик клонирует → хуки не работают. Решение: committable скрипты в `scripts/` + installer + `make hooks`.

- [ ] **Скрипты хуков в репо** — `scripts/pre-commit.sh`, `scripts/pre-push.sh` в version control
- [ ] **Установочный скрипт** — `scripts/install-hooks.sh` создаёт symlinks
- [ ] **Цель в Makefile** — `make hooks` для одной команды

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

> https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks

---

## 5g. Оптимизация скиллов — `disable-model-invocation` (~10 мин) [quality]
<!-- glossary: disable-model-invocation = настройка, запрещающая скиллу вызывать AI — экономит время и деньги -->

Скиллы типа `/test` и `/status` только запускают shell-команды — им не нужен LLM. С `disable-model-invocation: true` они работают быстрее и не тратят токены.

- [ ] **Command-runner скиллы оптимизированы** — `/test`, `/status`, `/deploy` имеют `disable-model-invocation: true`
- [ ] **Только для shell-скиллов** — скиллы с анализом (doctor, memory) НЕ должны иметь этот флаг

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
    bash_lines=$(grep -cE '(bash|python|pytest|make |npm |git |cargo |go |docker )' "$skill_file" 2>/dev/null); bash_lines=${bash_lines:-0}
    analysis_lines=$(grep -cE '(анализ|analyze|diagnos|review|think|plan|summarize|explain|refactor|decision|recommend)' "$skill_file" 2>/dev/null); analysis_lines=${analysis_lines:-0}
    total_lines=$(wc -l < "$skill_file" 2>/dev/null | tr -d ' '); total_lines=${total_lines:-0}

    if [ "$has_disable" -gt 0 ]; then
      optimized=$((optimized + 1))
      echo "  ✅ /$name — disable-model-invocation: true (экономия токенов)"
    elif [ "$bash_lines" -gt 5 ] && [ "$analysis_lines" -lt 3 ] && [ "$total_lines" -lt 80 ]; then
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
