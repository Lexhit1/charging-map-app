FROM php:8.3-fpm

# Установи зависимости для PHP, PostgreSQL и PostGIS
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libzip-dev \
    unzip \
    git \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-install pdo pdo_pgsql zip mbstring xml

# Установи Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Установи Node.js для npm (версия 20)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Обнови npm до последней версии (чтобы избежать уведомлений и ошибок)
RUN npm install -g npm@11.5.1

# Скопируй код проекта
WORKDIR /var/www/html
COPY . .

# Установи права
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Установи зависимости и собери ассеты (с фиксом для ERESOLVE)
RUN composer install --no-dev --optimize-autoloader
RUN npm install --legacy-peer-deps
RUN npm run build

# Запусти сервер
CMD php artisan serve --host=0.0.0.0 --port=10000