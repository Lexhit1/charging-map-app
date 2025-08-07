#!/bin/sh
set -e

# Если нет .env — копируем шаблон
[ ! -f .env ] && cp .env.example .env

# Миграции и симлинк для storage
php artisan migrate --force
php artisan storage:link

# Запускаем PHP-FPM
exec "$@"
