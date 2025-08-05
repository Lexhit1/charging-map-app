# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base (runtime-only PHP)         #
##############################################
FROM php:8.2-fpm-alpine AS php-base

WORKDIR /var/www/html

# Install only runtime libraries and enable OPCache
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

##############################################
# 2. Stage: Build PHP dependencies (+ Xdebug)#
##############################################
FROM php:8.2-fpm-alpine AS php-deps

WORKDIR /var/www/html

# Install build tools, headers, PHP extensions and Xdebug, then clean up
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
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        mbstring \
        zip \
        xml \
        intl \
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

# Install PHP dependencies (production)
COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-scripts \
        --prefer-dist \
        --no-interaction

# Copy application code
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

# Copy PHP application (without Xdebug)
COPY --from=php-deps /var/www/html /var/www/html

# Copy frontend build artifacts
COPY --from=frontend-build /var/www/html/public/build public/build

# Disable Xdebug in final image
RUN docker-php-ext-disable xdebug || true

# Laravel optimization
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && chmod -R 755 bootstrap/cache storage

# Entrypoint and permissions
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER www-data:www-data

EXPOSE 10000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]