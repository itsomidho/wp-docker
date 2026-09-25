FROM wordpress:php8.2-fpm

COPY --chmod=0755 php/install-php-extensions /usr/local/bin/install-php-extensions

RUN install-php-extensions xdebug

# WP-CLI: drives site provisioning (DB + wp-config + core install) from new-site.sh,
# and is available for ad-hoc use via `make wp site=<name> cmd="..."`.
ADD --chmod=0755 https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /usr/local/bin/wp
