# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Build PHP with extensions         #
##############################################
FROM php:8.2-fpm-alpine AS php-deps

# Устанавливаем build-зависимости + runtime-библиотеки
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
        bash \
        git \
        curl \
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        mbstring \
        zip \
        xml \
        intl \
        opcache \
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
    && rm -rf /var/cache/apk/*

WORKDIR /var/www/html

# Composer без dev-зависимостей
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-interaction

# Копируем весь код и настраиваем права
COPY . .
RUN chmod -R ug+rw storage bootstrap/cache

##############################################
# 2. Stage: Build frontend assets            #
##############################################
FROM node:22-alpine AS frontend-build

WORKDIR /var/www/html
COPY package.json package-lock.json vite.config.js ./
RUN npm ci --ignore-scripts
COPY resources resources
RUN npm run build

##############################################
# 3. Stage: Final runtime image              #
##############################################
FROM php:8.2-fpm-alpine AS php-base

# Устанавливаем только runtime-библиотеки
RUN apk add --no-cache \
        libzip \
        libpng \
        libjpeg-turbo \
        oniguruma \
        libxml2 \
        icu-libs \
        postgresql-libs \
        sqlite-libs

WORKDIR /var/www/html

# Копируем PHP-приложение из php-deps (включая собранные расширения)
COPY --from=php-deps /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=php-deps /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=php-deps /var/www/html /var/www/html

# Копируем фронтенд-сборку
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug в рантайме
RUN docker-php-ext-disable xdebug || true

# Laravel-кэширование и права
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