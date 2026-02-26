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
