# syntax=docker/dockerfile:1

##############################################
# 1. Stage: builder_php
##############################################
FROM debian:12.6 AS builder_php

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PHP_VERSION=8.2.0

# 1.1 Устанавливаем зависимости для сборки PHP (включая sqlite3-dev)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential ca-certificates curl git unzip \
      libssl-dev libzip-dev libpq-dev libpng-dev libxml2-dev \
      libonig-dev pkg-config autoconf libtool \
      zlib1g-dev libjpeg62-turbo-dev libfreetype6-dev \
      libgmp-dev libcurl4-gnutls-dev libicu-dev \
      libtidy-dev libxslt1-dev libevent-dev \
      xz-utils fontconfig locales sqlite3 libsqlite3-dev && \
    locale-gen en_US.UTF-8 && \
    update-ca-certificates

WORKDIR /usr/src/php

# 1.2 Скачиваем и собираем PHP с нужными расширениями
RUN curl -SL "https://www.php.net/distributions/php-$PHP_VERSION.tar.xz" -o php.tar.xz && \
    tar -xf php.tar.xz --strip-components=1 && \
    ./configure \
      --prefix=/usr/local \
      --with-pdo-pgsql=shared \
      --with-pgsql=shared \
      --with-openssl \
      --enable-mbstring \
      --with-zlib \
      --with-curl \
      --with-libedit \
      --enable-intl \
      --with-xsl \
      --enable-soap \
      --enable-bcmath && \
    make -j"$(nproc)" && \
    make install && \
    make clean

# 1.3 Устанавливаем Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# 1.4 Копируем PHP-приложение и устанавливаем зависимости
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

##############################################
# 2. Stage: builder_node
##############################################
FROM node:22-bullseye AS builder_node

WORKDIR /var/www/html

# 2.1 Копируем package-файлы и устанавливаем зависимости
COPY package.json package-lock.json vite.config.js ./
RUN npm ci

# 2.2 Копируем исходники фронтенда и делаем билд
COPY resources/js resources/js
COPY resources/css resources/css
RUN npm run build

##############################################
# 3. Stage: runtime
##############################################
FROM debian:12.6 AS runtime

# 3.1 Устанавливаем рантайм-зависимости
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates libpq5 libpng16-16 libxml2 \
      libonig5 libzip4 libicu72 tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    update-ca-certificates

# 3.2 Создаём пользователя
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /var/www/html

# 3.3 Копируем всё из builder_php и скомпилированный фронтенд
COPY --from=builder_php /usr/local/bin/php /usr/local/bin/php
COPY --from=builder_php /usr/local/lib/php /usr/local/lib/php
COPY --from=builder_php /usr/bin/composer /usr/bin/composer
COPY --from=builder_php /var/www/html /var/www/html
COPY --from=builder_node /var/www/html/public/build /var/www/html/public/build

# 3.4 Устанавливаем правильные права
RUN chown -R app:app /var/www/html

USER app

EXPOSE 9000
CMD ["php-fpm", "-F"]