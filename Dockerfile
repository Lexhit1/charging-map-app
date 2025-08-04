# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP build                        #
##############################################
FROM debian:12.6 AS php-builder

# Устанавливаем системные и сборочные зависимости
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential ca-certificates curl git unzip \
    libssl-dev libzip-dev libpng-dev libxml2-dev \
    libonig-dev pkg-config autoconf libtool \
    zlib1g-dev libjpeg62-turbo-dev libfreetype6-dev \
    libgmp-dev libcurl4-gnutls-dev libicu-dev \
    libtidy-dev libxslt1-dev libevent-dev \
    xz-utils fontconfig locales \
    sqlite3 libsqlite3-dev \
    postgresql-server-dev-all \
 && locale-gen en_US.UTF-8 \
 && update-ca-certificates

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PHP_VERSION=8.2.0

WORKDIR /usr/src/php

# Скачиваем и собираем PHP из исходников
RUN curl -SL "https://www.php.net/distributions/php-$PHP_VERSION.tar.xz" -o php.tar.xz \
 && tar -xf php.tar.xz --strip-components=1 \
 && ./configure \
      --prefix=/usr/local \
      --with-pdo-pgsql=shared \
      --with-pgsql=shared \
      --with-openssl \
      --enable-mbstring \
      --with-zlib \
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

# Копируем PHP-приложение и устанавливаем зависимости
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

##############################################
# 2. Stage: frontend build                   #
##############################################
FROM node:22 AS frontend-builder

WORKDIR /var/www/html

# Копируем package-файлы и заранее картинки для иконок
COPY package.json package-lock.json vite.config.js ./
RUN npm ci

# Копируем ресурсы и собираем финальную фронтенд-версию
COPY resources/js resources/js
COPY resources/css resources/css
COPY resources/img resources/img
RUN npm run build

##############################################
# 3. Stage: runtime                          #
##############################################
FROM debian:12.6 AS runtime

# Только рантайм-зависимости
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates libpq5 libpng16-16 libxml2 \
      libonig5 libzip4 libicu72 tzdata \
 && rm -rf /var/lib/apt/lists/*

# Создаём непривилегированного пользователя
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /var/www/html

# Копируем PHP-движок, Composer и приложение из билдера
COPY --from=php-builder /usr/local/bin/php /usr/local/bin/php
COPY --from=php-builder /usr/local/lib/php /usr/local/lib/php
COPY --from=php-builder /usr/bin/composer /usr/bin/composer
COPY --from=php-builder /var/www/html /var/www/html

# Копируем собранный фронтенд
COPY --from=frontend-builder /var/www/html/public/build public/build

# Прав на папки и запуск от пользователя app
RUN chown -R app:app /var/www/html
USER app

EXPOSE 9000
CMD ["php-fpm", "-F"]