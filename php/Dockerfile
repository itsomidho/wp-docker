FROM wordpress:php8.2-fpm

COPY --chmod=0755 php/install-php-extensions /usr/local/bin/install-php-extensions

RUN install-php-extensions xdebug
