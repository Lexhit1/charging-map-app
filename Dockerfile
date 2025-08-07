# Dockerfile

# 1. Выбираем базовый образ PHP с FPM (FastCGI Process Manager)
#    Это образ, который содержит PHP и все необходимое для его запуска.
#    Мы используем версию 8.2.
FROM php:8.2-fpm

# 2. Устанавливаем системные зависимости
#    Сначала обновляем список пакетов (apt-get update), затем устанавливаем необходимые пакеты (-y для автоматического подтверждения).
#    - nginx: Веб-сервер, который будет обслуживать статические файлы и передавать запросы PHP-FPM.
#    - supervisor: Менеджер процессов, который будет следить за Nginx и PHP-FPM и перезапускать их в случае сбоя.
#    - git, unzip: Нужны для установки зависимостей Composer.
#    - libpng-dev, libjpeg-dev, libwebp-dev, libzip-dev: Библиотеки, необходимые для установки расширений PHP (например, GD для работы с изображениями, Zip).
#    После установки удаляем кэш пакетов (rm -rf /var/lib/apt/lists/*), чтобы уменьшить размер образа.
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. Устанавливаем расширения PHP
#    Мы уже установили нужные библиотеки (libpng-dev, libjpeg-dev, libwebp-dev) выше.
#    Теперь просто устанавливаем расширения: gd (для обработки изображений), pdo_mysql (для работы с базой данных MySQL) и zip.
#    -j$(nproc) использует все доступные ядра процессора для ускорения компиляции.
RUN docker-php-ext-install -j$(nproc) gd pdo_mysql zip

# 4. Устанавливаем рабочую директорию внутри контейнера
#    Все последующие команды будут выполняться относительно этой директории.
WORKDIR /var/www/html

# 5. Копируем исходный код вашего приложения в контейнер
#    Точка '.' означает "все файлы и папки из текущей директории на вашем компьютере, где находится Dockerfile".
#    /var/www/html - это директория внутри контейнера.
COPY . /var/www/html

# 6. Устанавливаем зависимости Composer
#    Сначала копируем исполняемый файл Composer из официального образа Composer.
#    Затем запускаем composer install для установки всех PHP-зависимостей вашего проекта.
#    --no-dev: Не устанавливать зависимости для разработки.
#    --optimize-autoloader: Оптимизировать автозагрузчик классов для продакшена.
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer install --no-dev --optimize-autoloader
# 7. Настраиваем права доступа
#    - chown -R www-data:www-data /var/www/html: Изменяем владельца всех файлов и папок в /var/www/html на пользователя www-data,
#      под которым обычно работает Nginx и PHP-FPM.
#    - chmod -R 755 /var/www/html/storage: Устанавливаем права 755 для папки storage (чтение, запись, выполнение для владельца; чтение, выполнение для группы и других).
#      Это важно, так как Laravel пишет логи и кэш в эту папку.
#    - chmod -R 755 /var/www/html/bootstrap/cache: То же самое для папки bootstrap/cache.
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# 8. Копируем файлы конфигурации Nginx, Supervisor и PHP-FPM
#    - supervisord.conf: Конфигурация Supervisor. Копируем ее в стандартную директорию Supervisor.
#    - nginx.conf: Конфигурация Nginx. Копируем ее в sites-available, а затем создаем символическую ссылку в sites-enabled,
#      чтобы Nginx ее подхватил.
#    - www.conf: Конфигурация PHP-FPM для пула www. Копируем ее в директорию fpm/pool.d.
#    - rm -f /etc/nginx/sites-enabled/default: Удаляем стандартную символическую ссылку Nginx, если она есть, чтобы не конфликтовать с нашей.
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx/nginx.conf /etc/nginx/sites-available/default.conf
COPY php-fpm/www.conf /etc/php/8.2/fpm/pool.d/www.conf
RUN ln -sf /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf \
    && rm -f /etc/nginx/sites-enabled/default

# 9. Открываем порт 80
#    Это порт, на котором будет работать Nginx. Render будет видеть только его.
EXPOSE 80

# 10. Команда, которая будет запускаться при старте контейнера
#     Запускаем supervisord в режиме "без демона" (-n), чтобы он оставался на переднем плане.
#     Supervisor будет управлять Nginx и PHP-FPM.
CMD ["/usr/bin/supervisord", "-n"]
