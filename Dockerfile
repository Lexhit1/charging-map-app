# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Base image (runtime PHP)         #
##############################################
FROM php:8.2-fpm-alpine AS php-base

# Устанавливаем runtime-библиотеки и PHP-расширения
RUN apk add --no-cache \
        libzip \
        libpng \
        libjpeg-turbo \
        oniguruma \
        libxml2 \
        icu-libs \
        postgresql-libs \
        sqlite-libs \
    && docker-php-ext-install \
        pdo_pgsql \
        pdo_sqlite \
        zip \
        xml \
        intl \
        opcache \
    && docker-php-ext-enable opcache

WORKDIR /var/www/html

##############################################
# 2. Stage: Dependencies (composer + Xdebug) #
##############################################
FROM php:8.2-fpm-alpine AS php-deps

WORKDIR /var/www/html

# Устанавливаем build-зависимости для компиляции расширений
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
        pkgconfig \
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
        pkgconfig \
    && rm -rf /var/cache/apk/*

# Устанавливаем Composer
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Устанавливаем PHP-зависимости
COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --optimize-autoloader \
        --no-interaction

# Копируем приложение и выставляем права
COPY . .
RUN chmod -R ug+rw storage bootstrap/cache

##############################################
# 3. Stage: Frontend build (Node.js)         #
##############################################
FROM node:22-alpine AS frontend-build

WORKDIR /var/www/html

# Устанавливаем фронтенд-зависимости
COPY package.json package-lock.json vite.config.js ./
RUN npm ci --ignore-scripts

# Собираем ассеты
COPY resources resources
RUN npm run build

##############################################
# 4. Stage: Final image (runtime)            #
##############################################
FROM php-base AS runtime

WORKDIR /var/www/html

# Копируем PHP-приложение из стадии deps (без Xdebug)
COPY --from=php-deps /var/www/html /var/www/html

# Копируем фронтенд-сборку
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключаем Xdebug на всякий случай
RUN docker-php-ext-disable xdebug || true

# Оптимизируем Laravel
RUN php artisan config:cache \
 && php artisan route:cache \
 && php artisan view:cache \
 && chmod -R 755 bootstrap/cache storage

# Добавляем точку входа
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER www-data:www-data

EXPOSE 10000
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]