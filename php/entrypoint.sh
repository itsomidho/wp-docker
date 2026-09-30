#!/bin/bash
# Starts the cron daemon (self-daemonizes/forks, so this returns immediately)
# before handing off to the base image's real entrypoint, which execs
# php-fpm as the container's foreground/PID 1 process as usual.
set -e
cron
exec docker-entrypoint.sh "$@"
