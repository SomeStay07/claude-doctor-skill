# Слой 2 (продолжение): Продвинутые проверки качества

Основные проверки (2a–2f): [QUALITY.md](QUALITY.md)
Содержит: 2g branch protection, 2h type checking, 2i coverage, 2j print/logging, 2k PreToolUse

---

## 2g. Branch protection — PR workflow (~10 мин) [advanced]

Прямой push в main — рецепт катастрофы. **Branch protection** — мерж только через PR.

- [ ] **Ветка защищена + PR обязателен** — прямой push в main запрещён, мерж только через PR
- [ ] **Status checks + именование** — CI перед мержем, ветки по конвенции (`feature/`, `fix/`, `chore/`)

### Команды проверки

```bash
echo "=== Branch protection ==="
branch=$(git branch --show-current 2>/dev/null)
echo "  Current branch: $branch"

branch_count=$(git branch -a 2>/dev/null | wc -l | tr -d ' ')
if [ "$branch_count" -le 1 ]; then
  echo "  ⚠️ Only 1 branch — всё коммитится прямо в main"
else
  echo "  ✅ $branch_count branches exist"
  good_names=$(git branch -a 2>/dev/null | grep -cE 'feature/|fix/|chore/|hotfix/|release/' || echo 0)
  [ "$good_names" -gt 0 ] && echo "  ✅ Branch naming convention ($good_names named branches)"
fi

# GitHub branch protection (requires gh CLI):
if command -v gh &>/dev/null; then
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  : "${default_branch:=main}"
  if protection=$(gh api "repos/{owner}/{repo}/branches/$default_branch/protection" 2>/dev/null); then
    echo "  ✅ Branch protection enabled on $default_branch"
    echo "$protection" | python3 -c "
import json,sys;d=json.load(sys.stdin)
print('     PR reviews: ✅' if d.get('required_pull_request_reviews') else '     PR reviews: ⚠️ not required')
print('     Status checks: ✅' if d.get('required_status_checks') else '     Status checks: ⚠️ not required')
" 2>/dev/null
  else
    echo "  ⚠️ No branch protection on $default_branch"
    echo "     → GitHub: Settings → Branches → Add rule"
  fi
else
  echo "  🔵 gh CLI not available — check branch protection manually"
fi
```

### Workflow по уровню зрелости

| Уровень | Workflow | Для кого |
|---------|---------|----------|
| **Начинающий** | main + pre-push hook | Соло, учебные проекты |
| **Средний** | main + feature branches + PR | Соло с production |
| **Продвинутый** | main + develop + feature + PR + CI checks | Команда, open-source |

**Минимум для вайбкодера**: `git checkout -b feature/x` → работай → `gh pr create --fill` → review diff → `gh pr merge`.

> https://quesma.com/blog/vibe-code-git-blame/

---

## 2h. Проверка типов — ловим баги до запуска (~10 мин) [quality]
<!-- glossary: type checking = инструмент проверки типов данных — ловит ошибки до запуска программы -->

AI-код часто untyped — нет аннотаций типов, нет проверки. Результат: 2.27x больше null reference ошибок, неправильные аргументы функций, невозможность рефакторить.

- [ ] **Type checker настроен** — mypy / pyright (Python) / tsc --strict (TypeScript)
- [ ] **Запускается в CI или pre-commit** — не ручной запуск
- [ ] **Конфиг существует** — `mypy.ini` / `pyrightconfig.json` / `tsconfig.json` с strict

### Команды проверки

```bash
echo "=== Type checking ==="
# Python?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  mypy_found=false; pyright_found=false
  { command -v mypy &>/dev/null || [ -f .venv/bin/mypy ]; } && { mypy_found=true; echo "  ✅ mypy installed"; }
  { command -v pyright &>/dev/null || [ -f .venv/bin/pyright ]; } && { pyright_found=true; echo "  ✅ pyright installed"; }
  [ "$mypy_found" = false ] && [ "$pyright_found" = false ] && echo "  ⚠️ No type checker — pip install mypy (AI-код без типов: 2.27x больше null ref ошибок)"

  # Config?
  if [ -f mypy.ini ] || [ -f .mypy.ini ]; then echo "  ✅ mypy config"
  elif [ -f pyproject.toml ] && grep -q '\[tool.mypy\]' pyproject.toml 2>/dev/null; then echo "  ✅ mypy config in pyproject.toml"
  elif [ -f pyrightconfig.json ]; then echo "  ✅ pyright config"
  elif [ "$mypy_found" = true ] || [ "$pyright_found" = true ]; then echo "  ⚠️ No config — using loose defaults"
  fi

  # Type annotations:
  src_dirs=""
  for d in src app lib bot server backend api core pkg cmd internal services packages; do [ -d "$d" ] && src_dirs="${src_dirs:+$src_dirs }$d"; done
  if [ -n "$src_dirs" ]; then
    total=$(grep -rn "def " --include="*.py" $src_dirs 2>/dev/null | wc -l | tr -d ' ')
    typed=$(grep -rn "def .*->.*:" --include="*.py" $src_dirs 2>/dev/null | wc -l | tr -d ' ')
    [ "$total" -gt 0 ] && { pct=$((typed*100/total)); echo "  📊 Annotations: $typed/$total ($pct%)"; [ "$pct" -lt 30 ] && echo "     ⚠️ Мало аннотаций"; }
  fi
fi
# TypeScript?
if [ -f tsconfig.json ]; then
  echo "  ✅ tsconfig.json"
  grep -q '"strict"[[:space:]]*:[[:space:]]*true' tsconfig.json 2>/dev/null && echo "  ✅ strict mode" || echo "  ⚠️ strict mode NOT enabled"
  ts_dirs=""
  for d in src app lib; do [ -d "$d" ] && ts_dirs="${ts_dirs:+$ts_dirs }$d"; done
  if [ -n "$ts_dirs" ]; then
    any_count=$(grep -rn ": any" --include="*.ts" --include="*.tsx" $ts_dirs 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
    [ "$any_count" -gt 10 ] && echo "  ⚠️ $any_count ': any' uses — типизация обходится"
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

## 2i. Покрытие кода тестами — тесты реально покрывают код (~10 мин) [quality]
<!-- glossary: code coverage = процент кода, покрытого тестами — показывает какой код не тестируется -->

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
  find .github/workflows -name '*.yml' -o -name '*.yaml' 2>/dev/null | while read -r f; do
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

## 2j. Нет print() / console.log в production (~5 мин) [core]

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
  for d in src app lib bot server backend api core pkg cmd internal services packages; do
    [ -d "$d" ] && src_dirs="${src_dirs:+$src_dirs }$d"
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
  for d in src app lib bot server backend api core pkg cmd internal services packages; do
    [ -d "$d" ] && src_dirs="${src_dirs:+$src_dirs }$d"
  done
  if [ -n "$src_dirs" ]; then
    console_count=$(grep -rnE "console\.(log|info|warn|error)" --include="*.ts" --include="*.js" $src_dirs 2>/dev/null | grep -v "test" | grep -v "spec" | wc -l | tr -d ' ')
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

## 2k. PreToolUse hooks — предотвращение ошибок ДО записи (~10 мин) [cc]
<!-- glossary: PreToolUse hook = скрипт, запускающийся ПЕРЕД действием Claude — может заблокировать опасные команды -->

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

**1. Напоминания** (matcher: `Edit|Write`) — `exit 0`, только советуют:
```bash
#!/bin/bash
[[ "$CLAUDE_FILE_PATH" =~ bot/.*\.py$ ]] && echo "Reminders: no sync I/O, no bare except, logging not print()"
exit 0
```

**2. Блокировщики** (matcher: `Bash`) — `exit 2`, реально блокируют:
```bash
#!/bin/bash
echo "$CLAUDE_BASH_COMMAND" | grep -qiE '(gh\s+pr\s+merge|git\s+merge\s+(main|master)|rm\s+-rf)' \
  && { echo "BLOCKED: requires explicit permission"; exit 2; }
exit 0
```

**Exit codes**: `exit 0` = разрешить (с advisory output), `exit 2` = заблокировать.

> https://docs.anthropic.com/en/docs/claude-code/hooks

---

## Связь между уровнями защиты

```
Уровень              Что ловит                    Скорость     Обход           Блокирует?
────────────────────────────────────────────────────────────────────────────────────────
PostToolUse          Syntax + format               ~100ms       Нельзя          Нет (feedback)
Pre-commit           Lint + secrets + debug         ~3 sec       --no-verify     Да (commit)
Pre-push             Tests + lint                   ~30 sec      --no-verify     Да (push)
Branch protection    PR review + CI checks          ~3 min       Admin bypass    Да (merge)
CI (опционально)     Full test suite + lint         ~3 min       Force push      Да (PR)
```

**PostToolUse — самый ценный**: работает при КАЖДОМ Edit/Write, ловит мгновенно. Не блокирует запись, но Claude видит ошибку через stderr и исправляет.

**Pre-commit — второй барьер**: ловит lint, секреты, debug prints. Реально блокирует commit. Обходится `--no-verify`.

**CI — страховка**: для команд и open-source. Единственная защита от `--no-verify`.

### Ограничения pre-commit

- `--no-verify` обходит ВСЕ хуки — единственная защита: CI
- Secrets scan через grep имеет false negatives — для серьёзной защиты: gitleaks
- Хуки в `.git/hooks/` не коммитятся — нужен symlink на `scripts/pre-commit.sh`

---

> Production-мониторинг (2l error monitoring) → [QUALITY-PROD.md](QUALITY-PROD.md)
