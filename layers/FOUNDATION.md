# Слой 1: Фундамент — "Можно работать"

Слой 0 = не навредить. Слой 1 = Claude и разработчик могут продуктивно работать с проектом.

> `.gitignore` и `.env.example` проверяются в **Слой 0 (Безопасность)** — см. [SECURITY.md](./SECURITY.md)

---

## 1a. CLAUDE.md — инструкции для Claude

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
for section in "quick start\|getting started" "architecture\|structure" "critical\|rules\|must follow" "known issues\|troubleshoot"; do
  grep -qi "$section" CLAUDE.md 2>/dev/null && echo "✅ Has: $section" || echo "⚠️ Missing section: $section"
done

# Проверить наличие блоков кода (готовых к копированию):
code_blocks=$(grep -c '```' CLAUDE.md 2>/dev/null || echo 0)
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

## 1b. Файл зависимостей — стек зафиксирован

- [ ] **Существует** — манифест для стека проекта (см. таблицу ниже)
- [ ] **Не пустой** — содержит реальные зависимости (не пустой файл)
- [ ] **Устанавливается** — `pip install -r requirements.txt` / `npm install` работает без ошибок

### Команды проверки

```bash
echo "=== Dependency manifest ==="
manifest_found=false

# Python?
for f in requirements.txt pyproject.toml setup.py setup.cfg; do
  if [ -f "$f" ]; then
    manifest_found=true
    deps=$(grep -cvE '^\s*$|^\s*#' "$f" 2>/dev/null || echo 0)
    echo "  ✅ $f ($deps non-empty lines)"
  fi
done

# Node.js?
if [ -f package.json ]; then
  manifest_found=true
  dep_count=$(python3 -c "
import json
d = json.load(open('package.json'))
print(len(d.get('dependencies', {})) + len(d.get('devDependencies', {})))
" 2>/dev/null || echo 0)
  echo "  ✅ package.json ($dep_count dependencies)"
fi

# Rust?
if [ -f Cargo.toml ]; then
  manifest_found=true
  echo "  ✅ Cargo.toml"
fi

# Go?
if [ -f go.mod ]; then
  manifest_found=true
  echo "  ✅ go.mod"
fi

# Swift?
if [ -f Package.swift ]; then
  manifest_found=true
  echo "  ✅ Package.swift (Swift Package Manager)"
fi
xcodeproj=$(find . -maxdepth 2 -name "*.xcodeproj" -type d 2>/dev/null | head -1)
if [ -n "$xcodeproj" ]; then
  manifest_found=true
  echo "  ✅ $xcodeproj (Xcode project)"
fi
if [ -f Podfile ]; then
  manifest_found=true
  echo "  ✅ Podfile (CocoaPods)"
fi

# Ruby?
if [ -f Gemfile ]; then
  manifest_found=true
  echo "  ✅ Gemfile"
fi

# Java/Kotlin?
for f in pom.xml build.gradle build.gradle.kts; do
  if [ -f "$f" ]; then
    manifest_found=true
    echo "  ✅ $f"
  fi
done

# PHP?
if [ -f composer.json ]; then
  manifest_found=true
  echo "  ✅ composer.json"
fi

# Elixir?
if [ -f mix.exs ]; then
  manifest_found=true
  echo "  ✅ mix.exs"
fi

# Dart/Flutter?
if [ -f pubspec.yaml ]; then
  manifest_found=true
  echo "  ✅ pubspec.yaml"
fi

# C/C++?
for f in CMakeLists.txt meson.build conanfile.txt conanfile.py; do
  if [ -f "$f" ]; then
    manifest_found=true
    echo "  ✅ $f"
  fi
done

# C# / .NET?
csproj=$(find . -maxdepth 3 -name "*.csproj" -type f 2>/dev/null | head -1)
if [ -n "$csproj" ]; then
  manifest_found=true
  echo "  ✅ $csproj (.NET project)"
fi
sln=$(find . -maxdepth 2 -name "*.sln" -type f 2>/dev/null | head -1)
if [ -n "$sln" ]; then
  manifest_found=true
  echo "  ✅ $sln (.NET solution)"
fi

# Scala?
if [ -f build.sbt ]; then
  manifest_found=true
  echo "  ✅ build.sbt (Scala/sbt)"
fi

# Haskell?
cabal=$(find . -maxdepth 2 -name "*.cabal" -type f 2>/dev/null | head -1)
if [ -n "$cabal" ]; then
  manifest_found=true
  echo "  ✅ $cabal (Haskell/Cabal)"
fi
if [ -f stack.yaml ]; then
  manifest_found=true
  echo "  ✅ stack.yaml (Haskell Stack)"
fi

# Zig?
if [ -f build.zig ]; then
  manifest_found=true
  echo "  ✅ build.zig"
fi

# Clojure?
for f in project.clj deps.edn; do
  if [ -f "$f" ]; then
    manifest_found=true
    echo "  ✅ $f (Clojure)"
  fi
done

# Perl?
for f in Makefile.PL cpanfile; do
  if [ -f "$f" ]; then
    manifest_found=true
    echo "  ✅ $f (Perl)"
  fi
done

# R?
if [ -f DESCRIPTION ]; then
  grep -q "Package:" DESCRIPTION 2>/dev/null && {
    manifest_found=true
    echo "  ✅ DESCRIPTION (R package)"
  }
fi

if [ "$manifest_found" = false ]; then
  # Проверить, есть ли исходный код без манифеста:
  src_dirs=""
  for d in bot src app lib Sources; do
    if [ -d "$d" ]; then
      if [ -z "$src_dirs" ]; then src_dirs="$d"; else src_dirs="$src_dirs $d"; fi
    fi
  done
  if [ -n "$src_dirs" ]; then
    echo "  🔴 Source code exists ($src_dirs/) but NO dependency manifest!"
    echo "     → Другой разработчик (и Claude) не знает какие пакеты нужны"
    echo "     → Зависимости невоспроизводимы на другой машине"
    # Подсказка на основе обнаруженного языка:
    py_count=$(find $src_dirs -name "*.py" 2>/dev/null | wc -l | tr -d ' ')
    js_count=$(find $src_dirs -name "*.js" -o -name "*.ts" 2>/dev/null | wc -l | tr -d ' ')
    swift_count=$(find $src_dirs -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    go_count=$(find $src_dirs -name "*.go" 2>/dev/null | wc -l | tr -d ' ')
    rs_count=$(find $src_dirs -name "*.rs" 2>/dev/null | wc -l | tr -d ' ')
    rb_count=$(find $src_dirs -name "*.rb" 2>/dev/null | wc -l | tr -d ' ')
    java_count=$(find $src_dirs -name "*.java" -o -name "*.kt" 2>/dev/null | wc -l | tr -d ' ')
    [ "$py_count" -gt 0 ] && echo "     → Создай: pip freeze > requirements.txt"
    [ "$js_count" -gt 0 ] && echo "     → Создай: npm init -y"
    [ "$swift_count" -gt 0 ] && echo "     → Создай: swift package init"
    [ "$go_count" -gt 0 ] && echo "     → Создай: go mod init <module>"
    [ "$rs_count" -gt 0 ] && echo "     → Создай: cargo init"
    [ "$rb_count" -gt 0 ] && echo "     → Создай: bundle init"
    [ "$java_count" -gt 0 ] && echo "     → Создай: pom.xml или build.gradle"
    c_count=$(find $src_dirs -name "*.c" -o -name "*.cpp" -o -name "*.cc" -o -name "*.h" 2>/dev/null | wc -l | tr -d ' ')
    cs_count=$(find $src_dirs -name "*.cs" 2>/dev/null | wc -l | tr -d ' ')
    scala_count=$(find $src_dirs -name "*.scala" 2>/dev/null | wc -l | tr -d ' ')
    hs_count=$(find $src_dirs -name "*.hs" 2>/dev/null | wc -l | tr -d ' ')
    zig_count=$(find $src_dirs -name "*.zig" 2>/dev/null | wc -l | tr -d ' ')
    clj_count=$(find $src_dirs -name "*.clj" -o -name "*.cljs" 2>/dev/null | wc -l | tr -d ' ')
    pl_count=$(find $src_dirs -name "*.pl" -o -name "*.pm" 2>/dev/null | wc -l | tr -d ' ')
    r_count=$(find $src_dirs -name "*.R" -o -name "*.r" 2>/dev/null | wc -l | tr -d ' ')
    php_count=$(find $src_dirs -name "*.php" 2>/dev/null | wc -l | tr -d ' ')
    ex_count=$(find $src_dirs -name "*.ex" -o -name "*.exs" 2>/dev/null | wc -l | tr -d ' ')
    dart_count=$(find $src_dirs -name "*.dart" 2>/dev/null | wc -l | tr -d ' ')
    [ "$c_count" -gt 0 ] && echo "     → Создай: cmake_minimum_required(...) в CMakeLists.txt"
    [ "$cs_count" -gt 0 ] && echo "     → Создай: dotnet new console (или classlib/web)"
    [ "$scala_count" -gt 0 ] && echo "     → Создай: build.sbt"
    [ "$hs_count" -gt 0 ] && echo "     → Создай: cabal init или stack init"
    [ "$zig_count" -gt 0 ] && echo "     → Создай: zig init"
    [ "$clj_count" -gt 0 ] && echo "     → Создай: deps.edn или lein new"
    [ "$pl_count" -gt 0 ] && echo "     → Создай: cpanfile"
    [ "$r_count" -gt 0 ] && echo "     → Создай: usethis::create_package()"
    [ "$php_count" -gt 0 ] && echo "     → Создай: composer init"
    [ "$ex_count" -gt 0 ] && echo "     → Создай: mix new <project>"
    [ "$dart_count" -gt 0 ] && echo "     → Создай: dart create <project> или flutter create <project>"
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

## 1c. Скрипты сборки — автоматизация

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
  vars=$(head -10 Makefile | grep -cE '^[A-Z_]+ *[:?]?=' || echo 0)
  echo "  Variables defined: $vars"
fi

# Проверить ключевые скрипты (package.json):
if [[ -f package.json ]]; then
  echo "=== Essential scripts ==="
  for script in test lint format start build; do
    grep -q "\"$script\"" package.json && echo "  ✅ npm run $script" || echo "  ⚠️ MISSING: npm run $script"
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

### Бонусные цели (желательно)

- `install` / `setup` — установка зависимостей + создание venv
- `docker` / `docker-run` — сборка и запуск контейнера
- `status` — сводка git + тесты + линтер
- `hooks` — установка git-хуков

> https://www.kdnuggets.com/the-case-for-makefiles-in-python-projects-and-how-to-get-started

---

## 1d. Структура проекта — не всё в одном файле

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
  find . -maxdepth 3 -name "*.$ext" \
    ! -path "./.venv/*" ! -path "./node_modules/*" ! -path "./.git/*" \
    ! -path "./dist/*" ! -path "./build/*" ! -path "./target/*" \
    2>/dev/null | while read -r f; do
    lines=$(wc -l < "$f" | tr -d ' ')
    if [ "$lines" -gt 500 ]; then
      echo "  🟠 $f ($lines lines) — слишком большой, разбей на модули"
      mega_found=true
    fi
  done
done

# Проверить захламлённость корня:
echo "--- Root clutter ---"
root_src=$(find . -maxdepth 1 -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" 2>/dev/null | wc -l | tr -d ' ')
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

## 1e. Актуальность зависимостей — зависимости не устарели

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
      count=$(echo "$outdated" | wc -l | tr -d ' ')
      echo "  ⚠️ $count outdated Python packages:"
      echo "$outdated" | head -10 | while read -r line; do
        echo "     $line"
      done
      [ "$count" -gt 10 ] && echo "     ... и ещё $((count - 10))"
    else
      echo "  ✅ All Python packages up to date"
    fi
  fi
  # Проверить закреплённые версии:
  if [ -f requirements.txt ]; then
    unpinned=$(grep -cvE '^\s*$|^\s*#|==|>=|~=' requirements.txt 2>/dev/null || echo 0)
    if [ "$unpinned" -gt 0 ]; then
      echo "  ⚠️ $unpinned deps without version pin in requirements.txt"
      echo "     → pip freeze > requirements.txt для фиксации версий"
    else
      echo "  ✅ All deps pinned in requirements.txt"
    fi
  fi
fi

# Node.js?
if [ -f package.json ]; then
  if [ -f package-lock.json ] || [ -f yarn.lock ] || [ -f pnpm-lock.yaml ]; then
    echo "  ✅ Lock file exists"
  else
    echo "  🟠 No lock file — npm install не воспроизводим"
    echo "     → npm install (создаст package-lock.json)"
  fi
  if command -v npm &>/dev/null; then
    outdated_count=$(npm outdated 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    if [ "$outdated_count" -gt 0 ]; then
      echo "  ⚠️ $outdated_count outdated npm packages"
      npm outdated 2>/dev/null | head -5
    else
      echo "  ✅ All npm packages up to date"
    fi
  fi
fi

# Rust?
if [ -f Cargo.toml ]; then
  if [ -f Cargo.lock ]; then
    echo "  ✅ Cargo.lock exists"
  else
    echo "  ⚠️ No Cargo.lock — cargo build не воспроизводим"
  fi
fi
```

> https://www.qodo.ai/blog/technical-debt/
