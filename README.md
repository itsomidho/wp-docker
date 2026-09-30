# WordPress Docker Multi-Site — Local Development

A Docker-based environment for running multiple WordPress sites locally with
Nginx, a single shared PHP-FPM pool, MySQL, Redis (object cache), and
Adminer. Everything is driven by one command, `wpdev`. Adding a site is one
call and does not touch `docker-compose.yml`.

## Prerequisites

- Docker (20.10+) and Docker Compose (2.0+)
- [mkcert](https://github.com/FiloSottile/mkcert) for trusted local SSL — install with `wpdev install-mkcert` (see below)

## One-time setup: putting `wpdev` on your PATH

The command lives in this repo as the `wpdev` script. To type `wpdev up`
instead of `./wpdev up` from any directory, symlink it into `~/.local/bin`
(already on `PATH` on most Linux setups, including this one):

```bash
ln -sf "$(pwd)/wpdev" ~/.local/bin/wpdev
```

Run that once per machine — it's just a symlink, not tracked by git, so a
fresh `git clone` on another machine needs it again. If you'd rather not
touch `~/.local/bin`, every command below also works as `./wpdev <command>`
from inside this folder — no difference in behavior, just typing.

Check it worked:

```bash
wpdev help
```

## Getting started

```bash
wpdev install-mkcert     # 1. one-time: sets up a local trusted SSL CA
wpdev up                 # 2. start mysql, php, redis, mailpit, nginx, adminer, portainer
wpdev add                 # 3. provision your first site
```

`wpdev add` is interactive — it walks you through it:

```
$ wpdev add
Enter domain name (e.g., mysite.test): mysite.test

Domain:          mysite.test
Site directory:  sites/mysite
Database:        wp_mysite

Continue? (y/n): y
[STEP] 1/8 Starting MySQL + PHP + Redis...
...
✓ mysite.test is ready

  Site:        https://mysite.test
  Admin login: https://mysite.test/wp-admin  (admin / <generated password>)

Add '127.0.0.1 mysite.test' to /etc/hosts now? (y/n): y
```

That one command:

1. Creates the Nginx vhost in `nginx/sites/<domain>.conf`
2. Downloads WordPress core into `sites/<name>/`
3. Creates a dedicated MySQL database + user for the site
4. Generates `wp-config.php` via WP-CLI (Redis + `DISABLE_WP_CRON` included — see below)
5. Generates an mkcert SSL certificate
6. Runs `wp core install` — **no browser installer, no Adminer step**
7. Installs + activates the `redis-cache` plugin and enables the object cache
8. Reloads Nginx and offers to add the `/etc/hosts` entry for you

Visit `https://mysite.test` — it's a working, logged-in-capable WordPress
site with Redis object caching already on. The admin password is also saved
to `sites/mysite/.admin-password` if you need it again later (or just run
`wpdev creds mysite`).

Run `wpdev add` again for each additional site — the containers don't
restart, and every site gets its own vhost, cert, and database.

## Command reference

Everything is `wpdev <command> [argument]`:

| Command | What it does |
|---|---|
| `wpdev up` | Start all containers |
| `wpdev down` | Stop all containers |
| `wpdev restart` | Restart all containers |
| `wpdev status` | Container status, plus a per-site table: reachable? DB connected? Redis cache connected? |
| `wpdev doctor` | Proactive health check — CA trust, orphan containers, per-site DB sanity (see below) |
| `wpdev logs [service]` | Tail logs — all services, or one (`php`, `nginx`, `mysql`, `redis`) |
| `wpdev shell php\|db\|nginx\|redis` | Shell into a container (`redis` opens `redis-cli` directly) |
| `wpdev db [name]` | Open a MySQL prompt (CLI) — root by default, or scoped straight into one site's own DB |
| `wpdev adminer [name]` | Open Adminer in the browser — root by default, or deep-linked to one site's DB |
| `wpdev portainer` | Open Portainer in the browser (Docker container/image management) |
| `wpdev mailpit` | Open Mailpit in the browser — every site's outgoing mail, caught |
| `wpdev reload-nginx` | Test + reload Nginx (after editing a vhost by hand) |
| `wpdev backup` | `mysqldump --all-databases` to `backups/` |
| `wpdev install-mkcert` | One-time local CA setup for trusted SSL |
| `wpdev clean` | Remove containers (keeps data) |
| `wpdev clean-all` | Remove containers **and volumes** (⚠ deletes all data, asks to confirm) |
| `wpdev add` | Provision a new site (interactive) |
| `wpdev remove <name>` | Delete a site: WP files, DB, Nginx config, SSL cert, logs (asks you to confirm) |
| `wpdev clone <src> <new>` | Duplicate a site (files + DB) under a new domain, with URLs re-pointed and its own DB/cache |
| `wpdev snapshot <site> [label]` | Save a files+DB snapshot of a site |
| `wpdev restore <site> [snap-id]` | Restore a site from a snapshot (asks you to confirm; defaults to the latest) |
| `wpdev db-export <site> [file]` | Dump just that site's database (default: `backups/<site>_<time>.sql.gz`) |
| `wpdev db-import <site> <file>` | Replace that site's database from a `.sql` or `.sql.gz` dump (asks you to confirm) |
| `wpdev list` | List configured site domains |
| `wpdev hosts` | Print the `/etc/hosts` lines needed for all sites |
| `wpdev creds <name>` | Show a site's admin/DB credentials |
| `wpdev wp <name> <args...>` | Run any WP-CLI command against a site, e.g. `wpdev wp mysite plugin list` |

`wpdev help` prints this same list from the terminal. There's nothing else to
learn — it's a thin wrapper around `docker compose` (stack lifecycle) and
WP-CLI (site provisioning), nothing hidden behind it.

## Access points

| Service | URL | Credentials |
|---|---|---|
| Your sites | `https://<domain>` | `wpdev creds <name>` |
| Adminer | `http://localhost:8080` | `root` / `DB_ROOT_PASSWORD` in `.env` |
| MySQL (host) | `localhost:3306` | `root` / `DB_ROOT_PASSWORD` in `.env` |
| Redis (host) | `localhost:6379` | none (no auth configured — local dev only) |
| Portainer | `http://localhost:9000` | Set your own admin account on first visit (see below) |
| Mailpit | `http://localhost:8025` | none — local only, nothing ever really sends |

## Status dashboard

```bash
wpdev status
```

Shows container health (`docker compose ps`) plus a per-site table — the
WordPress-specific view Portainer's generic container UI can't give you:

```
DOMAIN                       HTTP   DATABASE   CACHE
mysite.test                  200    OK         Connected
otherlab.test                200    OK         off
```

- **HTTP** — the site's actual response code, checked directly against
  `127.0.0.1` (works even before you've added the `/etc/hosts` entry, and
  ignores any proxy your shell has set)
- **DATABASE** — `OK`/`FAIL`/`down`, checked against that site's real
  `DB_NAME` from its own `wp-config.php`
- **CACHE** — `Connected`/`off`/`n/a` — `off` just means that site predates
  the Redis feature (`wpdev add` enables it automatically; older sites never
  got it retrofitted)

## Doctor

```bash
wpdev doctor
```

`status` tells you what's happening right now; `doctor` looks for things
that will bite you *later* — read-only, diagnose-only, never fixes anything
for you, just tells you the command to run:

- Docker daemon reachable, `.env` present and populated
- Every expected container actually running (not just present)
- Orphaned `wp-*` containers left over from a renamed/removed service
- mkcert's local CA actually exists (not just that `mkcert` is installed)
- A stray root-owned `docker/` directory at the repo root, if present
- Disk usage of `sites/`
- Per site: `/etc/hosts` entry present, SSL cert present, and — the one
  this was built for — **whether the database `wp-config.php` actually
  points at really exists**, distinct from existing-but-empty. This is
  exactly the check that would have caught the incident that led to this
  command existing: a site's `wp-config.php` silently pointing at a
  database that isn't there.

## Cloning a site

```bash
wpdev clone mysite mysite-test
```

Duplicates `mysite`'s files and database under a new domain
(`mysite-test.test`), then:

- Creates a fresh, dedicated database + user for the clone (never reuses or
  shares the source's database)
- Rewrites `wp-config.php` for the new DB and domain
- Runs `wp search-replace` against the copied database so `siteurl`/`home`
  and any URLs embedded in post content actually point at the new domain,
  not the old one
- Sets its own `WP_REDIS_PREFIX` so the clone's cache never collides with
  the source's, and enables the object cache

The admin login is whatever the source site's was — it's a copy of that
same database, not a new account. `wpdev creds mysite` still works to look
it up. The source site is never touched; only files are read from it.

Refuses to run if the destination name already exists — remove it first
(`wpdev remove`) or pick a different name, rather than silently overwriting
something that might matter.

## Snapshots

```bash
wpdev snapshot mysite before-risky-plugin-update   # label is optional
wpdev restore mysite                               # defaults to the latest snapshot
wpdev restore mysite 20260115_143022_before-risky-plugin-update
```

Take a snapshot before doing anything you might want to undo — updating a
plugin, testing a theme change, whatever. Each snapshot is a full files +
database backup, stored under `snapshots/<site>/<timestamp>[_label]/`
(git-ignored — these live on disk only, never committed).

`restore` overwrites the site's *current* files and database with the
snapshot's, and flushes that site's Redis cache afterward so you don't end
up looking at stale cached content from before the rollback. It asks you to
type the domain to confirm first — the current state is not auto-saved
before restoring, so if you want to keep it, take a snapshot of it first.

Snapshots are never deleted automatically — not by `restore`, and not by
`wpdev remove` on the site they belong to (a safety net shouldn't quietly
disappear as a side effect of something else). Clean up `snapshots/<site>/`
by hand when you no longer need them.

## Sharing a site's database

`wpdev backup` dumps every database at once — useful for a full-stack backup,
not for handing one site's data to someone else. For that:

```bash
wpdev db-export mysite                       # -> backups/mysite_<timestamp>.sql.gz
wpdev db-export mysite mysite-for-bob.sql.gz # or a specific path

wpdev db-import mysite that-file.sql.gz      # .sql or .sql.gz, auto-detected
```

`db-import` **replaces** the site's entire current database (asks you to
confirm) and flushes its Redis cache afterward. If the dump came from a
different domain, `wpdev` doesn't guess at re-pointing URLs for you — it
prints the exact `wp search-replace` command to run, since only you know
what the old domain actually was.

## Xdebug

Xdebug is installed but only attaches on demand
(`xdebug.start_with_request=trigger` in `php/xdebug.ini`), so normal page
loads aren't slowed down. Trigger it per-request with the "Xdebug helper"
browser extension, or `?XDEBUG_TRIGGER=1`. VS Code config is in
`.vscode/launch.json` ("Listen for Xdebug (wp-docker)"), listening on 9003.

## Redis object cache

Every site provisioned by `wpdev add` gets the [redis-cache](https://wordpress.org/plugins/redis-cache/)
plugin, installed, activated, and enabled against the shared `redis`
container automatically — no per-site setup needed. Since Redis is shared
across all sites, each site's `wp-config.php` sets its own
`WP_REDIS_PREFIX` (its site name) so cache keys never collide between sites.

```bash
wpdev wp mysite redis status     # connection status, drop-in, hit/miss info
wpdev shell redis                # raw redis-cli, e.g. KEYS mysite:*
```

Redis has no volume — it's purely a cache, so a restart just means the next
few page loads repopulate it. `wpdev remove` flushes a site's own keys.

## Mail catching (Mailpit)

Every site's outgoing mail — password resets, WooCommerce order emails,
contact form notifications, comment alerts, anything sent via `wp_mail()` —
is caught by [Mailpit](https://mailpit.axllent.org/) instead of actually
being delivered. Nothing to configure per site: PHP's `mail()` (what
`wp_mail()` uses by default) is relayed to Mailpit at the PHP-container
level via `msmtp` (`php/msmtprc` + `php/mail.ini`), so it works
automatically for every site — including ones that predate this feature.

```bash
wpdev mailpit
```

Opens the web inbox at `http://localhost:8025`. Real SMTP too, at
`localhost:1025`, if some tool wants to connect directly instead of going
through `mail()`.

## Real WP-Cron

WordPress's default "cron" isn't a real scheduler — it only checks for due
events on a page load, so scheduled posts, WooCommerce order processing,
and plugin maintenance tasks can silently sit unrun on a quiet local site
with little traffic. Every site `wpdev add` creates gets
`DISABLE_WP_CRON` set automatically, and a real cron daemon inside the
shared `php` container runs the actual due events for **every** site, once
a minute, regardless of whether anyone loads a page:

```bash
tail -f logs/cron.log             # watch it run
wpdev wp mysite cron event run --due-now   # trigger a site's cron manually, right now
```

This is genuinely necessary, not theoretical — building this surfaced a
real backlog of dozens of unrun events (Yoast SEO, Gravity Forms, Elementor,
All-in-One WP Migration) on the sites in this repo that had been silently
queued for who knows how long under the old page-load-triggered pseudo-cron.

A few things worth knowing if you ever touch `php/crontab` or
`php/wp-cron-runner.sh`:

- The crontab file is **baked into the image**, not bind-mounted like the
  other `php/*` configs — Debian's `cron` silently ignores `/etc/cron.d`
  files that aren't root-owned and non-group-writable, which a bind mount
  can't guarantee (it inherits the host file's ownership). Changing it
  needs `docker compose build php`, not just an edit.
- `wp-cron-runner.sh` **is** bind-mounted and does pick up edits live in
  principle, but some editors/tools replace-rather-than-modify a file on
  save, which can orphan an already-open bind mount — if a change doesn't
  seem to take effect, `docker compose restart php` forces a fresh mount.
- The runner is `flock`-guarded against overlapping itself — a slow event
  (a big first-run backlog, or just a slow plugin hook) can take longer
  than cron's one-minute interval, and without the lock, overlapping runs
  pile up.

## Portainer (container/image dashboard)

```bash
wpdev portainer
```

Opens a web UI showing every container's state, logs, resource usage, plus
images, volumes, and networks — for this project and anything else on your
Docker daemon.

**First visit:** it asks for a one-time setup token instead of a bare login
screen — get it with `docker logs wp-portainer`, paste it in, then create
your own admin account.

**Worth knowing:** Portainer works by mounting your host's `docker.sock`,
which gives it — and anyone who can reach `localhost:9000` — full control of
your *entire* Docker daemon, not just this project's four containers. That's
inherent to how Portainer works, not a misconfiguration. Fine for a personal
dev machine; worth remembering if this box is ever shared or exposed.

## Project structure

```
wp-docker/
├── docker-compose.yml           # mysql, php, redis, mailpit, nginx, adminer, portainer
├── .env                         # DB password, ports, optional build proxy (git-ignored)
├── wpdev                        # the whole interface — `wpdev help` (see Getting started)
├── install-mkcert.sh            # one-time mkcert installer, called by `wpdev install-mkcert`
│
├── php/
│   ├── Dockerfile               # wordpress:php8.2-fpm + xdebug + phpredis + msmtp + cron + wp-cli
│   ├── xdebug.ini
│   ├── mail.ini                 # sendmail_path -> msmtp
│   ├── msmtprc                  # msmtp: relay to mailpit:1025
│   ├── crontab                  # /etc/cron.d entry — baked into the image, see "Real WP-Cron"
│   ├── wp-cron-runner.sh        # runs due cron events for every site, once a minute
│   └── entrypoint.sh            # starts cron, then hands off to the base image's entrypoint
│
├── nginx/
│   ├── nginx.conf
│   ├── sites/                   # one *.conf per site, served directly — no enable/disable step
│   │   ├── site.conf.template   # used by `wpdev add`
│   │   └── default.conf         # catch-all for unmatched domains
│   └── ssl/{certs,private}/     # mkcert output
│
├── sites/<name>/                 # WordPress core + wp-content for each site (git-ignored)
│   ├── .admin-password          # generated by `wpdev add`
│   └── .db-password
│
└── logs/
    ├── nginx/                   # access/error logs, per site
    └── cron.log                 # real WP-Cron activity, every site, one file
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `wpdev: command not found` | Either re-run the symlink step above, or use `./wpdev` instead (from inside this folder) |
| SSL not trusted | `wpdev install-mkcert` |
| Can't reach a site | `cat /etc/hosts \| grep <domain>` — add via `wpdev hosts` |
| 502 Bad Gateway | `docker compose restart php` |
| Nginx won't reload | `docker exec wp-nginx nginx -t` for the actual error |
| Permission denied under `sites/` | `sudo chown -R $USER:$USER sites/` |
| `docker compose build` fails to reach the internet | your network may need a proxy — set `HTTP_PROXY`/`HTTPS_PROXY` in `.env` (see `.env.example`); left unset, no proxy is used |
| `docker pull`/`docker compose up` fails (CDN block or "RBAC: access denied") | Docker Hub geo-blocking, not a config error — `.env`'s proxy only covers the `php` image *build*, not plain `docker pull`. Retry with `HTTP_PROXY=http://<proxy> HTTPS_PROXY=http://<proxy> docker pull <image>` once, then `wpdev up` normally |

## Notes

- Local development only — `.env` holds a plaintext root DB password by design.
- mkcert certificates are trusted locally only.
- For production, use real SSL (Let's Encrypt) and don't reuse this compose file as-is.
