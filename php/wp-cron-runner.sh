#!/bin/bash
# Runs WordPress's real cron queue for every site, once a minute (see
# php/crontab). Pairs with DISABLE_WP_CRON in wp-config.php — without a real
# cron loop, WordPress's page-load-triggered pseudo-cron doesn't fire
# reliably on a quiet local dev site, so scheduled posts, WooCommerce order
# processing, etc. can silently not run.
#
# Absolute path to wp, not just `wp` — cron's default PATH doesn't include
# /usr/local/bin, so a bare `wp` fails with "command not found" here even
# though it works fine everywhere else (interactive shell, docker exec).
#
# flock: cron starts a new instance every minute regardless of whether the
# previous one finished. A single slow event (a big backlog on first run, or
# just a slow plugin hook) can take longer than a minute, and without this,
# overlapping instances pile up — observed for real while building this: a
# 125-second event caused 3 concurrent runs stacked on top of each other.
exec 200>/var/run/wp-cron-runner.lock
flock -n 200 || { echo "[wp-cron] $(date '+%Y-%m-%d %H:%M:%S') previous run still in progress, skipping"; exit 0; }

for config in /var/www/*/wp-config.php; do
    [ -f "$config" ] || continue
    site_dir="$(dirname "$config")"
    echo "[wp-cron] $(date '+%Y-%m-%d %H:%M:%S') ${site_dir}"
    /usr/local/bin/wp cron event run --due-now --path="$site_dir" --allow-root 2>&1
done
