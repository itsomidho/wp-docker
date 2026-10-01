#!/bin/bash
# Starts the cron daemon (self-daemonizes/forks, so this returns immediately)
# before handing off to the base image's real entrypoint, which execs
# php-fpm as the container's foreground/PID 1 process as usual.
set -e

# Cron jobs run with a stripped environment and never see Docker's ENV
# PHP_VERSION — confirmed the hard way: php-fpm's own master process clears
# its environment internally (even /proc/1/environ comes up empty), so
# there's no way to recover it from inside a cron job at all. Writing it to
# a plain file here, before cron or php-fpm even start, sidesteps the whole
# problem — wp-cron-runner.sh reads this file instead of any env var.
echo "${PHP_VERSION:-8.2}" > /etc/php-version

cron
exec docker-entrypoint.sh "$@"
