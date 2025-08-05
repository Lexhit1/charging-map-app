# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP + Composer                  #
##############################################
FROM php:8.2-fpm AS php-base

# Устанавливаем рабочую директорию
WORKDIR /var/www/html

# Устанавливаем системные зависимости для PHP-расширений
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         libzip-dev libpng-dev libjpeg-dev libonig-dev libxml2-dev \
         zip unzip git curl \
         libpq-dev sqlite3 pkg-config libsqlite3-dev libedit-dev \
    && docker-php-ext-install \
         pdo_pgsql \
         pdo_sqlite \
         mbstring \
         zip \
         xml \
         intl \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && rm -rf /var/lib/apt/lists/*

# Копируем бинарь Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

##############################################
# 2. Stage: Install PHP dependencies         #
##############################################
FROM php-base AS php-deps

WORKDIR /var/www/html

# Копируем только файлы composer и устанавливаем зависимости без скриптов
COPY composer.json composer.lock ./
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-scripts \
    --no-interaction

# Копируем весь остальной код приложения
COPY . .

##############################################
# 3. Stage: Build frontend assets            #
##############################################
FROM node:22 AS frontend-build

WORKDIR /var/www/html

# Копируем package-файлы и устанавливаем npm-зависимости
COPY package.json package-lock.json vite.config.js ./
RUN npm ci

# Копируем исходники фронтенда и собираем ассеты
COPY resources resources
RUN npm run build

##############################################
# 4. Stage: Final runtime image              #
##############################################
FROM php-base AS runtime

WORKDIR /var/www/html

# Копируем собранное PHP-приложение с зависимостями
COPY --from=php-deps /var/www/html /var/www/html
COPY --from=php-deps /usr/local/bin/php /usr/local/bin/php
COPY --from=php-deps /usr/local/lib/php /usr/local/lib/php
COPY --from=php-deps /usr/bin/composer /usr/bin/composer

# Копируем собранный фронтенд
COPY --from=frontend-build /var/www/html/public/build public/build

# Копируем entrypoint и делаем его исполняемым
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Устанавливаем права на директорию приложения
RUN chown -R www-data:www-data /var/www/html

# Порт PHP-FPM
EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]