# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base (PHP + Composer)           #
##############################################
FROM php:8.2-fpm-alpine AS php-base

ENV COMPOSER_ALLOW_SUPERUSER=1
WORKDIR /var/www/html

# Устанавливаем build-зависимости и runtime-библиотеки
RUN apk add --no-cache \
        # build tools для phpize и pecl
        autoconf \
        build-base \
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
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        mbstring \
        zip \
        xml \
        intl \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    # устанавливаем Composer
    && wget -qO /usr/local/bin/composer https://getcomposer.org/composer-stable.phar \
    && chmod +x /usr/local/bin/composer \
    # очищаем кеш apk и build-зависимости (кроме runtime libs)
    && apk del \
        autoconf \
        build-base \
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

##############################################
# 2. Stage: Build PHP dependencies          #
##############################################
FROM php-base AS php-deps

WORKDIR /var/www/html

# Копируем и устанавливаем PHP-зависимости
COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-scripts \
        --prefer-dist \
        --no-interaction

# Копируем исходники приложения
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

WORKDIR /var/www/html

# Устанавливаем только необходимые runtime-библиотеки
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

# Копируем PHP-приложение и Laravel-кеш
COPY --from=php-deps /var/www/html /var/www/html

# Копируем фронтенд-сборку
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug в продакшне
RUN docker-php-ext-disable xdebug

# Генерируем Laravel-оптимизации на этапе сборки
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
CMD ["php-fpm"]