# 1. Базовый образ PHP-FPM на Alpine Linux
FROM php:8.2-fpm-alpine

# 2. Установка системных зависимостей и PHP расширений
#    Здесь мы исправляем 'oniguruma' на 'oniguruma-dev'
RUN apk add --no-cache \
    libzip \
    libpng \
    libjpeg-turbo \
    oniguruma-dev \
    libxml2 \
    icu-libs \
    postgresql-libs \
    sqlite-libs \
    pkgconfig \
    postgresql-dev \
    sqlite-dev \
    && docker-php-ext-install \
    pdo_pgsql \
    pdo_sqlite \
    mbstring \
    zip \
    xml \
    intl \
    opcache \
    && docker-php-ext-enable opcache \
    && apk del postgresql-dev sqlite-dev pkgconfig \
    && rm -rf /var/cache/apk/*

# 3. Копирование файлов приложения в рабочую директорию
#    Убедись, что твои файлы приложения находятся в корневой директории проекта,
#    относительно которой запускается Dockerfile.
WORKDIR /var/www/html
COPY . /var/www/html

# 4. Установка зависимостей Composer (если ты используешь Composer)
#    Раскомментируй эти строки, если у тебя есть файл composer.json
#    и тебе нужно установить зависимости PHP.
# COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
# RUN composer install --no-dev --optimize-autoloader

# 5. Настройка прав доступа (если требуется, для веб-сервера)
#    Это часто необходимо для PHP-FPM
RUN chown -R www-data:www-data /var/www/html

# 6. Открытие порта, на котором PHP-FPM слушает запросы (по умолчанию 9000)
EXPOSE 9000

# 7. Команда для запуска PHP-FPM при старте контейнера
CMD ["php-fpm"]
