# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP build                        #
##############################################
FROM debian:12.6 AS php-builder

# Сборочные зависимости для PHP и расширений
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential ca-certificates curl git unzip \
    autoconf libtool pkg-config xz-utils \
    locales fontconfig \
    libssl-dev libzip-dev libpng-dev libjpeg62-turbo-dev \
    libxml2-dev libonig-dev zlib1g-dev \
    libicu-dev libxslt1-dev libtidy-dev libevent-dev \
    libgmp-dev libcurl4-gnutls-dev \
    sqlite3 libsqlite3-dev \
    postgresql-server-dev-all \
 && locale-gen en_US.UTF-8 \
 && update-ca-certificates

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PHP_VERSION=8.2.0

WORKDIR /usr/src/php

# Скачиваем, конфигурируем и собираем PHP
RUN curl -SL "https://www.php.net/distributions/php-$PHP_VERSION.tar.xz" -o php.tar.xz \
 && tar -xf php.tar.xz --strip-components=1 \
 && ./configure \
      --prefix=/usr/local \
      --with-pdo-pgsql=shared \
      --with-pgsql=shared \
      --with-openssl \
      --enable-mbstring \
      --enable-fpm \
      --with-curl \
      --with-zip \
      --with-libedit \
      --enable-intl \
      --with-xsl \
      --enable-soap \
      --enable-bcmath \
      --enable-sqlite3 \
 && make -j"$(nproc)" \
 && make install \
 && make clean

# Устанавливаем Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Устанавливаем PHP-зависимости приложения
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

##############################################
# 2. Stage: frontend build                   #
##############################################
FROM node:22 AS frontend-builder

WORKDIR /var/www/html

# Устанавливаем JS-зависимости
COPY package.json package-lock.json vite.config.js ./
RUN npm ci

# Собираем ресурсы
COPY resources/js resources/js
COPY resources/css resources/css
COPY resources/img resources/img
RUN npm run build

##############################################
# 3. Stage: runtime                          #
##############################################
FROM debian:12.6 AS runtime

# Рантайм-зависимости
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates libpq5 libpng16-16 libxml2 \
      libonig5 libzip4 libicu72 tzdata \
 && rm -rf /var/lib/apt/lists/*

# Создаём непривилегированного пользователя
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /var/www/html

# Копируем PHP-исполняемый файл, библиотеки и приложение
COPY --from=php-builder /usr/local/bin/php /usr/local/bin/php
COPY --from=php-builder /usr/local/lib/php /usr/local/lib/php
COPY --from=php-builder /usr/bin/composer /usr/bin/composer
COPY --from=php-builder /var/www/html /var/www/html

# Копируем фронтенд-билд
COPY --from=frontend-builder /var/www/html/public/build public/build

RUN chown -R app:app /var/www/html
USER app

EXPOSE 9000
CMD ["php-fpm", "-F"]