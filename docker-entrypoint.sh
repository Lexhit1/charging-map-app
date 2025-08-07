#!/bin/sh

if [ ! -f .env ]; then
    cp .env.example .env
fi

php artisan migrate --force
php artisan storage:link

exec "$@"
