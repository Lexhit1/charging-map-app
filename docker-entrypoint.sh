#!/bin/sh
set -e

# Ждём готовности базы
until php artisan migrate:status > /dev/null 2>&1; do
  echo "Waiting for database..."
  sleep 2
done

# Запускаем миграции
php artisan migrate --force

# Запускаем основную команду
exec "$@"