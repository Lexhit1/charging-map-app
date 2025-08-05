# ───────────────────────────────────────────────────────────────
# Этап 1. Собираем PHP-базу с Xdebug для девелопмента
# ───────────────────────────────────────────────────────────────
FROM php:8.1-fpm AS php-base

# Устанавливаем системные зависимости, Composer и PECL для Xdebug
RUN apt-get update && apt-get install -y \
        git \
        unzip \
        libzip-dev \
        zip \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-install zip pdo pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# ───────────────────────────────────────────────────────────────
# Этап 2. Устанавливаем PHP-зависимости
# ───────────────────────────────────────────────────────────────
FROM php-base AS php-deps

# Копируем только файлы зависимостей для быстрого билд-кеша
COPY composer.json composer.lock ./

# Устанавливаем зависимости через Composer
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

# Копируем весь проект
COPY . .

# Корректируем права
RUN chmod -R 755 /var/www/html

# ───────────────────────────────────────────────────────────────
# Этап 3. Собираем фронтенд (например, Vue/React)
# ───────────────────────────────────────────────────────────────
FROM node:18-alpine AS frontend-build

WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/. .
RUN npm run build

# ───────────────────────────────────────────────────────────────
# Этап 4. Финальный образ без Xdebug
# ───────────────────────────────────────────────────────────────
FROM php:8.1-fpm AS runtime

# Копируем PHP-код и автозагрузчик
COPY --from=php-deps /var/www/html /var/www/html

# Копируем собранный фронтенд в папку public (при необходимости)
COPY --from=frontend-build /app/dist /var/www/html/public

WORKDIR /var/www/html

# Удаляем Xdebug из финального образа (disable)
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Копируем скрипт точки входа
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]