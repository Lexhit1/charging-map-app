# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base (runtime-only PHP)         #
##############################################
FROM php:8.2-fpm-alpine AS php-base

WORKDIR /var/www/html

# Устанавливаем runtime-библиотеки и расширения, включая dev-пакеты для сборки PDO
RUN apk add --no-cache \
        libzip \
        libpng \
        libjpeg-turbo \
        oniguruma \
        libxml2 \
        icu-libs \
        postgresql-libs \
        sqlite-libs \
        pkgconfig \
        sqlite-dev \
        postgresql-dev \
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        mbstring \
        zip \
        xml \
        intl \
        opcache \
    && docker-php-ext-enable opcache \
    && apk del sqlite-dev postgresql-dev pkgconfig \
    && rm -rf /var/cache/apk/*

##############################################
# 2. Stage: Build PHP dependencies (+ Xdebug)#
##############################################
FROM php:8.2-fpm-alpine AS php-deps

WORKDIR /var/www/html

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

COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-scripts \
        --prefer-dist \
        --no-interaction

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

# Копируем собранное PHP-приложение и фронтенд
COPY --from=php-deps /var/www/html /var/www/html
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug и оптимизируем Laravel
RUN docker-php-ext-disable xdebug || true \
  && php artisan config:cache \
  && php artisan route:cache \
  && php artisan view:cache \
  && chmod -R 755 bootstrap/cache storage

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
USER www-data:www-data

EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
