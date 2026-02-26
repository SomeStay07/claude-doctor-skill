# Слой 0: Безопасность и защита

Первое, что нужно проверить. Если секреты утекут — всё остальное не имеет значения.

**Важность зависит от видимости** — если репо публичный, ВСЕ находки КРИТИЧЕСКИЕ:
```bash
git remote -v 2>/dev/null | head -1  # проверь Visibility в Settings → Danger Zone
```

---

## 0a. Git инициализирован + есть история (~2 мин) [core]

Без git нет undo, нет бэкапов, нет blame. AI удалил файл — всё потеряно.
49.5% вайбкодеров теряют код потому что не используют git.

- [ ] **Git инициализирован** — `.git/` существует
- [ ] **Есть коммиты** — хотя бы один коммит в истории
- [ ] **Есть remote** — код запушен куда-то (GitHub/GitLab) как бэкап

### Команды проверки

```bash
echo "=== Git ==="
if [ -d .git ]; then
  echo "  ✅ Git initialized"
  commit_count=$(git rev-list --count HEAD 2>/dev/null);
  if [ "$commit_count" -gt 0 ]; then
    echo "  ✅ $commit_count commits"
    last_commit=$(git log --oneline -1 2>/dev/null)
    echo "     last: $last_commit"
  else
    echo "  🔴 No commits — любое удаление файла необратимо!"
    echo "     → git add -A && git commit -m 'Initial commit'"
  fi
  remote=$(git remote -v 2>/dev/null | head -1)
  if [ -n "$remote" ]; then
    echo "  ✅ Remote: $remote"
    # Check if pushed:
    behind=$(git rev-list --count HEAD --not --remotes 2>/dev/null);
    if [ "$behind" -gt 0 ]; then
      echo "  ⚠️ $behind unpushed commits — нет удалённого бэкапа"
    fi
  else
    echo "  🟠 No remote — код только на этой машине, нет бэкапа"
    echo "     → gh repo create --source . --push"
  fi
else
  echo "  🔴 Git NOT initialized — нет истории, нет отката, нет бэкапов!"
  echo "     → git init && git add -A && git commit -m 'Initial commit'"
  echo "     Без git: AI удалил файл = файл потерян навсегда"
fi
```

> https://deepakness.com/blog/git-for-vibe-coders/

---

## 0b. SAST — статический анализ безопасности (~5 мин) [core]
<!-- glossary: SAST = инструмент, который автоматически ищет уязвимости в коде -->

AI-код содержит OWASP Top 10 уязвимости в 45% случаев. Линтер ловит стиль, SAST ловит SQL injection, XSS, path traversal.

- [ ] **SAST инструмент настроен** — bandit (Python) / eslint-plugin-security (Node) / gosec (Go)
- [ ] **Запускается в CI или pre-commit** — не ручной запуск, а автоматический

### Команды проверки

```bash
echo "=== SAST (Static Application Security Testing) ==="
sast_found=false

# Python?
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if command -v bandit &>/dev/null || [ -f .venv/bin/bandit ]; then
    sast_found=true
    echo "  ✅ bandit installed"
  else
    echo "  ⚠️ No SAST — pip install bandit"
    echo "     AI-код содержит SQL injection, XSS, path traversal в 45% случаев"
  fi
  # Check ruff security rules:
  if [ -f ruff.toml ] || [ -f pyproject.toml ]; then
    ruff_s=false
    grep -qE 'S[0-9]' ruff.toml 2>/dev/null && ruff_s=true
    grep -qE '"S"' ruff.toml 2>/dev/null && ruff_s=true
    grep -qE 'S[0-9]' pyproject.toml 2>/dev/null && ruff_s=true
    grep -qE '"S"' pyproject.toml 2>/dev/null && ruff_s=true
    if [ "$ruff_s" = true ]; then
      sast_found=true
      echo "  ✅ ruff security rules (S) enabled"
    else
      echo "  ⚠️ ruff security rules (S) not enabled"
      echo "     → Добавь select = [\"S\"] в ruff.toml для базовой security проверки"
    fi
  fi
fi

# Node.js?
if [ -f package.json ]; then
  if grep -q "eslint-plugin-security" package.json 2>/dev/null; then
    sast_found=true
    echo "  ✅ eslint-plugin-security"
  else
    echo "  ⚠️ No SAST — npm i -D eslint-plugin-security"
  fi
fi

# Check CI for SAST:
sast_in_ci=false
while read -r f; do
  if grep -qiE 'bandit|semgrep|snyk|codeql|gosec|trivy|grype' "$f" 2>/dev/null; then
    sast_in_ci=true
    echo "  ✅ SAST in CI: $(basename "$f")"
  fi
done < <(find .github/workflows \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)

# Check pre-commit for SAST:
if [ -f .pre-commit-config.yaml ]; then
  if grep -qiE 'bandit|semgrep' .pre-commit-config.yaml 2>/dev/null; then
    sast_found=true
    echo "  ✅ SAST in pre-commit"
  fi
fi

if [ "$sast_found" = false ] && [ "$sast_in_ci" = false ]; then
  echo "  🟠 No SAST нигде — уязвимости попадают в production без проверки"
fi
```

### SAST по стеку

| Стек | Инструмент | Установка |
|------|-----------|-----------|
| Python | bandit, ruff S-rules | `pip install bandit` |
| Node.js | eslint-plugin-security | `npm i -D eslint-plugin-security` |
| Go / Multi | gosec, semgrep, trivy, grype | `pip install semgrep` / `brew install trivy` |

> https://www.invicti.com/blog/security-labs/security-issues-in-vibe-coded-web-apps-analyzed/
> https://appwrite.io/blog/post/vibe-coding-security-best-practices

---

## 0c. Секретные файлы не в git (~2 мин) [core]

- [ ] **`.env` не отслеживается** — `git ls-files .env` должен вернуть пустой результат
- [ ] **`.env` никогда не был в git** — `git log --all --diff-filter=A -- .env` должен вернуть пустой результат
- [ ] **`.mcp.json` не отслеживается** — часто содержит строки подключения к БД, API-ключи в блоках `"env"`
- [ ] **Нет других секретных файлов в git**:

```bash
# Check for ANY sensitive files in git:
git ls-files | grep -iE \
  '\.env|\.pem|\.key|\.p12|\.pfx|\.jks|id_rsa|id_ed25519|credentials|secret|\.pypirc|\.npmrc|\.tfstate|\.sql\.gz|\.dump' \
  2>/dev/null | grep -vE '\.(example|sample|template)$'
```

### Типичные секретные файлы по экосистемам

| Файл | Что содержит | Экосистема |
|------|-------------|------------|
| `.env`, `.env.local`, `.env.production` | API-ключи, пароли от БД | Универсальная |
| `.mcp.json` | Строки подключения к БД, API-ключи | Claude Code |
| `.npmrc` | Токены аутентификации npm registry | Node.js |
| `.pypirc` | Учётные данные для загрузки в PyPI | Python |
| `terraform.tfstate` | ВСЕ секреты инфраструктуры в открытом виде | Terraform/IaC |
| `*.sql`, `*.dump`, `*.sql.gz` | Дампы БД с реальными данными пользователей | Любая с БД |
| `id_rsa`, `id_ed25519`, `*.pem`, `*.key` | Приватные ключи SSH/TLS | Любая |
| `credentials.json`, `service-account*.json` | Сервисные аккаунты GCP/Firebase | Google Cloud |
| `application.properties`, `application.yml` | Пароли БД, API-ключи | Java/Spring |
| `wp-config.php` | Учётные данные БД, ключи аутентификации | WordPress |
| `.htpasswd` | Хэшированные пароли | Apache |
| `docker-compose.override.yml` | Локальные переопределения секретов | Docker |

> https://blog.gitguardian.com/secrets-in-source-code-redux/

---

## 0d. .gitignore покрывает ВСЕ категории (~2 мин) [core]

`.gitignore` — единственная страховка от случайных коммитов. Проверяй ВСЕ категории, не только секреты.

- [ ] **Секреты**: `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.tfstate`
- [ ] **Claude Code**: `.mcp.json`, `CLAUDE.local.md`, `.claude/settings.local.json`
- [ ] **Учётные данные**: `credentials.json`, `service-account*.json`, `.npmrc`, `.pypirc`
- [ ] **SSH**: `id_rsa`, `id_ed25519`
- [ ] **Runtime** (по стеку): `__pycache__/`, `.venv/` (Python) | `node_modules/`, `dist/` (Node) | `target/` (Rust/Java)
- [ ] **IDE**: `.idea/`, `.vscode/`
- [ ] **Дампы БД**: `*.sql`, `*.dump`, `*.sql.gz` (если в проекте есть скрипты дампов)

```bash
check_gi() { grep -qF "$1" .gitignore 2>/dev/null && echo "  ✅ $1" || echo "  ⚠️ MISSING: $1"; }
echo "=== Secrets ===" && for p in ".env" "*.pem" "*.key" ".mcp.json" "*.tfstate"; do check_gi "$p"; done
echo "=== Claude Code ===" && for p in ".mcp.json" "CLAUDE.local.md" ".claude/settings.local.json"; do check_gi "$p"; done
echo "=== Runtime ==="
[[ -f requirements.txt || -f pyproject.toml ]] && for p in "__pycache__/" ".venv/" "*.pyc"; do check_gi "$p"; done
[[ -f package.json ]] && for p in "node_modules" "dist/"; do check_gi "$p"; done
[[ -f Cargo.toml ]] && check_gi "target/"
echo "=== IDE ===" && for p in ".idea/" ".vscode/"; do check_gi "$p"; done
```

> https://docs.github.com/en/get-started/getting-started-with-git/ignoring-files

---

## 0e. Нет захардкоженных секретов в исходном коде (~5 мин) [core]

- [ ] **Исходники чистые** — нет API-ключей, токенов, паролей в виде строковых литералов
- [ ] **Конфиги чистые** — `docker-compose.yml`, `config.yaml`, `config.json` используют env-переменные, а не реальные значения
- [ ] **CI workflows чистые** — `.github/workflows/*.yml` используют `${{ secrets.* }}`, а не захардкоженные токены
- [ ] **Dockerfile чистые** — нет `ENV API_KEY=real_value` или `COPY .env`
- [ ] **Ноутбуки чистые** — `.ipynb` файлы не содержат API-ключей в выходных данных ячеек
- [ ] **Shell-скрипты чистые** — нет `export API_KEY="real_value"` в `.sh` файлах

### Варианты сканирования (выбери один)

**Вариант A: gitleaks (РЕКОМЕНДУЕТСЯ — 800+ паттернов, анализ энтропии):**
```bash
# Install:
brew install gitleaks  # macOS
# or: go install github.com/gitleaks/gitleaks/v8@latest

# Full repo scan (including git history):
gitleaks detect --source . --verbose

# Only current state (no history):
gitleaks detect --source . --no-git --verbose
```

gitleaks намного лучше grep — он определяет секреты по энтропии (случайности), а не только по совпадению ключевых слов. Он ловит Base64-закодированные ключи, строки с высокой энтропией и 800+ известных паттернов секретов (AWS, GCP, Stripe, GitHub токены и т.д.).

**Вариант B: grep (запасной вариант, если gitleaks недоступен):**
```bash
# Scan source code for hardcoded secrets (string assignments 8+ chars):
grep -rn -E "(api_key|secret|password|token|bearer|credential|auth_token|private_key)[[:space:]]*[:=][[:space:]]*['\"][A-Za-z0-9+/=_\-]{8,}" \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.go" --include="*.java" --include="*.rb" \
  --exclude-dir=.venv --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=tests --exclude-dir=test --exclude-dir=__tests__ \
  --exclude="*.test.*" --exclude="*_test.*" --exclude="test_*" --exclude=".env.example" . 2>/dev/null

# Scan config/infra files:
grep -rn -E "(password|secret|token|key)[[:space:]]*[:=][[:space:]]*['\"][^$\{][^'\"]{8,}" \
  --include="*.yml" --include="*.yaml" --include="*.json" --include="*.toml" \
  --exclude-dir=.git --exclude-dir=node_modules --exclude=".env.example" --exclude="package*.json" . 2>/dev/null

# Scan Dockerfiles:
grep -rn -E "^(ENV|ARG)[[:space:]]+(API_KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)" \
  --include="Dockerfile*" --include="*.dockerfile" . 2>/dev/null

# Scan shell scripts:
grep -rn -E "^export[[:space:]]+[A-Z_]*(KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)[[:space:]]*=" \
  --include="*.sh" --include="*.bash" . 2>/dev/null
```

**Ограничение grep**: ловит только по ключевым словам. Пропускает строки с высокой энтропией, Base64-закодированные секреты и нестандартные имена. Всегда используй gitleaks, если он доступен.

> https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password

---

## 0f. .env.example — документация и синхронизация (~2 мин) [core]

- [ ] **`.env.example` существует** — документирует ВСЕ env-переменные с placeholder-значениями, НЕ реальными секретами
- [ ] **Сгруппированы по сервисам** — комментарии разделяют секции (Twitter, Telegram, Database, AI и т.д.)
- [ ] **Есть описания** — комментарии объясняют, что делает каждая переменная и где получить API-ключи
- [ ] **Нет реальных секретов** — только значения `your_`, `changeme`, `placeholder`
- [ ] **Все переменные есть в `.env`** — нет пропущенных ключей, которые обрушат приложение при запуске
- [ ] **Нет осиротевших переменных** — в `.env` нет переменных, не задокументированных в `.env.example`

**Команды проверки:**
```bash
# Existence:
[[ -f .env.example ]] && echo "✅ EXISTS" || echo "❌ MISSING .env.example"

# Documentation quality (comments vs vars ratio):
comments=$(grep -c '^#' .env.example 2>/dev/null); comments=${comments:-0}
vars=$(grep -cE '^[A-Z_]+=' .env.example 2>/dev/null); vars=${vars:-0}
[[ $vars -gt 0 ]] && ratio=$((comments * 100 / vars)) || ratio=0
echo "Комментариев: $comments, Переменных: $vars (${ratio}% покрытие)"
[[ $ratio -lt 50 ]] && echo "⚠️ Мало документации" || echo "✅ Задокументировано"

# Real secrets check (values 20+ chars that aren't placeholders):
grep -nE '=[[:space:]]*[A-Za-z0-9+/]{20,}' .env.example 2>/dev/null \
  | grep -vE '(your_|example|fake|placeholder|changeme|xxx|dummy|test|postgresql://)' \
  && echo "🔴 POSSIBLE REAL SECRET in .env.example!" || echo "✅ No real secrets"

# Sync check (requires .env):
if [ ! -f .env ]; then
  echo "⚠️ No .env found (create from .env.example)"
else

echo "=== MISSING from .env ==="
diff <(grep -E '^[A-Z_]+=' .env.example | sed 's/=.*//' | sort -u) \
     <(grep -E '^[A-Z_]+=' .env | sed 's/=.*//' | sort -u) 2>/dev/null | grep "^<" | sed 's/^< /  /'

echo "=== UNDOCUMENTED in .env ==="
diff <(grep -E '^#?[[:space:]]*[A-Z_]+=' .env.example | sed 's/^#[[:space:]]*//' | sed 's/=.*//' | sort -u) \
     <(grep -E '^[A-Z_]+=' .env | sed 's/=.*//' | sort -u) 2>/dev/null | grep "^>" | sed 's/^> /  /'
fi
```

> https://12factor.net/config

---

## 0g. Права доступа к файлам (~5 мин) [advanced]

- [ ] **`.env` не читается всеми** — должен быть `chmod 600` (чтение/запись только для владельца)
- [ ] **Приватные ключи ограничены** — `*.pem`, `*.key` должны быть `chmod 600`

```bash
# Check permissions (should show -rw------- for sensitive files):
for f in .env .mcp.json; do [ -f "$f" ] && ls -la "$f"; done
find . -maxdepth 1 \( -name "*.pem" -o -name "*.key" \) -exec ls -la {} + 2>/dev/null
# Fix: chmod 600 .env .mcp.json
```

> https://en.wikipedia.org/wiki/File-system_permissions

---

## 0h. Уязвимости в зависимостях (~5 мин) [core]

- [ ] **Нет известных уязвимостей** в зависимостях

```bash
pip-audit 2>/dev/null || true  # Python
if [ -f pnpm-lock.yaml ]; then pnpm audit 2>/dev/null || true
elif [ -f yarn.lock ]; then yarn audit 2>/dev/null || true
elif [ -f package-lock.json ]; then npm audit 2>/dev/null || true; fi
govulncheck ./... 2>/dev/null || true  # Go
cargo audit 2>/dev/null || true  # Rust
```

> https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/

---

## 0i. Предотвращение — эшелонированная защита (~10 мин) [core]
<!-- glossary: gitleaks = утилита, сканирующая git-историю на случайно закоммиченные пароли и ключи -->
<!-- glossary: pre-commit hook = скрипт, который автоматически запускается перед каждым git commit -->

Секреты утекают потому что люди ошибаются. Одного уровня защиты недостаточно — используй несколько:

### Уровень 1: Pre-commit hook (локально, блокирует перед коммитом)

- [ ] **gitleaks / detect-secrets / trufflehog настроен** как pre-commit hook

```bash
# Install gitleaks:
brew install gitleaks  # macOS
# or: go install github.com/gitleaks/gitleaks/v8@latest

# Test manually:
gitleaks detect --source . --verbose

# Add to .gitleaks.toml for false positives:
# [allowlist]
# paths = ["tests/", ".env.example"]
```

**Проблема**: разработчики могут обойти через `git commit --no-verify`.

### Уровень 2: CI-сканирование секретов (удалённо, ловит обходы)

- [ ] **CI-пайплайн включает сканирование секретов** — ловит то, что pre-commit пропустил

```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push, pull_request]
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Это ловит секреты даже когда разработчики используют `--no-verify`.

### Уровень 3: GitHub secret scanning (на уровне платформы, алерты при push)

- [ ] **GitHub secret scanning включён** — в настройках репо Settings → Code security → Secret scanning

GitHub автоматически определяет токены от 200+ провайдеров (AWS, GCP, Stripe и т.д.) и оповещает или блокирует push.

> https://docs.gitleaks.io/

---

> Продвинутые проверки (0j Docker, 0k клиентские секреты) + инцидент-план → [SECURITY-EXTRA.md](SECURITY-EXTRA.md)
