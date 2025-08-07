FROM php:8.2-fpm-alpine

# Устанавливаем системные зависимости
RUN apk update && apk add --no-cache \
    nginx \
    supervisor \
    git \
    unzip \
    # Расширения PHP, необходимые для Laravel (могут потребоваться и другие, если ваш проект их использует)
    php82-pdo_mysql \
    php82-mysqli \
    php82-opcache \
    php82-dom \
    php82-mbstring \
    php82-xml \
    php82-json \
    php82-fileinfo \
    php82-tokenizer \
    php82-session \
    php82-ctype \
    php82-gd \
    php82-intl \
    php82-iconv \
    php82-zip \
    php82-curl

# Устанавливаем Composer
COPY --from=composer/composer:latest-bin /composer /usr/bin/composer

# Создаем пользователя www-data (если его нет) и группу для PHP-FPM
# php:*-fpm-alpine уже создает пользователя www-data (UID 82, GID 82)
# Если вы используете другую базовую ОС (не Alpine), возможно, придется добавить:
# RUN addgroup -g 82 www-data && adduser -u 82 -D -G www-data www-data

# Копируем весь проект в /var/www/html
# Исключаем .git и vendor (vendor будет установлен Composer'ом)
COPY . /var/www/html

# Устанавливаем рабочую директорию
WORKDIR /var/www/html

# Устанавливаем зависимости Composer
# --no-dev: не устанавливать зависимости для разработки
# --optimize-autoloader: оптимизировать автозагрузчик для продакшена
RUN composer install --no-dev --optimize-autoloader

# Настраиваем права доступа для Laravel
# Папки storage и bootstrap/cache должны быть доступны для записи веб-сервером
RUN chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache

# Копируем конфигурационные файлы Nginx, PHP-FPM и Supervisor
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY php-fpm/php-fpm.conf /etc/php-fpm.conf
COPY php-fpm/www.conf /etc/php-fpm.d/www.conf
COPY supervisor/supervisord.conf /etc/supervisord.conf

# Открываем порт 80 для Nginx
EXPOSE 80

# Запускаем Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
