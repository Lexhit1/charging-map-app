# syntax=docker/dockerfile:1

##############################################
# 1. Stage: Сборка PHP-приложения и зависимостей
##############################################
FROM php:8.2-fpm-alpine AS php_app

WORKDIR /var/www/html

# Устанавливаем системные зависимости и расширения
RUN apk add --no-cache \
    git \
    unzip \
    libxml2-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    postgresql-dev \
    sqlite-dev \
    pkgconfig \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install \
    pdo_pgsql \
    pdo_sqlite \
    mbstring \
    zip \
    xml \
    intl \
    gd \
    opcache \
  && docker-php-ext-enable opcache

# Копируем исходники приложения
COPY . .

# Устанавливаем зависимости через Composer
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Настраиваем права для storage и cache
RUN chown -R www-data:www-data /var/www/html \
  && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Экспонируем порт PHP-FPM
EXPOSE 9000

CMD ["php-fpm"]

##############################################
# 2. Stage: Nginx для отдачи статики и proxy
##############################################
FROM nginx:alpine AS nginx_app

# Удаляем дефолтный конфиг
RUN rm /etc/nginx/conf.d/default.conf

# Копируем свой конфиг
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Копируем сгенерированные файлы приложения из php_app
COPY --from=php_app /var/www/html /var/www/html

# Экспонируем HTTP-порт
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]