# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base (runtime-only PHP + PDO)   #
##############################################
FROM php:8.2-fpm-alpine AS php-base

WORKDIR /var/www/html

RUN apk add --no-cache \
        libzip libpng libjpeg-turbo oniguruma libxml2 icu-libs \
        postgresql-libs sqlite-libs \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS postgresql-dev sqlite-dev \
    && docker-php-ext-install \
        pdo_pgsql pdo_sqlite mbstring zip xml intl opcache \
    && docker-php-ext-enable opcache \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

##############################################
# 2. Stage: Build PHP deps (+ Xdebug)        #
##############################################
FROM php:8.2-fpm-alpine AS php-deps

WORKDIR /var/www/html

# Устанавливаем composer и Xdebug
RUN apk add --no-cache \
        curl bash git \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && apk add --no-cache --virtual .xdebug-deps $PHPIZE_DEPS \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apk del .xdebug-deps

# Сборка PHP-зависимостей
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction

COPY . .
RUN chmod -R ug+rw storage bootstrap/cache

##############################################
# 3. Stage: Build frontend (Node/Vite)       #
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

# Копируем из слоёв php-deps и frontend-build
COPY --from=php-deps /var/www/html /var/www/html
COPY --from=frontend-build /var/www/html/public/build public/build

# Запускаем миграции и оптимизации при старте
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER www-data:www-data
EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
