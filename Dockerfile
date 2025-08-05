# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base (PHP + Composer)           #
##############################################
FROM php:8.2-fpm-alpine AS php-base

# Установка системных библиотек и PHP-расширений
RUN apk add --no-cache \
        bash \
        git \
        curl \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        oniguruma-dev \
        libxml2-dev \
        postgresql-dev \
        sqlite-dev \
        libedit-dev \
        pkgconfig \
        zip \
        unzip \
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        mbstring \
        zip \
        xml \
        intl \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug

# Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html

##############################################
# 2. Stage: Build PHP dependencies          #
##############################################
FROM php-base AS php-deps

# Кешируем только файлы composer
COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-scripts \
        --prefer-dist \
        --no-interaction

# Копируем проект и настраиваем права
COPY . .
RUN chmod -R ug+rw storage bootstrap/cache

##############################################
# 3. Stage: Build frontend assets            #
##############################################
FROM node:22-alpine AS frontend-build

WORKDIR /var/www/html

COPY package.json package-lock.json vite.config.js ./
RUN npm ci --ignore-scripts
COPY resources resources
RUN npm run build

##############################################
# 4. Stage: Final runtime image              #
##############################################
FROM php:8.2-fpm-alpine AS runtime

# Установка только runtime-зависимостей
RUN apk add --no-cache \
        libzip \
        libpng \
        libjpeg-turbo \
        oniguruma \
        libxml2 \
        postgresql-libs \
        sqlite-libs \
    && docker-php-ext-install opcache \
    && docker-php-ext-enable opcache

WORKDIR /var/www/html

# Копируем PHP-приложение без dev-зависимостей
COPY --from=php-deps /var/www/html /var/www/html

# Копируем frontend-сборку
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug в продакшне
RUN docker-php-ext-disable xdebug

# Оптимизация Laravel
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && chmod -R 755 bootstrap/cache storage

# Точка входа и пользователь
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
USER www-data:www-data

EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
