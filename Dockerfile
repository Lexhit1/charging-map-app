FROM php:8.3-fpm

# Установи зависимости
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libzip-dev \
    unzip \
    git \
    && docker-php-ext-install pdo pdo_pgsql zip

# Установи Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Установи Node.js для npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Скопируй код проекта
WORKDIR /var/www/html
COPY . .

# Установи права
RUN chown -R www-data:www-data /var/www/html

# Установи зависимости
RUN composer install --no-dev --optimize-autoloader
RUN npm install
RUN npm run build

# Запусти сервер
CMD ["php-fpm"]