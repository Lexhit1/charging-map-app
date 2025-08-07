# Dockerfile

# Используем базовый образ PHP с FPM для Alpine Linux
FROM php:8.2-fpm-alpine

# Устанавливаем Nginx
RUN apk add --no-cache nginx

# Устанавливаем системные зависимости и расширения PHP
# build-base: содержит компиляторы, необходимые для сборки некоторых PHP-расширений
# git: для Composer, если он будет клонировать что-то
# unzip: для распаковки архивов (используется Composer)
# libxml2-dev, libpng-dev, libjpeg-turbo-dev, freetype-dev: для расширений xml, gd
# icu-dev, oniguruma-dev: для расширений intl, mbstring
# postgresql-dev, sqlite-dev: для pdo_pgsql, pdo_sqlite
# pkgconfig: инструмент для поиска библиотек
# libzip-dev: *ЭТО ТОТ ПАКЕТ, КОТОРЫЙ НУЖЕН ДЛЯ РАСШИРЕНИЯ 'zip'*
RUN apk add --no-cache \
    build-base \
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
    libzip-dev \
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

# Устанавливаем Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Устанавливаем рабочую директорию
WORKDIR /var/www/html

# Копируем файлы проекта
# Важно: если у тебя есть .dockerignore, он будет игнорировать ненужные файлы
COPY . .

# Устанавливаем зависимости Laravel
# --no-dev: не устанавливать зависимости для разработки
# --optimize-autoloader: оптимизировать автозагрузку классов
# --no-interaction: не задавать вопросы в процессе установки
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Настраиваем права доступа для папок storage и bootstrap/cache
# Это необходимо, чтобы Laravel мог записывать файлы (логи, кэш, сессии)
RUN chown -R www-data:www-data /var/www/html/storage \
    && chown -R www-data:www-data /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Копируем конфигурацию Nginx
# Убедись, что файл nginx.conf находится в папке nginx/ относительно корня твоего проекта
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Копируем конфигурацию Supervisor
# Убедись, что файл supervisord.conf находится в папке supervisor/ относительно корня твоего проекта
COPY supervisor/supervisord.conf /etc/supervisord.conf

# Открываем порт 80, на котором будет работать Nginx
EXPOSE 80

# Команда запуска контейнера: используем Supervisor для запуска Nginx и PHP-FPM одновременно
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
