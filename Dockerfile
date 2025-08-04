# syntax=docker/dockerfile:1

##############################################
# 1. Stage: builder_php
##############################################
FROM debian:12.6 AS builder_php

# Устанавливаем базовые пакеты и инструменты сборки PHP
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential ca-certificates curl git unzip \
      libssl-dev libzip-dev libpq-dev libpng-dev libxml2-dev \
      libonig-dev pkg-config autoconf libtool \
      zlib1g-dev libjpeg62-turbo-dev libfreetype6-dev \
      libgmp-dev libcurl4-gnutls-dev libicu-dev \
      libtidy-dev libxslt1-dev libevent-dev \
      xz-utils fontconfig locales sqlite3 pkg-config \
 && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PHP_VERSION=8.2.0

WORKDIR /usr/src/php
# Скачиваем и собираем PHP
RUN curl -SL "https://www.php.net/distributions/php-$PHP_VERSION.tar.xz" -o php.tar.xz \
 && tar -xf php.tar.xz --strip-components=1 \
 && ./configure \
      --prefix=/usr/local \
      --with-pdo-pgsql=shared \
      --with-pgsql=shared \
      --with-openssl \
      --enable-mbstring \
      --with-zlib \
      --enable-json \
      --enable-fpm \
      --with-curl \
      --enable-zip \
      --with-libedit \
      --enable-intl \
      --with-xsl \
      --enable-soap \
      --enable-bcmath \
 && make -j"$(nproc)" \
 && make install \
 && make clean

# Устанавливаем Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Копируем PHP-приложение и устанавливаем зависимости
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

##############################################
# 2. Stage: builder_node
##############################################
FROM node:22-bullseye AS builder_node

WORKDIR /var/www/html

# Копируем package-файлы, устанавливаем зависимости
COPY package.json package-lock.json vite.config.js ./
# добавляем crypto-browserify для поддержки crypto.hash
RUN npm install crypto-browserify --save-dev \
 && npm ci

# Копируем остальной фронтенд-код
COPY resources/js resources/js
COPY public public

# Собираем фронтенд
RUN npm run build

##############################################
# 3. Stage: runtime
##############################################
FROM debian:12.6 AS runtime

# Устанавливаем рантайм-зависимости
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates libpq5 libpng16-16 libxml2 \
      libonig5 libzip4 libicu72 tzdata \
 && rm -rf /var/lib/apt/lists/*

# Создаём пользователя для приложения
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /var/www/html

# Копируем PHP-бинарь, зависимости и собранный фронтенд
COPY --from=builder_php /usr/local/bin/php /usr/local/bin/php
COPY --from=builder_php /usr/local/lib/php /usr/local/lib/php
COPY --from=builder_php /usr/bin/composer /usr/bin/composer
COPY --from=builder_php /var/www/html /var/www/html
COPY --from=builder_node /var/www/html/dist /var/www/html/public/dist

# Устанавливаем владельца и порт
RUN chown -R app:app /var/www/html

USER app
EXPOSE 9000

# Запускаем PHP-FPM
CMD ["php-fpm", "-F"]