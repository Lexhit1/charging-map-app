# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base (runtime-only PHP)         #
##############################################
FROM php:8.2-fpm-alpine AS php-base

WORKDIR /var/www/html

# Устанавливаем только runtime-библиотеки и PHP-расширения
RUN apk add --no-cache \
        libzip \
        libpng \
        libjpeg-turbo \
        oniguruma \
        libxml2 \
        postgresql-libs \
        sqlite-libs \
        pkgconfig \
    && apk add --no-cache --virtual .phpize-deps \
        postgresql-dev \
        sqlite-dev \
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        zip \
        xml \
        intl \
        opcache \
    && docker-php-ext-enable opcache \
    && apk del .phpize-deps \
    && rm -rf /var/cache/apk/*

##############################################
# 2. Stage: Build PHP dependencies (+ Xdebug)#
##############################################
FROM php:8.2-fpm-alpine AS php-deps

WORKDIR /var/www/html

# Устанавливаем build-инструменты для сборки PECL-модулей
RUN apk add --no-cache \
        autoconf \
        build-base \
        linux-headers \
        icu-dev \
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
        bash \
        git \
        curl \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del \
        autoconf \
        build-base \
        linux-headers \
        icu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        oniguruma-dev \
        libxml2-dev \
        postgresql-dev \
        sqlite-dev \
        libedit-dev \
        pkgconfig \
    && rm -rf /var/cache/apk/*

# Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Устанавливаем PHP-зависимости
COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-scripts \
        --prefer-dist \
        --no-interaction

# Копируем приложение
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
FROM php-base AS runtime

WORKDIR /var/www/html

# Копируем PHP-приложение из php-deps (без Xdebug)
COPY --from=php-deps /var/www/html /var/www/html

# Копируем фронтенд-сборку
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug на всякий случай
RUN docker-php-ext-disable xdebug || true

# Laravel optimization
RUN php artisan config:cache \
 && php artisan route:cache \
 && php artisan view:cache \
 && chmod -R 755 bootstrap/cache storage

# Точка входа и права
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER www-data:www-data

EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["serve"]