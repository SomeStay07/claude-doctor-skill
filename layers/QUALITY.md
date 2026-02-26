# Слой 2: Ворота качества — "Код не сломается"

Без автоматических проверок ошибки попадают в git, а потом в production. С Quality Gates — каждое изменение проверяется автоматически на 3 уровнях.

```
Claude пишет → PostToolUse ловит     (мгновенно, при каждом Edit/Write)
git commit   → pre-commit ловит      (секунды, перед коммитом)
GitHub PR    → CI ловит              (минуты, опционально)
```

---

## 2a. Linter + Formatter — инструменты настроены (~5 мин) [core]

- [ ] **Linter установлен** — ruff / eslint / clippy есть в зависимостях
- [ ] **Конфиг linter-а существует** — `ruff.toml` / `pyproject.toml [tool.ruff]` / `.eslintrc` / `clippy.toml`
- [ ] **Formatter интегрирован** — ruff format / prettier / rustfmt в build scripts

### Команды проверки

```bash
# Detect linter by stack:
echo "=== Linter ==="
# Python?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if command -v ruff &>/dev/null || [ -f .venv/bin/ruff ]; then
    echo "  ✅ ruff installed"
  else
    echo "  ❌ No linter found (рекомендуется: pip install ruff)"
  fi
  # Config?
  if [ -f ruff.toml ] || [ -f .ruff.toml ]; then
    echo "  ✅ ruff.toml config"
  elif [ -f pyproject.toml ] && grep -q '\[tool.ruff\]' pyproject.toml 2>/dev/null; then
    echo "  ✅ ruff config in pyproject.toml"
  else
    echo "  ⚠️ No ruff config — using defaults (ОК для начала, но не хватает project-specific правил)"
  fi
fi

# Node.js?
if [ -f package.json ]; then
  if [ -f .eslintrc ] || [ -f .eslintrc.js ] || [ -f .eslintrc.json ] || [ -f eslint.config.js ] || [ -f eslint.config.mjs ] || [ -f eslint.config.cjs ]; then
    echo "  ✅ eslint config"
  elif grep -q '"eslint"' package.json 2>/dev/null; then
    echo "  ⚠️ eslint в зависимостях, но нет конфига"
  fi
fi

# Check formatter in build scripts:
echo "=== Formatter ==="
if [ -f Makefile ]; then
  grep -qE '^format:' Makefile && echo "  ✅ make format target" || echo "  ⚠️ No 'make format' target"
fi
if [ -f package.json ]; then
  grep -q '"format"' package.json && echo "  ✅ npm run format script" || echo "  ⚠️ No format script in package.json"
fi
```

### Зачем конфиг, если ruff работает и без него?

Ruff defaults работают для 90% случаев. Конфиг нужен когда:
- Нужно **исключить** папки (generated code, migrations)
- Нужно **включить** дополнительные правила (security, type checking)
- Нужно **настроить** line-length, import sorting, target Python version

Без конфига — ОК для начала. С конфигом — лучше для зрелых проектов.

### Linter по стеку

| Стек | Linter | Formatter | Конфиг |
|------|--------|-----------|--------|
| Python | ruff check | ruff format | `ruff.toml` / `pyproject.toml` |
| Node.js | eslint | prettier | `eslint.config.mjs` (v9+ flat config, рекомендуется) / `.eslintrc` (v8, legacy) + `.prettierrc` |
| Rust | cargo clippy | cargo fmt | `clippy.toml` |
| Go | golangci-lint | gofmt | `.golangci.yml` |

> https://docs.astral.sh/ruff/integrations/

---

## 2b. PostToolUse hook — автопроверка Claude (~10 мин) [cc]
<!-- glossary: PostToolUse hook = скрипт, запускающийся автоматически после каждого действия Claude (Edit, Write) -->

- [ ] **Hook существует** — `PostToolUse` для `Edit|Write` в `.claude/settings.json`
- [ ] **Format + syntax** — hook делает format + syntax check (не только одно)
- [ ] **Обратная связь при ошибке** — exit code 2 при syntax error, Claude получает stderr и исправляет
- [ ] **Скрипт исполняемый** — `chmod +x` если используется внешний скрипт

### Команды проверки

```bash
echo "=== PostToolUse hook ==="
# Check in project settings:
for settings_file in ".claude/settings.json" ".claude/settings.local.json"; do
  if [ -f "$settings_file" ]; then
    if grep -q "PostToolUse" "$settings_file" 2>/dev/null; then
      echo "  ✅ PostToolUse hook in $settings_file"
      # Check what it does (in settings AND referenced scripts):
      if grep -q "Edit\|Write" "$settings_file" 2>/dev/null; then
        echo "     matcher: Edit|Write ✅"
      fi
      # Check settings + hook scripts for format & syntax:
      if grep -ql "format" "$settings_file" .claude/hooks/*.sh 2>/dev/null; then
        echo "     format: ✅"
      else
        echo "     format: ⚠️ no formatting in hook"
      fi
      if grep -ql "py_compile\|tsc\|--check" "$settings_file" .claude/hooks/*.sh 2>/dev/null; then
        echo "     syntax check: ✅"
      else
        echo "     syntax check: ⚠️ no syntax validation"
      fi
    else
      echo "  ⚠️ No PostToolUse hook in $settings_file"
    fi
  fi
done

# Check hook script is executable:
for hook_script in .claude/hooks/*.sh; do
  if [ -f "$hook_script" ]; then
    if [ -x "$hook_script" ]; then
      echo "  ✅ $hook_script (executable)"
    else
      echo "  ❌ $hook_script (NOT executable — chmod +x needed)"
    fi
  fi
done
```

### Правильный PostToolUse hook

Хороший hook делает **2 вещи**:
1. **Syntax check** — exit 2 если сломан (Claude видит ошибку в stderr и исправляет)
2. **Format** — автоматически форматирует (не ломает, только чистит)

**Порядок важен**: syntax FIRST, format SECOND. py_compile даёт **более понятную** ошибку чем ruff format (который тоже упадёт на syntax error, но с менее читаемым сообщением).

```bash
# ✅ Правильно: syntax → format
py_compile "$FILE" || exit 2    # Feedback on syntax error
ruff format "$FILE"              # Format only valid code

# ❌ Неправильно: только format
ruff format "$FILE"              # Сообщение об ошибке менее информативное
```

**Exit codes** (PostToolUse):
- `exit 0` — всё ОК, Claude продолжает
- `exit 2` — Claude видит stderr как feedback и исправляет в следующем действии
- Другие exit codes — предупреждение, но не feedback

**ВАЖНО**: PostToolUse выполняется ПОСЛЕ записи файла — edit/write уже применён. Exit code 2 **не отменяет** запись, а показывает Claude ошибку для исправления. Это отличается от PreToolUse, где exit 2 реально блокирует операцию.

> https://docs.anthropic.com/en/docs/claude-code/hooks

---

## 2c. Pre-commit hook — барьер перед git (~10 мин) [core]
<!-- glossary: pre-commit hook = скрипт, проверяющий код перед каждым git commit -->

- [ ] **Hook установлен** — `.git/hooks/pre-commit` существует и исполняемый
- [ ] **Проверяет только staged файлы** — `git diff --cached`, не весь проект
- [ ] **Обязательные проверки** — syntax + lint + secrets scan
- [ ] **Можно обойти** — `--no-verify` для аварийных коммитов
- [ ] **Скрипт в репозитории** — `scripts/pre-commit.sh` (коммитится, не только в .git/hooks/)

### Команды проверки

```bash
echo "=== Pre-commit hook ==="
if [ -f .git/hooks/pre-commit ]; then
  echo "  ✅ .git/hooks/pre-commit exists"
  # Check if executable:
  if [ -x .git/hooks/pre-commit ]; then
    echo "     executable: ✅"
  else
    echo "     executable: ❌ (chmod +x needed)"
  fi
  # Check if symlink to repo script:
  if [ -L .git/hooks/pre-commit ]; then
    target=$(readlink .git/hooks/pre-commit)
    echo "     symlink → $target ✅ (committable)"
  else
    echo "     ⚠️ Not a symlink — hook lives only in .git/ (not committable)"
  fi
  # Check what it does:
  hook_file=$(readlink -f .git/hooks/pre-commit 2>/dev/null || echo .git/hooks/pre-commit)
  if [ -f "$hook_file" ]; then
    grep -q "py_compile\|tsc\|syntax" "$hook_file" 2>/dev/null && echo "     syntax check: ✅" || echo "     syntax check: ⚠️ missing"
    grep -q "ruff\|eslint\|clippy\|lint" "$hook_file" 2>/dev/null && echo "     lint: ✅" || echo "     lint: ⚠️ missing"
    grep -q "secret\|password\|token\|gitleaks" "$hook_file" 2>/dev/null && echo "     secrets scan: ✅" || echo "     secrets scan: ⚠️ missing"
    grep -q "git diff --cached" "$hook_file" 2>/dev/null && echo "     staged only: ✅" || echo "     staged only: ⚠️ checks all files (slow)"
  fi
else
  # Check for .pre-commit-config.yaml (pre-commit framework):
  if [ -f .pre-commit-config.yaml ]; then
    echo "  ✅ .pre-commit-config.yaml (pre-commit framework)"
    echo "     Run: pre-commit install (if hooks not installed)"
  else
    echo "  ❌ No pre-commit hook"
  fi
fi

# Check for committable hook script:
echo "=== Hook script in repo ==="
for f in scripts/pre-commit.sh scripts/pre-commit hooks/pre-commit.sh; do
  if [ -f "$f" ]; then
    echo "  ✅ $f (committable)"
    break
  fi
done
```

### Что должен проверять pre-commit

**Обязательно** (быстрое, < 5 секунд):
1. **Syntax check** — py_compile / tsc / cargo check (только staged файлы)
2. **Lint** — ruff check / eslint (только staged файлы, без --fix)
3. **Secrets scan** — grep по diff на password/token/api_key

**Опционально** (полезно, но может замедлить):
4. Debug prints — grep на print() / console.log / breakpoint()
5. Format check — ruff format --check (проверить, но не исправлять)

**НЕ должен**:
- Запускать тесты (это для pre-push или CI, слишком долго)
- Проверять весь проект (только `git diff --cached`)
- Блокировать на warnings (только errors)

> https://github.com/astral-sh/ruff-pre-commit

---

## 2d. CI workflow — удалённая проверка (опционально) (~10 мин) [advanced]
<!-- glossary: CI workflow = автоматический запуск тестов и проверок при каждом push в GitHub -->

- [ ] **Workflow существует** — `.github/workflows/ci.yml` или аналог
- [ ] **Lint первым** — lint job быстро фейлит, тесты зависят от lint
- [ ] **Фиктивные env-переменные** — fake tokens для graceful degradation

### Команды проверки

```bash
echo "=== CI/CD ==="
ci_found=false
for f in $(find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null); do
  [ -f "$f" ] || continue
  ci_found=true
  echo "  ✅ $(basename "$f")"
  grep -q "needs:" "$f" 2>/dev/null && echo "     stages: ✅" || echo "     stages: ⚠️ no 'needs:' (lint should be first)"
  grep -qE 'fake|dummy|""' "$f" 2>/dev/null && echo "     dummy env: ✅"
done
[ -f .gitlab-ci.yml ] && { ci_found=true; echo "  ✅ .gitlab-ci.yml"; }
[ "$ci_found" = false ] && echo "  🔵 No CI workflow (опционально для соло-проектов)"
```

### Нужен ли CI?

| Ситуация | CI нужен? |
|----------|-----------|
| Соло-проект, local hooks настроены | 🔵 Опционально |
| Команда из 2+ человек | 🟠 Важно |
| Open-source проект | 🔴 Обязательно |
| --no-verify используется часто | 🔴 Обязательно (CI — последний барьер) |

CI дорогой (GitHub Actions minutes). Для соло-проектов **локальные хуки** (PostToolUse + pre-commit) покрывают 95% кейсов.

> https://docs.github.com/en/actions/writing-workflows

---

## 2e. Обработка ошибок — код не глотает ошибки (~5 мин) [core]

AI часто генерирует `except:` без конкретного типа или `catch(e) {}` пустой — ошибки проглатываются, баги не видны.

- [ ] **Нет голого except** — нет `except:` без типа исключения (Python)
- [ ] **Нет пустого catch** — нет `catch(e) {}` без обработки (JS/TS)
- [ ] **Правила linter-а включены** — ruff E722 / eslint no-empty-catch

### Команды проверки

```bash
echo "=== Error handling ==="

# Python — bare except:
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  src_dirs=""
  for d in bot src app lib; do [ -d "$d" ] && src_dirs="$src_dirs $d"; done
  if [ -n "$src_dirs" ]; then
    bare_all=$(grep -rn "^[[:space:]]*except:" --include="*.py" $src_dirs 2>/dev/null)
    bare_count=$(echo "$bare_all" | grep -v "^$" | wc -l | tr -d ' ')
    if [ "$bare_count" -gt 0 ]; then
      echo "  🟠 $bare_count bare 'except:' (проглатывают ВСЕ ошибки):"
      echo "$bare_all" | head -5 | sed 's/^/     /'
      echo "     → Используй 'except SpecificError:' или минимум 'except Exception:'"
    else
      echo "  ✅ No bare except statements"
    fi
    pass_count=$(grep -rn -A1 "except" --include="*.py" $src_dirs 2>/dev/null | grep -c "pass" | tr -d ' ')
    [ "$pass_count" -gt 3 ] && echo "  ⚠️ $pass_count 'except ... pass' blocks — ошибки проглатываются молча"
  fi
  # Check ruff E722:
  if [ -f ruff.toml ] || [ -f pyproject.toml ]; then
    grep -qE 'E722|"E"' ruff.toml pyproject.toml 2>/dev/null \
      && echo "  ✅ ruff E722 (bare-except) enabled" \
      || echo "  ⚠️ ruff E722 not explicitly enabled (may use defaults)"
  fi
fi

# Node.js — empty catch:
if [ -f package.json ]; then
  src_dirs=""
  for d in src app lib; do [ -d "$d" ] && src_dirs="$src_dirs $d"; done
  if [ -n "$src_dirs" ]; then
    empty_catch=$(grep -rn "catch.*{}" --include="*.ts" --include="*.js" $src_dirs 2>/dev/null | wc -l | tr -d ' ')
    [ "$empty_catch" -gt 0 ] && echo "  🟠 $empty_catch empty catch blocks (ошибки проглатываются)" || echo "  ✅ No empty catch blocks"
  fi
fi
```

### Почему это критично для вайбкодеров

AI генерирует `try/except` повсюду "для безопасности", но без конкретного типа ошибки:
- `except:` ловит даже `KeyboardInterrupt` и `SystemExit` — приложение не останавливается по Ctrl+C
- `except: pass` — ошибка происходит, но никто не видит. Баг обнаруживается через недели
- Правильно: `except ValueError as e: logger.error(f"Invalid input: {e}")`

> https://www.glideapps.com/blog/vibe-coding-risks

---

## 2f. Pre-push hook — тесты перед отправкой (~10 мин) [quality]

Pre-commit ловит синтаксис и стиль (быстро, <5 сек). Но тесты в pre-commit — это слишком медленно. Решение: **pre-push hook** — тесты запускаются перед `git push`, не перед каждым коммитом.

- [ ] **Pre-push hook существует** — `.git/hooks/pre-push` запускает тест-сьют
- [ ] **Запускает тесты** — pytest / npm test / cargo test
- [ ] **Быстрая проверка первой** — сначала lint (быстро), потом тесты (если lint прошёл)

### Команды проверки

```bash
echo "=== Pre-push hook ==="
if [ -f .git/hooks/pre-push ]; then
  echo "  ✅ .git/hooks/pre-push exists"
  if [ -x .git/hooks/pre-push ]; then
    echo "     executable: ✅"
  else
    echo "     executable: ❌ (chmod +x needed)"
  fi
  hook_file=$(readlink -f .git/hooks/pre-push 2>/dev/null || echo .git/hooks/pre-push)
  if [ -f "$hook_file" ]; then
    grep -qiE "pytest|npm test|cargo test|go test|test" "$hook_file" 2>/dev/null && echo "     tests: ✅" || echo "     tests: ⚠️ no test command found"
    grep -qiE "ruff|eslint|lint" "$hook_file" 2>/dev/null && echo "     lint gate: ✅" || echo "     lint gate: ⚠️ missing"
  fi
  # Check if symlink to repo script:
  if [ -L .git/hooks/pre-push ]; then
    echo "     symlink: ✅ (committable)"
  else
    echo "     ⚠️ Not a symlink — hook not in repo"
  fi
elif [ -f .pre-commit-config.yaml ]; then
  if grep -q "pre-push" .pre-commit-config.yaml 2>/dev/null; then
    echo "  ✅ pre-push stage in .pre-commit-config.yaml"
  else
    echo "  ⚠️ .pre-commit-config.yaml exists but no pre-push stage"
  fi
else
  echo "  ⚠️ No pre-push hook — сломанные тесты можно запушить в remote"
fi
```

### Шаблон pre-push hook

```bash
#!/bin/bash
# scripts/pre-push.sh — lint + тесты перед пушем
ruff check . --no-fix || { echo "❌ Lint failed"; exit 1; }
python -m pytest tests/ -q --tb=short || { echo "❌ Tests failed"; exit 1; }
echo "✅ All checks passed"
```

**Установка**: `ln -sf ../../scripts/pre-push.sh .git/hooks/pre-push && chmod +x scripts/pre-push.sh`

---

> Продвинутые проверки (2g branch protection, 2h type checking, 2i coverage, 2j print/logging, 2k PreToolUse) + обзор уровней защиты → [QUALITY-EXTRA.md](QUALITY-EXTRA.md)
