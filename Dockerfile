
FROM php:8\.3\\-fpm\\-alpine AS php\\-base

RUN apk add \\-\\-no\\-cache \\
    git \\
    curl \\
    bash \\
    libzip\\-dev \\
    libpng\\-dev \\
    jpeg\\-dev \\
    oniguruma\\-dev \\
    libxml2\\-dev \\
    icu\\-dev \\
    postgresql\\-dev \\
    sqlite\\-dev \\
    mysql\\-client \\
    pkgconfig \\
  && docker\\-php\\-ext\\-install \\
    pdo\_mysql \\
    pdo\_pgsql \\
    pdo\_sqlite \\
    mbstring \\
    zip \\
    xml \\
    intl \\
    gd \\
    opcache \\
  && docker\\-php\\-ext\\-enable pdo_mysql pdo_pgsql pdo\_sqlite opcache \\
  && rm \\-rf /var/cache/apk/\* \\
  && curl \\-sS https://getcomposer\.org/installer \| php \\-\\- \\-\\-install\\-dir\=/usr/local/bin \\-\\-filename\=composer

WORKDIR /var/www/html

FROM php\\-base AS php\\-deps

COPY \. \.

RUN composer install \\-\\-no\\-dev \\-\\-optimize\\-autoloader

RUN chmod \\-R ug\+rw storage bootstrap/cache

FROM node:22\\-alpine AS frontend\\-build

WORKDIR /var/www/html

COPY package\.json package\\-lock\.json vite\.config\.js \./
RUN npm ci \\-\\-ignore\\-scripts

COPY resources resources
RUN npm run build

FROM php\\-base AS runtime

WORKDIR /var/www/html

COPY \\-\\-from\=php\\-deps /var/www/html /var/www/html
COPY \\-\\-from\=frontend\\-build /var/www/html/public/build public/build

RUN docker\\-php\\-ext\\-disable xdebug \|\| true \\
  && php artisan config:cache \\
  && php artisan route:cache \\
  && php artisan view:cache \\
  && chmod \\-R 755 bootstrap/cache storage

COPY docker\\-entrypoint\.sh /usr/local/bin/docker\\-entrypoint\.sh
RUN chmod \+x /usr/local/bin/docker\\-entrypoint\.sh

USER www\\-data:www\\-data

EXPOSE 10000

ENTRYPOINT \["docker\\-entrypoint\.sh"\]
CMD \["php\\-fpm"\]
