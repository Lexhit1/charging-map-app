#!/usr/bin/env bash

set -e

echo "Running composer"
composer install --no-dev --working-dir=/var/www/html

echo "Caching config..."
php artisan config:cache

echo "Caching routes..."
php artisan route:cache

echo "Resetting migrations (drops all tables)..."
php artisan migrate:reset --force

echo "Running migrations..."
php artisan migrate --force

echo "Deployment script completed successfully."
