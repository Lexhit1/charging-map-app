# 1. Базовый образ с PHP 8.2
FROM php:8.2-fpm

# 2. Системные зависимости и psql
RUN apt-get update && apt-get install -y \
    libpq-dev \
    postgresql-client \
    git \
    unzip \
    curl \
    zip \
    nodejs \
    npm \
  && docker-php-ext-install pdo_pgsql \
  && rm -rf /var/lib/apt/lists/*

# 3. Устанавливаем Composer (копируем из оф. образа)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 4. Рабочая директория
WORKDIR /var/www/html

# 5. Копируем код проекта
COPY . .

# 6. Устанавливаем PHP-зависимости
RUN composer install --no-dev --optimize-autoloader

# 7. Собираем фронтенд (Vite)
RUN npm ci
RUN npm run build

# 8. Кэшируем Laravel-конфигурацию и маршруты
RUN php artisan config:cache
RUN php artisan route:cache

# 9. Активируем PostGIS прямо в контейнере
#    Задайте PGPASSWORD через ENV, чтобы psql считал пароль
ENV PGPASSWORD="fWLDAhjj4axZlfx2RTe1sTFF3OyDs1uP"
#    Выполняем CREATE EXTENSION
RUN psql -h dpg-d26j47juibrs739va4t0-a.frankfurt-postgres.render.com \
         -U charging_map_user \
         -d charging_map_db \
         -c "CREATE EXTENSION IF NOT EXISTS postgis;"
RUN psql -h dpg-d26j47juibrs739va4t0-a.frankfurt-postgres.render.com \
         -U charging_map_user \
         -d charging_map_db \
         -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;"
RUN psql -h dpg-d26j47juibrs739va4t0-a.frankfurt-postgres.render.com \
         -U charging_map_user \
         -d charging_map_db \
         -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"

# 10. Сбрасываем и применяем все миграции
RUN php artisan migrate:reset --force
RUN php artisan migrate --force

# 11. Права и запуск
RUN chown -R www-data:www-data /var/www/html
CMD ["php-fpm"]

