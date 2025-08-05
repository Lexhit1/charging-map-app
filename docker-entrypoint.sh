#!/usr/bin/env bash
set -e

# Пример динамической подстановки переменных окружения
: "${APP_ENV:=production}"
export APP_ENV

# При необходимости запустите миграции, seed, сборку кеша и т.п.
# php artisan migrate --force
# php artisan config:cache
# php artisan route:cache

# Запуск PHP-FPM
exec "$@"