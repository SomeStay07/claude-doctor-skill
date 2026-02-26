# Определение зрелости проекта — Adaptive Scoring

Doctor автоматически определяет уровень зрелости проекта и адаптирует аудит: веса слоёв, набор применимых чеков, пороги оценок, терминологию.

---

## Детекция зрелости

Запусти в Phase 1 (после изучения проекта):

```bash
echo "=== Определение зрелости ==="
maturity_score=0
has_git=false; has_deps=false; has_tests=false
has_linter=false; has_ci=false; has_env=false; has_claude=false

# 1. Git
if [ -d .git ] && git rev-list --count HEAD &>/dev/null; then
  has_git=true; maturity_score=$((maturity_score + 1))
fi

# 2. Зависимости
for f in requirements.txt pyproject.toml package.json Cargo.toml go.mod Gemfile composer.json pom.xml build.gradle pubspec.yaml mix.exs; do
  if [ -f "$f" ]; then
    has_deps=true; maturity_score=$((maturity_score + 1)); break
  fi
done

# 3. Тесты
for d in tests test __tests__ spec; do
  if [ -d "$d" ]; then
    has_tests=true; maturity_score=$((maturity_score + 1)); break
  fi
done

# 4. Линтер
for f in ruff.toml .ruff.toml .eslintrc .eslintrc.json .eslintrc.yml .eslintrc.js eslint.config.mjs eslint.config.js .flake8 .pylintrc clippy.toml .golangci.yml biome.json biome.jsonc deno.json deno.jsonc bunfig.toml; do
  if [ -f "$f" ]; then
    has_linter=true; maturity_score=$((maturity_score + 1)); break
  fi
done
# Проверить pyproject.toml на ruff/pylint/flake8:
if [ "$has_linter" = false ] && [ -f pyproject.toml ]; then
  grep -qiE '\[tool\.(ruff|pylint|flake8)\]' pyproject.toml 2>/dev/null && {
    has_linter=true; maturity_score=$((maturity_score + 1))
  }
fi
# Проверить установленные линтеры (конфиг может быть в defaults):
if [ "$has_linter" = false ]; then
  for cmd in ruff eslint pylint flake8 biome golangci-lint clippy; do
    command -v "$cmd" &>/dev/null && { has_linter=true; maturity_score=$((maturity_score + 1)); break; }
  done
fi

# 5. CI
if [ -d .github/workflows ] || [ -f .gitlab-ci.yml ] || [ -f .circleci/config.yml ] || [ -f Jenkinsfile ]; then
  has_ci=true; maturity_score=$((maturity_score + 1))
fi

# 6. Env handling
if [ -f .env.example ]; then
  has_env=true; maturity_score=$((maturity_score + 1))
fi

# 7. Toolchain versioning
has_toolchain=false
for f in .tool-versions .mise.toml .rtx.toml .python-version .node-version .nvmrc; do
  [ -f "$f" ] && has_toolchain=true && break
done

# 8. Monorepo detection
has_monorepo=false
for f in turbo.json nx.json lerna.json pnpm-workspace.yaml; do
  [ -f "$f" ] && has_monorepo=true && break
done

# 9. Claude Code
if [ -d .claude ]; then
  has_claude=true; maturity_score=$((maturity_score + 1))
fi

# === Определение уровня ===
level="starter"
if [ "$has_git" = false ]; then
  level="starter"
elif [ "$has_tests" = false ] && [ "$has_ci" = false ] && [ "$has_linter" = false ]; then
  level="starter"
elif [ "$has_tests" = true ] && [ "$has_linter" = true ] && { [ "$has_ci" = true ] || [ "$has_env" = true ]; }; then
  if [ "$has_claude" = true ]; then
    # Pro: проверяем наличие agents/skills/hooks
    has_cc_automation=false
    [ -d .claude/agents ] && has_cc_automation=true
    [ -d .claude/skills ] && has_cc_automation=true
    for sf in .claude/settings.json .claude/settings.local.json; do [ -f "$sf" ] && grep -q '"hooks"' "$sf" 2>/dev/null && has_cc_automation=true; done
    [ "$has_cc_automation" = true ] && level="pro" || level="mature"
  else
    level="mature"
  fi
else
  level="growing"
fi
```

---

## Вывод зрелости

```
ЗРЕЛОСТЬ ПРОЕКТА: [Level] [Emoji]
══════════════════════════════════════
✅/❌ Git    ✅/❌ Зависимости   ✅/❌ Тесты
✅/❌ CI     ✅/❌ Линтер        ✅/❌ Claude Code

Профиль аудита: N чеков ([описание])
```

Эмоджи по уровню:
- Starter = 🌱
- Growing = 🌿
- Mature = 🌳
- Pro = ⚡

---

## Теги чеков

> Полная таблица тегов (18 core + 9 quality + 7 advanced + 12 cc = 46) → [CHECKLIST.md](../CHECKLIST.md)

Чеки за пределами текущего уровня **отображаются** как `🔮 Бонус`, но **НЕ считаются** в скор. Это справедливо: новичок не штрафуется за отсутствие MCP-серверов.

---

## Взвешенный скор

Скор считается как взвешенная сумма процентов по слоям:

```
Взвешенный скор = Σ (score_layer_i / max_layer_i × weight_layer_i)
```

### Веса слоёв по уровню

| Слой | Starter | Growing | Mature | Pro |
|------|---------|---------|--------|-----|
| 0: Безопасность (13) | 50% | 30% | 25% | 20% |
| 1: Фундамент (7) | 35% | 25% | 20% | 15% |
| 2: Качество (12) | 15% | 30% | 25% | 20% |
| 3: Интеллект (2) | — | 5% | 10% | 15% |
| 4: Контекст (5) | — | 5% | 10% | 15% |
| 5: DX (7) | — | 5% | 10% | 15% |

**`—`** = слой показывается как 🔮 Бонус, вес 0%.

### Подсчёт score_layer_i

Считаются **только чеки с применимыми тегами** для данного уровня:

- **Starter**: в Слое 2 (12 чеков) считаются только 4 `[core]` чека → max=4, не 12
- **Growing**: в Слое 2 считаются 4 `[core]` + 4 `[quality]` = 8 → max=8 (2 `[advanced]` + 2 `[cc]` = бонус)
- **Mature**: 4+4+2 `[advanced]` = 10 → max=10 (2 `[cc]` = бонус)
- **Pro**: все 12 → max=12

### N/A чеки

Когда чек не применим к проекту (напр. Docker без Dockerfile, миграции без БД) — он **N/A**:
- N/A чеки **исключаются** из формулы: уменьшают И `score`, И `max`
- Пример: Слой 0 = 13 чеков. Docker-чек N/A → max = 12, не 13
- Формула: `score_layer / max_applicable` (max_applicable = всего − N/A − бонус)

Это гарантирует что проект без Docker не штрафуется за Docker-чеки, а проект без БД — за миграции.

### Перераспределение весов при max_applicable=0

Если у слоя нет применимых чеков (все бонусные или все N/A), его вес перераспределяется пропорционально на остальные слои:

```
remaining = Σ весов слоёв где max > 0
new_weight_i = original_weight_i / remaining × 100%
```

Пример (Growing, слои 3-4 пустые — все чеки `[cc]`):
- Оригинал: 30/25/30/5/5/5
- Слои 3,4 = 0 applicable → 10% перераспределяется
- remaining = 30+25+30+5 = 90%
- Новые: 33.3/27.8/33.3/—/—/5.6

---

## Пороги оценки

### Starter 🌱

| Скор | Оценка |
|------|--------|
| 80%+ | Отличный старт 🌟 |
| 60-79% | На верном пути 🌱 |
| 40-59% | Есть основа 🔧 |
| < 40% | Начало пути 🚀 |

> Для Starter **нет слова "Плохо"**. Новичок не виноват что у него нет CI — он только начал.

### Growing 🌿

| Скор | Оценка |
|------|--------|
| 85%+ | Отлично 🌟 |
| 70-84% | Хорошо ✅ |
| 50-69% | Средне ⚠️ |
| < 50% | Требует внимания 🔧 |

### Mature 🌳 / Pro ⚡

| Скор | Оценка |
|------|--------|
| 90%+ | Отлично 🌟 |
| 70-89% | Хорошо ✅ |
| 50-69% | Средне ⚠️ |
| < 50% | Плохо 🔴 |

---

## Следующий уровень

После итоговой сводки — покажи путь роста (3 конкретных шага):

### Starter → Growing

```
СЛЕДУЮЩИЙ УРОВЕНЬ: Starter → Growing
═════════════════════════════════════
1. → Добавь тесты (хотя бы 1 файл с 3 тестами)
2. → Настрой линтер (ruff для Python / eslint для Node)
3. → Зафиксируй зависимости (pip freeze > requirements.txt)
```

### Growing → Mature

```
СЛЕДУЮЩИЙ УРОВЕНЬ: Growing → Mature
════════════════════════════════════
1. → Добавь CI ИЛИ .env.example (любой из двух поднимет до Mature)
2. → Убедись что есть тесты + линтер (оба обязательны)
3. → Добавь coverage (pytest-cov / istanbul, цель: 60%)
```

### Mature → Pro

```
СЛЕДУЮЩИЙ УРОВЕНЬ: Mature → Pro
═══════════════════════════════
1. → Создай .claude/agents/ (code-reviewer, debugger, architect)
2. → Настрой MCP-серверы (.mcp.json под стек проекта)
3. → Добавь скиллы (/test, /status — автоматизация команд)
```

### Pro (максимальный уровень)

```
PRO УРОВЕНЬ ДОСТИГНУТ ⚡
════════════════════════
Точечные улучшения:
- Compound agents (агент вызывает агента)
- Custom MCP-серверы (свой сервер под проект)
- LLM-evaluation (тесты качества AI-ответов)
```

---

## Глоссарий для Starter

Когда уровень = Starter, Doctor добавляет пояснения к терминам. Layer-файлы содержат `<!-- glossary: TERM = explanation -->` комментарии.

**Формат вывода для Starter:**

```
⚠️ Нет SAST (инструмент ищет уязвимости в коде автоматически)
⚠️ Нет pre-commit хука (скрипт, проверяющий код перед каждым коммитом)
```

**Для Growing+ пояснения НЕ показываются** — разработчик знает базовые термины.
