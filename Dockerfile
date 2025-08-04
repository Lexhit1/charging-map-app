# syntax=docker/dockerfile:1

##############################################
# 1. Stage: php-build                       #
##############################################
FROM php:8.2-fpm AS php-build

# Установка системных зависимостей и PHP-расширений
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y \
       git curl zlib1g-dev libpng-dev libonig-dev libxml2-dev \
       libzip-dev libicu-dev libxslt1-dev libpq-dev \
  && docker-php-ext-install \
       pdo_pgsql mbstring exif pcntl bcmath gd xml zip intl xsl \
  && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader \
  && rm -rf ~/.composer/cache

##############################################
# 2. Stage: node-build                      #
##############################################
FROM node:22 AS node-build

WORKDIR /app

# Копируем только package-файлы и конфиг Vite
COPY package.json package-lock.json vite.config.js ./
COPY resources/js resources/css resources/img ./resources
# Устанавливаем зависимости и собираем фронтенд
RUN npm ci
RUN npm run build

##############################################
# 3. Stage: runtime                          #
##############################################
FROM php:8.2-fpm AS runtime

# Установка рантайм-зависимостей (меньше размеров)
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y \
       libpng16-16 libonig5 libxml2 libzip4 libicu72 libxslt1.1 \
       libpq5 \
  && rm -rf /var/lib/apt/lists/*

# Создаём пользователя (необязательно)
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /app

# Копируем PHP-приложение и зависимости
COPY --from=php-build /app /app
COPY --from=php-build /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=php-build /usr/local/bin/php /usr/local/bin/php
COPY --from=php-build /usr/local/lib/php /usr/local/lib/php
COPY --from=php-build /usr/bin/composer /usr/bin/composer

# Копируем собранный фронтенд
COPY --from=node-build /app/public/build /app/public/build

# Права
RUN chown -R www-data:www-data /app

USER www-data

EXPOSE 9000
CMD ["php-fpm", "-F"]
