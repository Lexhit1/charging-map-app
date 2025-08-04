# syntax=docker/dockerfile:1

##############################################
# 1. Stage: builder                        #
##############################################
FROM debian:12.6 AS builder

# Устанавливаем базовые пакеты и инструменты сборки
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential ca-certificates curl git unzip \
      libssl-dev libzip-dev libpq-dev libpng-dev libxml2-dev \
      libonig-dev pkg-config autoconf libtool \
      zlib1g-dev libjpeg62-turbo-dev libfreetype6-dev \
      libgmp-dev libcurl4-gnutls-dev libicu-dev \
      libtidy-dev libxslt1-dev libevent-dev \
      xz-utils fontconfig locales && \
    locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PHP_VERSION=8.2.0

# Скачиваем, собираем и устанавливаем PHP
WORKDIR /usr/src/php
RUN curl -SL "https://www.php.net/distributions/php-$PHP_VERSION.tar.xz" -o php.tar.xz && \
    tar -xf php.tar.xz --strip-components=1 && \
    ./configure \
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
      --enable-bcmath && \
    make -j"$(nproc)" && \
    make install && \
    make clean

# Устанавливаем Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Копируем приложение и устанавливаем PHP-зависимости
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

# Устанавливаем Node.js и npm

FROM node:22 AS frontend-builder
WORKDIR /var/www/html
COPY package*.json vite.config.js ./
RUN npm ci
COPY resources/js resources/js
RUN npm run build

# Копируем фронтенд-код и устанавливаем npm-зависимости, создаём билд

COPY package.json package-lock.json ./
RUN npm ci

COPY resources/js resources/js
COPY vite.config.js ./
RUN npm run build

##############################################
# 2. Stage: runtime                        #
##############################################
FROM debian:12.6 AS runtime

# Устанавливаем рантайм-зависимости
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates libpq5 libpng16-16 libxml2 \
      libonig5 libzip4 libicu72 tzdata && \
    rm -rf /var/lib/apt/lists/*

# Создаём пользователя для запуска приложения
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /var/www/html

# Копируем из builder всё содержимое приложения и собранный фронтенд
COPY --from=builder /usr/local/bin/php /usr/local/bin/php
COPY --from=builder /usr/local/lib/php /usr/local/lib/php
COPY --from=builder /usr/bin/composer /usr/bin/composer
COPY --from=builder /var/www/html /var/www/html

# Меняем владельца файлов на неопределённого пользователя
RUN chown -R app:app /var/www/html

USER app

# Expose порт и точка входа
EXPOSE 9000
CMD ["php-fpm", "-F"]
