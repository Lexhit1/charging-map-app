# 1. Stage: build
FROM php:8.2-fpm AS build

# PHP-расширения
RUN apt-get update && apt-get install -y zlib1g-dev libpng-dev libonig-dev libxml2-dev git curl \
    && docker-php-ext-install pdo_pgsql mbstring exif pcntl bcmath gd xml zip

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

# Собираем фронтенд
FROM node:18 AS frontend-build
WORKDIR /app
COPY package*.json vite.config.js ./
RUN npm ci
COPY resources/js resources/js
COPY resources/css resources/css
RUN npm run build

# 2. Stage: final
FROM php:8.2-fpm

WORKDIR /app

# Копируем PHP-часть
COPY --from=build /app /app

# Копируем фронтенд
COPY --from=frontend-build /app/public/build /app/public/build

# Права
RUN chown -R www-data:www-data /app

EXPOSE 9000
CMD ["php-fpm"]
