# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP + Composer                  #
##############################################
FROM php:8.2-fpm AS php-base

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         libzip-dev libpng-dev libjpeg-dev libonig-dev libxml2-dev \
         zip unzip git curl \
         libpq-dev libedit-dev sqlite3 pkg-config libsqlite3-dev \
    && docker-php-ext-install pdo_pgsql pdo_sqlite mbstring zip xml intl \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

##############################################
# 2. Stage: Install PHP dependencies         #
##############################################
FROM php-base AS php-deps

WORKDIR /var/www/html

COPY composer.json composer.lock ./
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

COPY . .

RUN chmod -R ug+rw storage bootstrap/cache

##############################################
# 3. Stage: Build frontend assets            #
##############################################
FROM node:22 AS frontend-build

WORKDIR /var/www/html

COPY package.json package-lock.json vite.config.js ./
RUN npm ci

COPY resources resources
RUN npm run build

##############################################
# 4. Stage: Final runtime image              #
##############################################
FROM php-base AS runtime

WORKDIR /var/www/html

COPY --from=php-deps /var/www/html /var/www/html
COPY --from=php-deps /usr/local/bin/php /usr/local/bin/php
COPY --from=php-deps /usr/local/lib/php /usr/local/lib/php
COPY --from=php-deps /usr/bin/composer /usr/bin/composer

COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug в финальном образе
RUN docker-php-ext-disable xdebug

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN chown -R www-data:www-data /var/www/html

EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]