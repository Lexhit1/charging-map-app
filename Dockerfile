# 1. Stage: Base PHP image with common extensions
FROM php:8.3-fpm-alpine AS php-base

# Install PHP extensions and Composer
# ВНИМАНИЕ: Здесь мы устанавливаем только те dev-пакеты, которые нужны для сборки расширений.
# jpeg-dev вместо libjpeg-turbo для gd
# postgresql-dev для pdo_pgsql
# mysql-client для pdo_mysql (хотя pdo_mysql не требует mysql-client для сборки, но полезно иметь)
# nodejs и npm для фронтенда
RUN apk add --no-cache \
    git \
    curl \
    libzip-dev \
    libpng-dev \
    jpeg-dev \
    postgresql-dev \
    mysql-client \
    nodejs \
    npm \
    bash \
  # Устанавливаем PHP-расширения
  && docker-php-ext-install pdo_mysql pdo_pgsql zip gd opcache \
  # Включаем установленные расширения
  && docker-php-ext-enable pdo_mysql pdo_pgsql opcache \
  # Удаляем временные файлы и кэши apk
  && rm -rf /var/cache/apk/* \
  # Устанавливаем Composer
  && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set working directory for all stages
WORKDIR /var/www/html

# 2. Stage: Install PHP dependencies (Composer)
FROM php-base AS php-deps

# Copy Composer files and install dependencies
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader

# Copy the rest of the application files
COPY . .
# Set permissions for storage and cache directories
RUN chmod -R ug+rw storage bootstrap/cache

##############################################
# 3. Stage: Build frontend assets            #
##############################################
FROM node:22-alpine AS frontend-build

WORKDIR /var/www/html

COPY package.json package-lock.json vite.config.js ./
RUN npm ci --ignore-scripts

COPY resources resources
RUN npm run build

##############################################
# 4. Stage: Final runtime image              #
##############################################
FROM php-base AS runtime

WORKDIR /var/www/html

# Copy PHP application from php-deps and frontend build
COPY --from=php-deps /var/www/html /var/www/html
COPY --from=frontend-build /var/www/html/public/build public/build

# Disable Xdebug (if installed) and optimize Laravel
# Opcache уже включен в php-base, так что его здесь не нужно включать
RUN docker-php-ext-disable xdebug || true \
  && php artisan config:cache \
  && php artisan route:cache \
  && php artisan view:cache \
  && chmod -R 755 bootstrap/cache storage

# Copy the entrypoint script and make it executable
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
# Run the application as a non-root user for security
USER www-data:www-data

# Expose port 10000 (this is the internal port Laravel FPM will listen on)
EXPOSE 10000

# Define the entrypoint script that runs when the container starts
ENTRYPOINT ["docker-entrypoint.sh"]
# Default command to run (PHP-FPM server)
CMD ["php-fpm"]
