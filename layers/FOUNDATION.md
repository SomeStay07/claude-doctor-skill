# Слой 1: Фундамент — "Можно работать"

Слой 0 = не навредить. Слой 1 = Claude и разработчик могут продуктивно работать с проектом.

> `.gitignore` и `.env.example` проверяются в **Слой 0 (Безопасность)** — см. [SECURITY.md](./SECURITY.md)

---

## 1a. CLAUDE.md — инструкции для Claude (~15 мин) [core]
<!-- glossary: CLAUDE.md = файл с инструкциями для Claude Code — описание проекта, команды, правила -->

- [ ] **Существует** — `CLAUDE.md` в корне проекта
- [ ] **Адекватный размер** — до 300 строк (идеал: 60-150). Больше 300 = инструкции теряются в шуме
- [ ] **Есть ключевые разделы** — Quick Start, Architecture, Critical Rules, Known Issues
- [ ] **Команды готовы к копированию** — блоки кода с реальными командами, а не описания
- [ ] **Нет антипаттернов** — нет правил стиля кода (это работа линтера), нет общих знаний, которые Claude и так знает
- [ ] **Команды работают** — команды из Quick Start запускаются без ошибок

### Команды проверки

```bash
# Проверить наличие и размер:
[[ -f CLAUDE.md ]] && echo "✅ EXISTS: $(wc -l < CLAUDE.md) lines" || echo "❌ MISSING"

# Проверить ключевые разделы (без учёта регистра):
for section in "quick start|getting started" "architecture|structure" "critical|rules|must follow" "known issues|troubleshoot"; do
  label=$(echo "$section" | sed 's/|/ \/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
  grep -qiE "$section" CLAUDE.md 2>/dev/null && echo "✅ Has: $label" || echo "⚠️ Missing section: $label"
done

# Проверить наличие блоков кода (готовых к копированию):
code_blocks=$(grep -c '```' CLAUDE.md 2>/dev/null); code_blocks=${code_blocks:-0}
echo "Code blocks: $((code_blocks / 2))"

# Антипаттерн: слишком много строк = раздутый файл
lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
if [[ $lines -gt 500 ]]; then
  echo "🔴 BLOATED: $lines lines — split into sub-files or CLAUDE.md per directory"
elif [[ $lines -gt 300 ]]; then
  echo "🟠 LONG: $lines lines — consider trimming non-essential content"
elif [[ $lines -gt 0 ]]; then
  echo "✅ SIZE OK: $lines lines"
fi
```

### Как выглядит хороший CLAUDE.md

**Обязательно:**
- Команды для быстрого старта (готовые к копированию, рабочие)
- Обзор архитектуры (дерево каталогов + обязанности модулей)
- Критические правила, которым Claude обязан следовать (нумерованные, императивные)
- Таблица известных проблем (Проблема | Причина | Решение)
- Команды тестирования с ожидаемыми результатами

**Запрещено:**
- Правила стиля кода — используй конфиг линтера (ruff.toml, .eslintrc)
- Общие знания, которые Claude и так знает (как работают импорты в Python и т.д.)
- Инструкции для конкретных задач — выноси в отдельные файлы, ссылайся из CLAUDE.md
- Полные куски кода — используй ссылки `file:line`

**Прогрессивное раскрытие** — CLAUDE.md загружается всегда, поэтому держи его компактным:
- Корневой `CLAUDE.md` = универсальные правила (< 300 строк)
- `bot/CLAUDE.md` = контекст конкретного модуля (опционально)
- `.claude/agents/*.md` = инструкции для конкретных агентов
- `.claude/rules/*.md` = правила по паттернам файлов

> https://www.humanlayer.dev/blog/writing-a-good-claude-md
> https://claude.com/blog/using-claude-md-files

---

## 1b. Файл зависимостей — стек зафиксирован (~2 мин) [core]

- [ ] **Существует** — манифест для стека проекта (см. таблицу ниже)
- [ ] **Не пустой** — содержит реальные зависимости (не пустой файл)
- [ ] **Устанавливается** — `pip install -r requirements.txt` / `npm install` работает без ошибок

### Команды проверки

```bash
echo "=== Dependency manifest ==="
manifest_found=false

# --- Простые файлы (проверка наличия) ---
for entry in \
  "requirements.txt|Python" "pyproject.toml|Python" "setup.py|Python" "setup.cfg|Python" "package.json|Node.js" "Cargo.toml|Rust" \
  "go.mod|Go" "Package.swift|Swift" "Podfile|CocoaPods" "Gemfile|Ruby" "pom.xml|Java/Kotlin" "build.gradle|Java/Kotlin" \
  "build.gradle.kts|Java/Kotlin" "composer.json|PHP" "mix.exs|Elixir" "pubspec.yaml|Dart/Flutter" "CMakeLists.txt|C/C++" \
  "meson.build|C/C++" "conanfile.txt|C/C++" "conanfile.py|C/C++" "build.sbt|Scala" "stack.yaml|Haskell" "build.zig|Zig" \
  "project.clj|Clojure" "deps.edn|Clojure" "Makefile.PL|Perl" "cpanfile|Perl"; do
  file="${entry%%|*}"; label="${entry#*|}"
  if [ -f "$file" ]; then
    manifest_found=true
    if [ "$file" = "package.json" ]; then
      dep_count=$(node -p "try{const p=require('./package.json');Object.keys(p.dependencies||{}).length+Object.keys(p.devDependencies||{}).length}catch(e){0}" 2>/dev/null || echo "?")
      echo "  ✅ $file ($dep_count dependencies)"
    else
      deps=$(grep -cvE '^\s*$|^\s*#' "$file" 2>/dev/null); deps=${deps:-0}
      echo "  ✅ $file ($deps non-empty lines)"
    fi
  fi
done

# --- Глубокий поиск (find) ---
for entry in "*.xcodeproj|d|2|Xcode project" "*.csproj|f|3|.NET project" "*.sln|f|2|.NET solution" "*.cabal|f|2|Haskell/Cabal"; do
  pat="${entry%%|*}"; rest="${entry#*|}"; ftype="${rest%%|*}"; rest="${rest#*|}"
  depth="${rest%%|*}"; label="${rest#*|}"
  match=$(find . -maxdepth "$depth" -name "$pat" -type "$ftype" 2>/dev/null | head -1)
  if [ -n "$match" ]; then
    manifest_found=true
    echo "  ✅ $match ($label)"
  fi
done

# --- R (особая проверка) ---
if [ -f DESCRIPTION ]; then
  grep -q "Package:" DESCRIPTION 2>/dev/null && { manifest_found=true; echo "  ✅ DESCRIPTION (R package)"; }
fi

if [ "$manifest_found" = false ]; then
  src_dirs=""
  for d in src app lib bot server backend api core pkg cmd internal services packages Sources; do
    [ -d "$d" ] && src_dirs="${src_dirs:+$src_dirs }$d"
  done
  if [ -n "$src_dirs" ]; then
    echo "  🔴 Source code exists ($src_dirs) but NO dependency manifest!"
    echo "     → Другой разработчик (и Claude) не знает какие пакеты нужны"
    # Подсказка на основе обнаруженного языка:
    for entry in \
      "*.py|pip freeze > requirements.txt" "*.js *.ts|npm init -y" "*.swift|swift package init" \
      "*.go|go mod init <module>" "*.rs|cargo init" "*.rb|bundle init" \
      "*.java *.kt|pom.xml или build.gradle" "*.c *.cpp *.cc *.h|cmake_minimum_required(...) в CMakeLists.txt" \
      "*.cs|dotnet new console" "*.scala|build.sbt" "*.hs|cabal init или stack init" "*.zig|zig init" \
      "*.clj *.cljs|deps.edn или lein new" "*.pl *.pm|cpanfile" "*.R *.r|usethis::create_package()" \
      "*.php|composer init" "*.ex *.exs|mix new <project>" "*.dart|dart create или flutter create"; do
      globs="${entry%%|*}"; hint="${entry#*|}"
      count=0
      for g in $globs; do
        c=$(find $src_dirs -name "$g" 2>/dev/null | wc -l | tr -d ' ')
        count=$((count + c))
      done
      [ "$count" -gt 0 ] && echo "     → Создай: $hint"
    done
  else
    echo "  🔵 No source code yet — manifest не нужен пока"
  fi
fi
```

### Зачем нужен файл зависимостей

Без файла зависимостей:
- `pip install` невозможен на новой машине
- Docker build не знает что ставить
- Doctor не может детектить стек — все рекомендации по линтеру, MCP, правилам будут мимо
- CI не может воспроизвести окружение

> https://pip.pypa.io/en/stable/reference/requirements-file-format/

---

## 1c. Скрипты сборки — автоматизация (~10 мин) [quality]

- [ ] **Существует** — `Makefile` / `package.json` scripts / `justfile` / `taskfile.yml`
- [ ] **Есть справка** — `make help` или аналог выводит список целей с описаниями
- [ ] **Есть ключевые цели** — test, lint, format, run, clean
- [ ] **Есть быстрая проверка** — быстрый гейт перед тяжёлыми операциями (lint + проверка импортов < 5сек)
- [ ] **Цели работают** — `make test`, `make lint` запускаются без ошибок
- [ ] **Используются переменные** — пути и команды определены один раз в начале, а не захардкожены в каждой цели

### Команды проверки

```bash
# Определить систему сборки:
[[ -f Makefile ]] && echo "✅ Makefile found"
[[ -f justfile ]] && echo "✅ justfile found"
[[ -f package.json ]] && grep -q '"scripts"' package.json 2>/dev/null && echo "✅ package.json scripts found"
[[ -f taskfile.yml ]] && echo "✅ taskfile.yml found"
[[ ! -f Makefile && ! -f justfile && ! -f taskfile.yml ]] && [[ ! -f package.json || $(grep -c '"scripts"' package.json 2>/dev/null) -eq 0 ]] && echo "❌ NO build system found"

# Проверить ключевые цели (Makefile):
if [[ -f Makefile ]]; then
  echo "=== Essential targets ==="
  for target in test lint format run clean help; do
    grep -qE "^${target}:" Makefile && echo "  ✅ make $target" || echo "  ⚠️ MISSING: make $target"
  done

  # Проверить описания целей (комментарии ##):
  help_count=$(grep -cE '^[a-zA-Z_-]+:.*##' Makefile)
  targets_count=$(grep -cE '^[a-zA-Z_-]+:' Makefile)
  echo "  Documented: $help_count / $targets_count targets"

  # Проверить наличие переменных в начале файла:
  vars=$(head -10 Makefile | grep -cE '^[A-Z_]+ *[:?]?=' 2>/dev/null); vars=${vars:-0}
  echo "  Variables defined: $vars"
fi

# Проверить ключевые скрипты (package.json):
if [[ -f package.json ]]; then
  echo "=== Essential scripts ==="
  for script in test lint format start build; do
    grep -qE "\"$script\"\\s*:" package.json && echo "  ✅ npm run $script" || echo "  ⚠️ MISSING: npm run $script"
  done
fi

# Проверить, что цели реально работают:
echo "=== Smoke test ==="
if [[ -f Makefile ]]; then
  make help 2>&1 | head -3 && echo "  ✅ make help works" || echo "  ⚠️ make help failed"
fi
```

### Ключевые цели по экосистемам

| Цель | Python | Node.js | Rust | Go |
|------|--------|---------|------|-----|
| test | `pytest` | `npm test` / `vitest` | `cargo test` | `go test ./...` |
| lint | `ruff check` | `eslint` | `cargo clippy` | `golangci-lint run` |
| format | `ruff format` | `prettier --write` | `cargo fmt` | `gofmt -w .` |
| run | `python -m app` | `npm start` | `cargo run` | `go run .` |
| clean | `rm -rf __pycache__` | `rm -rf dist node_modules` | `cargo clean` | `go clean` |
| help | `grep ## Makefile` | встроенный `npm run` | N/A | N/A |
| check | `lint + import test` | `lint + typecheck` | `clippy + check` | `vet + lint` |

> https://www.kdnuggets.com/the-case-for-makefiles-in-python-projects-and-how-to-get-started

---

## 1d. Структура проекта — не всё в одном файле (~2 мин) [core]

AI-код часто живёт в одном гигантском файле. Это делает проект нечитаемым, неподдерживаемым, невозможным для AI-ассистента (контекст переполняется).

- [ ] **Нет мега-файлов** — нет source файлов > 500 строк в корне проекта
- [ ] **Есть структура каталогов** — код разнесён по папкам (не 10 .py файлов в корне)
- [ ] **Точка входа ясна** — есть main.py / index.ts / main.go (не app_v2_final_FINAL.py)

### Команды проверки

```bash
echo "=== Project structure ==="

# Найти мега-файлы (>500 строк):
echo "--- Mega-files (>500 lines) ---"
mega_found=false
for ext in py ts js go rs rb java kt swift php ex dart c cpp cs scala; do
  while read -r f; do
    lines=$(wc -l < "$f" | tr -d ' ')
    if [ "$lines" -gt 500 ]; then
      echo "  🟠 $f ($lines lines) — слишком большой, разбей на модули"
      mega_found=true
    fi
  done < <(find . -maxdepth 3 -name "*.$ext" \
    ! -path "./.venv/*" ! -path "./node_modules/*" ! -path "./.git/*" \
    ! -path "./dist/*" ! -path "./build/*" ! -path "./target/*" 2>/dev/null)
done

# Проверить захламлённость корня:
echo "--- Root clutter ---"
root_src=$(find . -maxdepth 1 \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" \) 2>/dev/null | wc -l | tr -d ' ')
if [ "$root_src" -gt 5 ]; then
  echo "  🟠 $root_src source files in root — организуй в папки (src/, app/, lib/)"
elif [ "$root_src" -gt 0 ]; then
  echo "  ⚠️ $root_src source files in root (OK для маленьких проектов)"
else
  echo "  ✅ Root clean — код в папках"
fi

# Проверить именование точки входа:
echo "--- Entry point ---"
entry_found=false
for f in main.py app.py index.ts index.js main.go main.rs lib.rs main.swift main.kt App.java; do
  found=$(find . -maxdepth 3 -name "$f" ! -path "./.venv/*" ! -path "./node_modules/*" 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    entry_found=true
    echo "  ✅ Entry: $found"
    break
  fi
done
if [ "$entry_found" = false ]; then
  echo "  ⚠️ No standard entry point found"
  echo "     Есть ли файлы типа app_v2_final.py? Переименуй в main.py"
fi
```

### Признаки плохой структуры

- `app.py` на 2000 строк — разбей на модули по ответственности
- 15 файлов в корне — создай `src/` или `app/`
- `utils.py` > 300 строк — разбей на `utils/format.py`, `utils/validation.py`
- `app_v2_final_FINAL.py` — переименуй, используй git для версий

> https://stackoverflow.blog/2026/01/02/a-new-worst-coder-has-entered-the-chat-vibe-coding-without-code-knowledge/

---

## 1e. Актуальность зависимостей — зависимости не устарели (~10 мин) [quality]
<!-- glossary: lock file = файл фиксирующий точные версии зависимостей (requirements.txt, package-lock.json) -->

Устаревшие зависимости = известные уязвимости + несовместимости. AI часто генерирует код с устаревшими паттернами.

- [ ] **Нет критически устаревших зависимостей** — мажорные версии не отстают на 2+
- [ ] **Lock-файл существует** — `requirements.txt` с pinned версиями / `package-lock.json` / `Cargo.lock`

### Команды проверки

```bash
echo "=== Dependency freshness ==="

# Python?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if command -v pip &>/dev/null || [ -f .venv/bin/pip ]; then
    pip_cmd="pip"
    [ -f .venv/bin/pip ] && pip_cmd=".venv/bin/pip"
    outdated=$($pip_cmd list --outdated --format=columns 2>/dev/null | tail -n +3)
    if [ -n "$outdated" ]; then
      echo "  ⚠️ $(echo "$outdated" | wc -l | tr -d ' ') outdated Python packages:"
      echo "$outdated" | head -10 | sed 's/^/     /'
    else
      echo "  ✅ All Python packages up to date"
    fi
  fi
  if [ -f requirements.txt ]; then
    unpinned=$(grep -cvE '^\s*$|^\s*#|==|>=|~=' requirements.txt 2>/dev/null); unpinned=${unpinned:-0}
    [ "$unpinned" -gt 0 ] && echo "  ⚠️ $unpinned deps without version pin → pip freeze > requirements.txt" \
      || echo "  ✅ All deps pinned in requirements.txt"
  fi
fi

# Node.js?
if [ -f package.json ]; then
  if [ -f package-lock.json ] || [ -f yarn.lock ] || [ -f pnpm-lock.yaml ]; then
    echo "  ✅ Lock file exists"
  else
    echo "  🟠 No lock file — npm install не воспроизводим"
  fi
  if command -v npm &>/dev/null; then
    outdated_count=$(npm outdated 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    [ "$outdated_count" -gt 0 ] && { echo "  ⚠️ $outdated_count outdated npm packages"; npm outdated 2>/dev/null | head -5; } \
      || echo "  ✅ All npm packages up to date"
  fi
fi

# Rust?
if [ -f Cargo.toml ]; then
  [ -f Cargo.lock ] && echo "  ✅ Cargo.lock exists" || echo "  ⚠️ No Cargo.lock — cargo build не воспроизводим"
fi
```

> https://www.qodo.ai/blog/technical-debt/

---

## 1f. README.md — документация для людей (~2 мин) [core]

CLAUDE.md — инструкции для Claude. README.md — первое, что видит человек: коллега, контрибьютор, будущий ты через 6 месяцев.

- [ ] **README.md существует** — в корне проекта
- [ ] **Есть описание** — что проект делает (не как устроен внутри)
- [ ] **Есть инструкция запуска** — Quick Start или Getting Started (для людей, не для Claude)
- [ ] **Нет устаревшей информации** — команды из README работают

### Команды проверки

```bash
echo "=== README.md ==="
if [ -f README.md ]; then
  lines=$(wc -l < README.md | tr -d ' ')
  echo "  ✅ README.md exists ($lines lines)"
  has_desc=false; has_start=false
  grep -qiE '^#+.*\b(about|описание|what|overview)\b' README.md 2>/dev/null && has_desc=true
  [ "$(head -10 README.md | grep -cv '^#\|^$\|^\[')" -gt 0 ] && has_desc=true
  grep -qiE '^#+.*(start|install|setup|usage|запуск|установка)' README.md 2>/dev/null && has_start=true
  [ "$has_desc" = true ] && echo "  ✅ Has description" || echo "  ⚠️ No project description"
  [ "$has_start" = true ] && echo "  ✅ Has getting started" || echo "  ⚠️ No getting started section"
  [ "$lines" -lt 5 ] && echo "  🟠 Only $lines lines — добавь описание и Quick Start"
else
  echo "  ⚠️ No README.md — создай с описанием + Quick Start + инструкция запуска"
fi

# LICENSE detection (informational, not scored)
has_license=false
for f in LICENSE LICENSE.md LICENSE.txt LICENCE LICENCE.md COPYING; do [ -f "$f" ] && has_license=true && break; done
$has_license && echo "  ℹ️  LICENSE file detected" || echo "  ℹ️  No LICENSE file (consider adding one for open-source projects)"
```

### Зачем README если есть CLAUDE.md

| | CLAUDE.md | README.md |
|---|-----------|-----------|
| Для кого | Claude (AI-ассистент) | Люди (коллеги, контрибьюторы) |
| Содержимое | Критические правила, architecture, gotchas | Что проект делает, как запустить |
| Формат | Императивные инструкции | Понятное описание |
| Размер | < 300 строк (компактный) | Любой (может быть длинным) |

**CLAUDE.md НЕ заменяет README**. Новый контрибьютор не будет читать CLAUDE.md чтобы понять что проект делает.

> https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes

> Продвинутые проверки (1g миграции БД) → [FOUNDATION-EXTRA.md](FOUNDATION-EXTRA.md)
