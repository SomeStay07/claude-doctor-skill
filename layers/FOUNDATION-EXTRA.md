# Слой 1: Фундамент — продвинутые проверки

Продвинутые проверки фундамента (миграции БД).
Базовые проверки (1a-1f): [FOUNDATION.md](FOUNDATION.md)

---

## 1g. Миграции БД — схема под контролем (~10 мин) [quality]
<!-- glossary: миграции БД = скрипты, описывающие изменения схемы базы данных (добавление таблиц, колонок) — без них ALTER TABLE вручную -->

Вайбкодеры меняют схему БД вручную (ALTER TABLE) или пересоздают таблицы. Результат: потеря данных, невоспроизводимость, невозможность отката.

- [ ] **Инструмент миграций настроен** — alembic / prisma migrate / knex / typeorm / drizzle-kit
- [ ] **Директория миграций существует** — `alembic/versions/`, `prisma/migrations/`, `migrations/`
- [ ] **Конфиг миграций есть** — `alembic.ini`, `prisma/schema.prisma`, `knexfile.*`

### Команды проверки

```bash
echo "=== Database migrations ==="

# Определить наличие БД в проекте:
db_detected=false
grep -rq "DATABASE_URL" .env.example .env 2>/dev/null && db_detected=true

src_dirs=""
for d in src app lib bot server backend api core pkg cmd internal services packages; do
  [ -d "$d" ] && src_dirs="$src_dirs $d"
done

if [ -n "$src_dirs" ]; then
  grep -rqE "asyncpg|psycopg|prisma|typeorm|sequelize|knex|sqlalchemy|mongoose|drizzle|diesel|ecto|activerecord" "$src_dirs" 2>/dev/null && db_detected=true
fi

if [ "$db_detected" = false ]; then
  echo "  🔵 БД не обнаружена — пропускаем"
else
  echo "  📦 Проект использует базу данных"
  migration_found=false

  # Python — Alembic:
  if [ -d alembic ] || [ -f alembic.ini ]; then
    migration_found=true
    ver_count=$(find alembic/versions -name "*.py" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✅ Alembic ($ver_count миграций)"
  fi

  # Node.js — Prisma:
  if [ -d prisma/migrations ] || [ -f prisma/schema.prisma ]; then
    migration_found=true
    mig_count=$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✅ Prisma Migrate ($mig_count миграций)"
  fi

  # Node.js — Drizzle:
  if [ -f drizzle.config.ts ] || [ -f drizzle.config.js ]; then
    migration_found=true
    echo "  ✅ Drizzle Kit"
  fi

  # Node.js — Knex:
  for f in knexfile.js knexfile.ts knexfile.mjs; do
    if [ -f "$f" ]; then
      migration_found=true
      echo "  ✅ Knex ($f)"
      break
    fi
  done

  # Node.js — TypeORM:
  if [ -f ormconfig.json ] || [ -f ormconfig.ts ]; then
    migration_found=true
    echo "  ✅ TypeORM"
  fi

  # Generic migrations dir:
  if [ "$migration_found" = false ] && [ -d migrations ]; then
    migration_found=true
    mig_count=$(find migrations -name "*.sql" -o -name "*.py" -o -name "*.js" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✅ migrations/ ($mig_count файлов)"
  fi

  if [ "$migration_found" = false ]; then
    echo "  🟠 БД есть, но миграций НЕТ"
    echo "     Без миграций: ALTER TABLE вручную → потеря данных, невоспроизводимость"
    # Подсказки по стеку:
    if [ -n "$src_dirs" ]; then
      grep -rq "sqlalchemy\|alembic" "$src_dirs" 2>/dev/null && echo "     → alembic init alembic"
      grep -rq "prisma" "$src_dirs" 2>/dev/null && echo "     → npx prisma migrate dev"
      grep -rq "knex" "$src_dirs" 2>/dev/null && echo "     → npx knex migrate:make init"
      grep -rq "drizzle" "$src_dirs" 2>/dev/null && echo "     → npx drizzle-kit generate"
      grep -rq "typeorm" "$src_dirs" 2>/dev/null && echo "     → npx typeorm migration:create"
    fi
  fi
fi
```

### Зачем миграции

| Без миграций | С миграциями |
|-------------|-------------|
| ALTER TABLE вручную | `alembic upgrade head` |
| Забыл что менял | История изменений в git |
| Коллега не знает новую схему | Автоматическая синхронизация |
| Откатить невозможно | `alembic downgrade -1` |
| CI не может создать БД | Миграции в CI = воспроизводимость |

> https://docs.sqlalchemy.org/en/20/tutorial/metadata.html
> https://www.prisma.io/docs/orm/prisma-migrate
