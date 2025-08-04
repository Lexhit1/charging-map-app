# syntax=docker/dockerfile:1
##############################################
# 1. Stage: builder (PHP + Composer)        #
##############################################
FROM php:8.2-fpm AS php-builder

# Системные зависимости, расширения PHP и Composer
RUN apt-get update \
 && apt-get install -y \
      libpq-dev libzip-dev zlib1g-dev libpng-dev libxml2-dev libonig-dev \
      git curl unzip \
 && docker-php-ext-install pdo_pgsql mbstring exif pcntl bcmath gd xml zip \
 && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

##############################################
# 2. Stage: builder (Node + Vite build)      #
##############################################
FROM node:18-alpine AS node-builder

WORKDIR /var/www/html

# Копируем фронтенд-конфиги и зависимости
COPY package.json package-lock.json vite.config.js ./
RUN npm ci

# Копируем исходники и собираем статику
COPY resources/js resources/js
COPY resources/css resources/css
RUN npm run build

##############################################
# 3. Stage: production runtime               #
##############################################
FROM php:8.2-fpm

# Устанавливаем runtime-зависимости
RUN apt-get update \
 && apt-get install -y \
      libpq5 libzip4 libpng16-16 libxml2 libonig5 tzdata \
 && rm -rf /var/lib/apt/lists/*

# Копируем PHP и статику
WORKDIR /var/www/html
COPY --from=php-builder /usr/local/etc/php /usr/local/etc/php
COPY --from=php-builder /usr/local/bin/php /usr/local/bin/php
COPY --from=php-builder /usr/bin/composer /usr/bin/composer
COPY --from=php-builder /var/www/html /var/www/html
COPY --from=node-builder /var/www/html/public/build public/build

# Права
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]
