#!/bin/sh
set -e

# Запускаем миграции без подтверждения
php artisan migrate --force

# Запускаем встроенный сервер Laravel
php artisan serve --host=0.0.0.0 --port=10000