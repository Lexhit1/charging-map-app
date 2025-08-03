#!/usr/bin/env bash
set -e

# Строка подключения к базе на Render.com
PSQL="psql 'postgresql://charging_map_user:fWLDAhjj4axZlfx2RTe1sTFF3OyDs1uP@dpg-d26j47juibrs739va4t0-a.frankfurt-postgres.render.com/charging_map_db'"

echo "Running composer"
composer install --no-dev --working-dir=/var/www/html

echo "Caching config..."
php artisan config:cache

echo "Caching routes..."
php artisan route:cache

echo "Activating PostGIS extensions..."
$PSQL -c "CREATE EXTENSION IF NOT EXISTS postgis;"
$PSQL -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;"
$PSQL -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"
echo "--- PostGIS version:"
$PSQL -c "SELECT PostGIS_Version();"

echo "Resetting migrations (drops all tables)..."
php artisan migrate:reset --force

echo "Running migrations..."
php artisan migrate --force

echo "Deployment script completed successfully."