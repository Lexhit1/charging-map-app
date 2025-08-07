#!/bin/sh
set -e

# Пропускаем миграции при старте
php artisan migrate --force

# Создаем симлинк для публичных загружаемых файлов
php artisan storage:link

# Если аргумент CMD равен "serve", запускаем встроенный сервер Laravel
if [ "$1" = 'serve' ]; then
  exec php artisan serve --host=0.0.0.0 --port=10000
else
  exec "$@"
fi