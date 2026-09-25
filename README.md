# WordPress Docker Multi-Site — Local Development

A Docker-based environment for running multiple WordPress sites locally with
Nginx, a single shared PHP-FPM pool, MySQL, and phpMyAdmin. Everything is
driven by one command, `wpdev`. Adding a site is one call and does not touch
`docker-compose.yml`.

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
wpdev up                 # 2. start mysql, php, nginx, phpmyadmin
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
[STEP] 1/7 Starting MySQL + PHP...
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
4. Generates `wp-config.php` via WP-CLI
5. Generates an mkcert SSL certificate
6. Runs `wp core install` — **no browser installer, no phpMyAdmin step**
7. Reloads Nginx and offers to add the `/etc/hosts` entry for you

Visit `https://mysite.test` — it's a working, logged-in-capable WordPress
site. The admin password is also saved to `sites/mysite/.admin-password` if
you need it again later (or just run `wpdev creds mysite`).

Run `wpdev add` again for each additional site — the containers don't
restart, and every site gets its own vhost, cert, and database.

## Command reference

Everything is `wpdev <command> [argument]`:

| Command | What it does |
|---|---|
| `wpdev up` | Start all containers |
| `wpdev down` | Stop all containers |
| `wpdev restart` | Restart all containers |
| `wpdev status` | Show container status |
| `wpdev logs [service]` | Tail logs — all services, or one (`php`, `nginx`, `mysql`) |
| `wpdev shell php\|db\|nginx` | Shell into a container |
| `wpdev db [name]` | Open a MySQL prompt (CLI) — root by default, or scoped straight into one site's own DB |
| `wpdev pma [name]` | Open phpMyAdmin in the browser — root by default, or deep-linked to one site's DB |
| `wpdev reload-nginx` | Test + reload Nginx (after editing a vhost by hand) |
| `wpdev backup` | `mysqldump --all-databases` to `backups/` |
| `wpdev install-mkcert` | One-time local CA setup for trusted SSL |
| `wpdev clean` | Remove containers (keeps data) |
| `wpdev clean-all` | Remove containers **and volumes** (⚠ deletes all data, asks to confirm) |
| `wpdev add` | Provision a new site (interactive) |
| `wpdev remove <name>` | Delete a site: WP files, DB, Nginx config, SSL cert, logs (asks you to confirm) |
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
| phpMyAdmin | `http://localhost:8080` | `root` / `DB_ROOT_PASSWORD` in `.env` |
| MySQL (host) | `localhost:3306` | `root` / `DB_ROOT_PASSWORD` in `.env` |

## Xdebug

Xdebug is installed but only attaches on demand
(`xdebug.start_with_request=trigger` in `php/xdebug.ini`), so normal page
loads aren't slowed down. Trigger it per-request with the "Xdebug helper"
browser extension, or `?XDEBUG_TRIGGER=1`. VS Code config is in
`.vscode/launch.json` ("Listen for Xdebug (wp-docker)"), listening on 9003.

## Project structure

```
wp-docker/
├── docker-compose.yml           # mysql, php, nginx, phpmyadmin
├── .env                         # DB password, ports, optional build proxy (git-ignored)
├── wpdev                        # the whole interface — `wpdev help` (see Getting started)
├── install-mkcert.sh            # one-time mkcert installer, called by `wpdev install-mkcert`
│
├── php/
│   ├── Dockerfile               # wordpress:php8.2-fpm + xdebug + wp-cli
│   └── xdebug.ini
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
└── logs/nginx/                  # access/error logs, per site
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

## Notes

- Local development only — `.env` holds a plaintext root DB password by design.
- mkcert certificates are trusted locally only.
- For production, use real SSL (Let's Encrypt) and don't reuse this compose file as-is.
