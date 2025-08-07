\# 1\. Stage: Base PHP image with common extensions
FROM php:8\.3\-fpm\-alpine AS php\-base

\# Install PHP extensions dependencies and Composer
\# Здесь мы устанавливаем "\-dev" версии библиотек, которые нужны для компиляции PHP\-расширений\.
\# Например, "libzip\-dev" вместо "libzip" для расширения "zip"\.
RUN apk add \-\-no\-cache \\
    git \\
    curl \\
    bash \\
    \# PHP extension build dependencies:
    libzip\-dev \\       \# Для расширения 'zip'
    libpng\-dev \\       \# Для расширения 'gd'
    jpeg\-dev \\         \# Для расширения 'gd'
    oniguruma\-dev \\    \# Для расширения 'mbstring'
    libxml2\-dev \\      \# Для расширения 'xml'
    icu\-dev \\          \# Для расширения 'intl'
    postgresql\-dev \\   \# Для расширения 'pdo\_pgsql'
    sqlite\-dev \\       \# Для расширения 'pdo\_sqlite'
    mysql\-client \\     \# Для расширения 'pdo\_mysql' \(клиентская библиотека\)
    pkgconfig \\        \# Вспомогательный инструмент для компиляции
  && docker\-php\-ext\-install \\
    pdo\_mysql \\
    pdo\_pgsql \\
    pdo\_sqlite \\
    mbstring \\
    zip \\
    xml \\
    intl \\
    gd \\
    opcache \\
  && docker\-php\-ext\-enable pdo_mysql pdo_pgsql pdo\_sqlite opcache \\
  && rm \-rf /var/cache/apk/\* \\
  && curl \-sS https://getcomposer\.org/installer \| php \-\- \-\-install\-dir\=/usr/local/bin \-\-filename\=composer

\# Set working directory for all stages
WORKDIR /var/www/html

\# 2\. Stage: Install PHP dependencies \(Composer\)
FROM php\-base AS php\-deps

\# Сначала скопируйте ВСЕ файлы приложения, включая 'artisan'\.
\# Это важно, потому что 'composer install' будет запускать скрипты Laravel,
\# которым нужен файл 'artisan'\.
COPY \. \.

\# Теперь установите Composer зависимости\.
\# Файл 'artisan' теперь доступен, и скрипты Laravel могут быть выполнены\.
RUN composer install \-\-no\-dev \-\-optimize\-autoloader

\# Установите права доступа для папок storage и bootstrap/cache
RUN chmod \-R ug+rw storage bootstrap/cache

\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
\# 3\. Stage: Build frontend assets            \#
\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
FROM node:22\-alpine AS frontend\-build

WORKDIR /var/www/html

COPY package\.json package\-lock\.json vite\.config\.js \./
RUN npm ci \-\-ignore\-scripts

COPY resources resources
RUN npm run build

\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
\# 4\. Stage: Final runtime image              \#
\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
FROM php\-base AS runtime

WORKDIR /var/www/html

\# Скопируйте PHP\-приложение из php\-deps и собранные фронтенд\-файлы
COPY \-\-from\=php\-deps /var/www/html /var/www/html
COPY --from=frontend-build /var/www/html/public/build public/build

# Отключите Xdebug (если установлен) и оптимизируйте Laravel
RUN docker-php-ext-disable xdebug || true \
  && php artisan config:cache \
  && php artisan route:cache \
  && php artisan view:cache \
  && chmod -R 755 bootstrap/cache storage

# Скопируйте скрипт entrypoint и сделайте его исполняемым
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
# Запустите приложение от имени пользователя без прав root для безопасности
USER www-data:www-data

# Откройте порт 10000 (это внутренний порт, на котором будет слушать Laravel FPM)
EXPOSE 10000

# Определите скрипт entrypoint, который запускается при старте контейнера
ENTRYPOINT ["docker-entrypoint.sh"]
# Команда по умолчанию для запуска (сервер PHP-FPM)
CMD ["php-fpm"]
