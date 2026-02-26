# Слой 2: Качество — production-мониторинг

Мониторинг ошибок в production.
Основные проверки (2a–2f): [QUALITY.md](QUALITY.md)
Продвинутые проверки (2g–2k): [QUALITY-EXTRA.md](QUALITY-EXTRA.md)

---

## 2l. Error monitoring — видимость ошибок в production (~10 мин) [quality]
<!-- glossary: error monitoring = сервис (Sentry, LogRocket), собирающий ошибки из production автоматически -->

Вайбкодеры деплоят и не видят ошибок. Узнают от юзеров ("у меня не работает") вместо системы. Sentry ловит ошибки автоматически, группирует, показывает стек, окружение, частоту.

- [ ] **Сервис мониторинга настроен** — Sentry / LogRocket / Axiom / Datadog / Highlight
- [ ] **DSN/ключ в env** — `SENTRY_DSN` или аналог в `.env.example`
- [ ] **SDK подключён** — `sentry-sdk` (Python) / `@sentry/node` (Node) в зависимостях

### Команды проверки

```bash
echo "=== Error monitoring ==="
monitoring_found=false

# Python — Sentry SDK:
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if grep -qE "sentry-sdk|sentry_sdk" requirements*.txt pyproject.toml 2>/dev/null; then
    monitoring_found=true
    echo "  ✅ sentry-sdk в зависимостях (Python)"
  fi
fi

# Node.js — Sentry:
if [ -f package.json ]; then
  if grep -qE '"@sentry/(node|react|nextjs|vue|angular|browser)"' package.json 2>/dev/null; then
    monitoring_found=true
    echo "  ✅ @sentry/* в зависимостях (Node.js)"
  fi
  # LogRocket:
  if grep -q '"logrocket"' package.json 2>/dev/null; then
    monitoring_found=true
    echo "  ✅ LogRocket в зависимостях"
  fi
  # Highlight:
  if grep -q '"@highlight-run' package.json 2>/dev/null; then
    monitoring_found=true
    echo "  ✅ Highlight в зависимостях"
  fi
fi

# Sentry config files:
for f in sentry.client.config.ts sentry.client.config.js sentry.server.config.ts sentry.server.config.js .sentryclirc sentry.properties; do
  if [ -f "$f" ]; then
    monitoring_found=true
    echo "  ✅ $f"
  fi
done

# DSN в env:
if [ "$monitoring_found" = true ]; then
  if grep -qE "SENTRY_DSN|LOGROCKET_APP_ID|DATADOG_API_KEY|HIGHLIGHT_PROJECT_ID" .env.example 2>/dev/null; then
    echo "  ✅ DSN/ключ документирован в .env.example"
  else
    echo "  ⚠️ DSN/ключ не в .env.example — новый разработчик не настроит мониторинг"
  fi
fi

if [ "$monitoring_found" = false ]; then
  echo "  🟠 Нет error monitoring"
  echo "     Без мониторинга: узнаёшь об ошибках от юзеров, а не от системы"
  echo "     → Sentry (бесплатно до 5K ошибок/мес): pip install sentry-sdk / npm i @sentry/node"
  echo "     → Или: LogRocket, Highlight.io, Axiom"
fi
```

### Сравнение сервисов мониторинга

| Сервис | Бесплатный план | Стеки | Фишка |
|--------|----------------|-------|-------|
| **Sentry** | 5K ошибок/мес | Все | Stacktrace + контекст + releases |
| **LogRocket** | 1K сессий/мес | Frontend | Session replay + ошибки |
| **Highlight.io** | 500 сессий/мес | Full-stack | Open-source, session replay |
| **Axiom** | 500 МБ/мес | Все | Логи + трейсы + метрики |

**Для вайбкодера**: Sentry — 2 строки кода, бесплатный план, все стеки.

### Быстрый старт Sentry

**Python:**
```python
import sentry_sdk
sentry_sdk.init(dsn=os.environ["SENTRY_DSN"])
```

**Node.js:**
```javascript
const Sentry = require("@sentry/node");
Sentry.init({ dsn: process.env.SENTRY_DSN });
```

> https://docs.sentry.io/platforms/
> https://blog.sentry.io/how-to-set-up-sentry-for-error-monitoring/
