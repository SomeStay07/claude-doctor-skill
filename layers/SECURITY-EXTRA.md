# Слой 0: Безопасность — продвинутые проверки

Продвинутые проверки безопасности (Docker, frontend, инцидент-план).
Базовые проверки (0a-0i): [SECURITY.md](SECURITY.md)

---

## 0j. Docker-безопасность — секреты не утекают в образ (~10 мин) [advanced]
<!-- glossary: .dockerignore = файл, указывающий Docker какие файлы НЕ копировать в контейнер -->

Если в проекте есть Dockerfile, AI часто копирует `.env` прямо в образ или хардкодит секреты в `ENV`. Образ пушится в registry → секреты доступны всем.

- [ ] **`.dockerignore` существует** — и покрывает `.env`, `.mcp.json`, `*.pem`, `*.key`, `.git/`
- [ ] **Нет COPY .env** — секреты не копируются в образ
- [ ] **Нет захардкоженных ENV-секретов** — нет `ENV API_KEY=real_value` в Dockerfile
- [ ] **Non-root USER** — контейнер не работает от root
- [ ] **Multi-stage build** — build-time зависимости не попадают в финальный образ

### Команды проверки

```bash
echo "=== Docker security ==="
dockerfile=""
for f in Dockerfile Dockerfile.* docker/Dockerfile; do
  [ -f "$f" ] && dockerfile="$f" && break
done

if [ -z "$dockerfile" ]; then
  echo "  🔵 No Dockerfile — пропускаем"
else
  echo "  📦 Found: $dockerfile"

  # .dockerignore:
  if [ -f .dockerignore ]; then
    echo "  ✅ .dockerignore exists"
    for p in ".env" ".mcp.json" ".git" "*.pem" "*.key"; do
      grep -qF "$p" .dockerignore 2>/dev/null && echo "     ✅ $p" || echo "     ⚠️ MISSING: $p"
    done
  else
    echo "  🔴 No .dockerignore — ВСЕ файлы (включая .env) копируются в образ!"
    echo "     → Создай .dockerignore с: .env .mcp.json .git *.pem *.key node_modules .venv"
  fi

  # COPY .env?
  if grep -qE "^COPY.*\.env" "$dockerfile" 2>/dev/null; then
    echo "  🔴 COPY .env found — секреты запекаются в образ!"
    grep -n "COPY.*\.env" "$dockerfile"
    echo "     → Используй runtime env vars: docker run -e API_KEY=\$API_KEY"
  else
    echo "  ✅ No COPY .env"
  fi

  # Hardcoded ENV secrets?
  secret_envs=$(grep -nE "^ENV\s+[A-Z_]*(KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)\s*=" "$dockerfile" 2>/dev/null)
  if [ -n "$secret_envs" ]; then
    echo "  🔴 Hardcoded secrets in ENV:"
    echo "$secret_envs" | while read -r line; do echo "     $line"; done
    echo "     → Используй docker run --env-file .env или -e VAR=\$VAR"
  else
    echo "  ✅ No hardcoded secrets in ENV"
  fi

  # Non-root USER?
  if grep -qE "^USER\s+" "$dockerfile" 2>/dev/null; then
    echo "  ✅ Non-root USER defined"
  else
    echo "  ⚠️ No USER directive — контейнер работает от root"
    echo "     → Добавь: RUN adduser --disabled-password appuser && USER appuser"
  fi

  # Multi-stage build?
  stage_count=$(grep -cE "^FROM\s+" "$dockerfile" 2>/dev/null || echo 0)
  if [ "$stage_count" -gt 1 ]; then
    echo "  ✅ Multi-stage build ($stage_count stages)"
  else
    echo "  ⚠️ Single-stage build — build tools попадают в финальный образ"
  fi
fi
```

> https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html
> https://github.com/docker/docker-bench-security

---

## 0k. Утечка секретов в клиентском коде (~10 мин) [advanced]

AI-код часто кладёт API ключи прямо во frontend. Переменные `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_` попадают в бандл и видны всем через DevTools.

- [ ] **Нет секретов во frontend env-переменных** — `NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*` не содержат приватных ключей
- [ ] **Нет API-ключей в клиентском коде** — нет hardcoded ключей в `.ts`, `.tsx`, `.jsx` frontend файлах

### Команды проверки

```bash
echo "=== Client-side secrets ==="

# Check for frontend env prefixes with secret-like names:
frontend_found=false

# Next.js:
if [ -f next.config.js ] || [ -f next.config.mjs ] || [ -f next.config.ts ]; then
  frontend_found=true
  leaked=$(grep -rnE "NEXT_PUBLIC_[A-Z_]*(SECRET|KEY|TOKEN|PASSWORD|CREDENTIAL)" .env* 2>/dev/null | grep -v ".env.example")
  if [ -n "$leaked" ]; then
    echo "  🔴 Secrets in NEXT_PUBLIC_ env vars (видны в браузере!):"
    echo "$leaked" | while read -r line; do echo "     $line"; done
  else
    echo "  ✅ No secrets in NEXT_PUBLIC_ vars"
  fi
fi

# Vite:
if [ -f vite.config.ts ] || [ -f vite.config.js ]; then
  frontend_found=true
  leaked=$(grep -rnE "VITE_[A-Z_]*(SECRET|KEY|TOKEN|PASSWORD|CREDENTIAL)" .env* 2>/dev/null | grep -v ".env.example")
  if [ -n "$leaked" ]; then
    echo "  🔴 Secrets in VITE_ env vars (видны в браузере!):"
    echo "$leaked" | while read -r line; do echo "     $line"; done
  else
    echo "  ✅ No secrets in VITE_ vars"
  fi
fi

# Create React App:
if grep -q "react-scripts" package.json 2>/dev/null; then
  frontend_found=true
  leaked=$(grep -rnE "REACT_APP_[A-Z_]*(SECRET|KEY|TOKEN|PASSWORD|CREDENTIAL)" .env* 2>/dev/null | grep -v ".env.example")
  if [ -n "$leaked" ]; then
    echo "  🔴 Secrets in REACT_APP_ env vars (видны в браузере!):"
    echo "$leaked" | while read -r line; do echo "     $line"; done
  else
    echo "  ✅ No secrets in REACT_APP_ vars"
  fi
fi

# Hardcoded keys in frontend source:
if [ -d src ] || [ -d app ] || [ -d pages ] || [ -d components ]; then
  for ext in ts tsx js jsx; do
    hardcoded=$(grep -rnE "(api[_-]?key|secret|token)\s*[:=]\s*['\"][A-Za-z0-9]{20,}" \
      --include="*.$ext" src/ app/ pages/ components/ 2>/dev/null | head -5)
    if [ -n "$hardcoded" ]; then
      echo "  🔴 Hardcoded secrets in frontend .$ext files:"
      echo "$hardcoded" | while read -r line; do echo "     $line"; done
    fi
  done
fi

if [ "$frontend_found" = false ]; then
  echo "  🔵 No frontend framework detected — пропускаем"
fi
```

### Что безопасно в NEXT_PUBLIC_ / VITE_

| Безопасно (публичные) | Опасно (приватный ключ) |
|----------------------|-----------------------|
| `NEXT_PUBLIC_API_URL` | `NEXT_PUBLIC_API_SECRET_KEY` |
| `VITE_STRIPE_PUBLISHABLE_KEY` | `VITE_STRIPE_SECRET_KEY` |
| `REACT_APP_GOOGLE_MAPS_ID` | `REACT_APP_DATABASE_PASSWORD` |

**Правило**: если ключ позволяет **читать** public данные — ОК для клиента. Если позволяет **писать/удалять** — НИКОГДА в клиент.

> https://www.invicti.com/blog/web-security/vibe-coding-security-checklist-how-to-secure-ai-generated-apps/
> https://fingerprint.com/blog/vibe-coding-security-checklist/

---

## 0l. AI API cost protection — защита от разорения (~5 мин) [core]
<!-- glossary: billing alerts = уведомления при превышении лимита расходов на AI API -->

Вайбкодеры используют OpenAI/Anthropic/Google AI без лимитов. Зацикленный агент без `max_tokens` = $500 за ночь. Billing alerts — единственная страховка.

- [ ] **Billing alerts настроены** — лимит расходов на дашборде провайдера
- [ ] **max_tokens указан** — в API-вызовах есть ограничение длины ответа
- [ ] **Dev/prod ключи раздельные** — разные API ключи для разработки и production

### Команды проверки

```bash
echo "=== AI API cost protection ==="
ai_api_found=false

# Детекция AI API ключей:
for key_name in OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_AI_API_KEY GROQ_API_KEY TOGETHER_API_KEY; do
  if grep -q "$key_name" .env.example .env 2>/dev/null; then
    ai_api_found=true
    echo "  📡 $key_name обнаружен"
  fi
done

if [ "$ai_api_found" = false ]; then
  echo "  🔵 AI API ключи не обнаружены — пропускаем"
else
  # Проверка max_tokens в коде:
  src_dirs=""
  for d in src app lib bot server backend api core pkg cmd internal services packages; do [ -d "$d" ] && src_dirs="$src_dirs $d"; done
  if [ -n "$src_dirs" ]; then
    api_calls=$(grep -rn "chat.completions.create\|messages.create\|generate_content" "$src_dirs" 2>/dev/null | wc -l | tr -d ' ')
    max_tokens=$(grep -rn "max_tokens\|max_output_tokens\|maxOutputTokens" "$src_dirs" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$api_calls" -gt 0 ]; then
      if [ "$max_tokens" -gt 0 ]; then
        echo "  ✅ max_tokens указан ($max_tokens из $api_calls вызовов)"
      else
        echo "  🔴 $api_calls API-вызовов БЕЗ max_tokens — зацикленный агент = неограниченные расходы"
        echo "     → Добавь max_tokens в каждый вызов"
      fi
    fi
  fi

  # Проверка раздельных ключей:
  for key_name in OPENAI_API_KEY ANTHROPIC_API_KEY; do
    if grep -q "$key_name" .env.example 2>/dev/null; then
      if grep -qE "${key_name}_(DEV|PROD|STAGING)" .env.example 2>/dev/null; then
        echo "  ✅ Раздельные $key_name для окружений"
      else
        echo "  🟡 Один $key_name для всех окружений — dev-баг тратит production-бюджет"
      fi
    fi
  done

  echo "  💡 Настрой billing alerts: OpenAI → Settings → Billing → Usage limits"
  echo "     Anthropic → Settings → Plans & Billing → Spend notifications"
fi
```

> https://platform.openai.com/docs/guides/production-best-practices
> https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching

---

## 0m. Backup strategy — данные не потеряются (~5 мин) [advanced]
<!-- glossary: backup = резервная копия данных, позволяющая восстановиться после сбоя или ошибки -->

Git бэкапит код, но НЕ данные. Managed DB (Railway, Supabase, RDS) включает бэкапы автоматически. Self-hosted DB без бэкапов — один `DROP TABLE` от катастрофы.

- [ ] **Managed DB или backup скрипт** — бэкапы включены автоматически или есть скрипт
- [ ] **Git remote настроен** — код в облаке (проверяется в 0a)

### Команды проверки

```bash
echo "=== Backup strategy ==="

# Git remote (ref: check 0a):
if git remote -v 2>/dev/null | grep -q "push"; then
  echo "  ✅ Git remote настроен (код бэкапится)"
else
  echo "  🔴 Нет git remote — код только на локальной машине"
fi

# Managed DB detection:
db_detected=false
managed_backup=false

# Railway:
if grep -rqiE "railway|RAILWAY_" .env .env.example Procfile railway.toml 2>/dev/null; then
  managed_backup=true; db_detected=true
  echo "  ✅ Railway — автоматические бэкапы БД включены"
fi
# Supabase:
if grep -rqiE "supabase|SUPABASE_" .env .env.example 2>/dev/null; then
  managed_backup=true; db_detected=true
  echo "  ✅ Supabase — автоматические бэкапы включены"
fi
# Neon:
if grep -rqiE "neon\.tech|NEON_" .env .env.example 2>/dev/null; then
  managed_backup=true; db_detected=true
  echo "  ✅ Neon — point-in-time recovery включён"
fi
# PlanetScale:
if grep -rqiE "planetscale|PLANETSCALE_" .env .env.example 2>/dev/null; then
  managed_backup=true; db_detected=true
  echo "  ✅ PlanetScale — автоматические бэкапы"
fi

# Backup scripts:
backup_script=false
for f in scripts/backup* backup* scripts/*dump*; do
  if [ -f "$f" ] 2>/dev/null; then
    backup_script=true
    echo "  ✅ Backup script: $f"
  fi
done

# Self-hosted DB without backup:
if [ "$db_detected" = false ]; then
  src_dirs=""
  for d in src app lib bot server backend api core pkg cmd internal services packages; do [ -d "$d" ] && src_dirs="$src_dirs $d"; done
  if [ -n "$src_dirs" ]; then
    grep -rqE "asyncpg|psycopg|prisma|mongoose|sqlalchemy" "$src_dirs" 2>/dev/null && db_detected=true
  fi
fi

if [ "$db_detected" = true ] && [ "$managed_backup" = false ] && [ "$backup_script" = false ]; then
  echo "  🟠 БД есть, но бэкапов НЕТ"
  echo "     → Managed DB (Railway/Supabase/Neon) включает бэкапы автоматически"
  echo "     → Self-hosted: pg_dump + cron или scripts/backup.sh"
fi
```

> https://docs.railway.com/guides/backups
> https://supabase.com/docs/guides/platform/backups

---

## Если секреты утекли — план действий

1. **СТОП** — не коммить ничего нового
2. **Оцени масштаб** — репо публичный? Сколько коммитов содержат секрет?
   ```bash
   git log --all --oneline | wc -l  # total commits exposed
   git remote -v                     # where was it pushed?
   ```
3. **Ротируй** ВСЕ утёкшие ключи/токены/пароли немедленно (считай их скомпрометированными)
4. **Очисти историю** — `git filter-repo` (предпочтительно) или BFG Repo-Cleaner
5. **Force push** — после очистки истории (согласуй с командой)
6. **Добавь в .gitignore** — предотврати повторение
7. **Добавь pre-commit hook + CI-сканирование** — эшелонированная защита
8. **Уведоми команду** — если запушено в remote, всем коллабораторам нужно пере-клонировать
9. **Проверь логи аудита** — использовали ли секрет неавторизованные лица? (проверь дашборды провайдеров)
