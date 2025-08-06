#!/usr/bin/env bash
set -e
php artisan migrate --force
exec "$@"