# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP + Composer                  #
##############################################
FROM php:8.2-fpm AS php-base

WORKDIR /var/www/html

# Устанавливаем системные зависимости для PHP-расширений
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libzip-dev libpng-dev libjpeg-dev libonig-dev libxml2-dev \
        zip unzip git curl \
        libpq-dev libedit-dev \
        sqlite3 pkg-config libsqlite3-dev \
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

# Устанавливаем Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

##############################################
# 2. Stage: Dependencies install             #
##############################################
FROM php-base AS php-deps

WORKDIR /var/www/html

# Копируем весь код приложения до установки зависимостей,
# чтобы composer мог считать пути к artisan и прочим файлам
COPY composer.json composer.lock ./
COPY . .

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction

##############################################
# 3. Stage: Frontend build                   #
##############################################
FROM node:22 AS frontend-build

WORKDIR /var/www/html

COPY package.json package-lock.json vite.config.js ./
RUN npm ci

COPY resources resources
RUN npm run build

##############################################
# 4. Stage: Final runtime                    #
##############################################
FROM php:8.2-fpm AS runtime

WORKDIR /var/www/html

# Копируем PHP, зависимости и код
COPY --from=php-deps /var/www/html /var/www/html

# Копируем собранный фронтенд
COPY --from=frontend-build /var/www/html/public/build public/build

# Устанавливаем права
RUN chown -R www-data:www-data /var/www/html

EXPOSE 9000
CMD ["php-fpm"]