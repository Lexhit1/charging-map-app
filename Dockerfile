# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP base — system deps + PHP ext #
##############################################
FROM php:8.2-fpm AS php-base

WORKDIR /var/www/html

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libzip-dev libpng-dev libjpeg-dev libonig-dev libxml2-dev \
      zip unzip git curl sqlite3 pkg-config libsqlite3-dev libpq-dev libedit-dev \
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

# Install Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

##############################################
# 2. Stage: Install PHP application deps     #
##############################################
FROM php-base AS php-deps

WORKDIR /var/www/html

# Copy all application files so vendor:publish & artisan are available
COPY . .

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction

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
FROM php:8.2-fpm AS runtime

WORKDIR /var/www/html

# Runtime PHP extensions & libs if needed
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libpq5 libpng16-16 libxml2 libonig5 libzip4 libicu72 tzdata \
 && rm -rf /var/lib/apt/lists/*

# Copy application code & PHP binary + libs
COPY --from=php-deps /usr/local/bin/php /usr/local/bin/php
COPY --from=php-deps /usr/local/lib/php /usr/local/lib/php
COPY --from=php-deps /usr/bin/composer /usr/bin/composer
COPY --from=php-deps /var/www/html /var/www/html

# Copy built frontend
COPY --from=frontend-build /var/www/html/public/build public/build

# Set permissions
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]