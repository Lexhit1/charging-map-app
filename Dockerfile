# syntax=docker/dockerfile:1

##############################################
# 1. Stage: PHP build                        #
##############################################
FROM debian:12.6 AS php-builder

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PHP_VERSION=8.2.0

# Устанавливаем сборочные зависимости и dev-пакеты
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
      libedit-dev \
      postgresql-server-dev-all \
 && locale-gen en_US.UTF-8 \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/php

# Скачиваем, конфигурируем и собираем PHP
RUN curl -SL "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz" -o php.tar.xz \
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
      --with-sqlite3 \
 && make -j"$(nproc)" \
 && make install \
 && make clean

# Устанавливаем Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

##############################################
# 2. Stage: application dependencies install #
##############################################
FROM php-builder AS app-deps

WORKDIR /var/www/html

# Копируем исходники приложения (включая artisan)
COPY . .

# Устанавливаем PHP-зависимости приложения
RUN composer install --no-dev --optimize-autoloader

##############################################
# 3. Stage: frontend build                   #
##############################################
FROM node:22 AS frontend-builder

WORKDIR /var/www/html

# Копируем package-файлы и устанавливаем JS-зависимости
COPY package.json package-lock.json vite.config.js ./
RUN npm ci

# Копируем ресурсы и собираем фронтенд
COPY resources/js resources/js
COPY resources/css resources/css
COPY resources/img resources/img
RUN npm run build

##############################################
# 4. Stage: runtime                          #
##############################################
FROM debian:12.6 AS runtime

# Устанавливаем лишь рантайм-зависимости
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates libpq5 libpng16-16 libxml2 \
      libonig5 libzip4 libicu72 tzdata \
 && rm -rf /var/lib/apt/lists/*

# Создаём непривилегированного пользователя
RUN useradd -M -d /home/app -s /usr/sbin/nologin app

WORKDIR /var/www/html

# Копируем PHP бинарь и библиотеки из этапа сборки
COPY --from=php-builder /usr/local/bin/php /usr/local/bin/php
COPY --from=php-builder /usr/local/lib/php /usr/local/lib/php
COPY --from=php-builder /usr/bin/composer /usr/bin/composer

# Копируем установленные зависимости и исходники приложения
COPY --from=app-deps /var/www/html /var/www/html

# Копируем фронтенд-билд
COPY --from=frontend-builder /var/www/html/public/build public/build

# Устанавливаем права и переключаемся на непривилегированного юзера
RUN chown -R app:app /var/www/html
USER app

EXPOSE 9000
CMD ["php-fpm", "-F"]