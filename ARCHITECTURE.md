# WordPress Multi-Site Docker Architecture

## Container Layout

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Host (Your Machine)              │
│                                                             │
│  ┌────────────────────────────────────────────────────-┐    │
│  │ wp-nginx (nginx:alpine)                             │    │
│  │ Ports: 80, 443                                      │    │
│  │ ┌────────────────────────────────────────────┐      │    │
│  │ │ /etc/nginx/sites-enabled/                  │      │    │
│  │ │  ├── default.conf (catch-all)              │      │    │
│  │ │  ├── site1.test.conf → sites-available/    │      │    │
│  │ │  └── site2.test.conf → sites-available/    │      │    │
│  │ └────────────────────────────────────────────┘      │    │
│  │                                                     │    │
│  │ SSL Certificates: /etc/nginx/ssl/                   │    │
│  │  ├── certs/                                         │    │
│  │  │   └── site1.test.pem (mkcert)                    │    │
│  │  └── private/                                       │    │
│  │      └── site1.test-key.pem                         │    │
│  └──────────────┬──────────────────────────────────────┘    │
│                 │ fastcgi_pass php:9000                     │
│  ┌──────────────▼──────────────────────────────────────┐    │
│  │ wp-php (wordpress:php8.2-fpm-alpine)                │    │
│  │ Port: 9000 (internal)                               │    │
│  │ ┌────────────────────────────────────────────┐      │    │
│  │ │ /var/www/                                  │      │    │
│  │ │  ├── site1/  (WordPress installation)      │      │    │
│  │ │  ├── site2/  (WordPress installation)      │      │    │
│  │ │  └── site3/  (WordPress installation)      │      │    │
│  │ └────────────────────────────────────────────┘      │    │
│  └──────────────┬──────────────────────────────────────┘    │
│                 │ mysql://db:3306                           │
│  ┌──────────────▼──────────────────────────────────────┐    │
│  │ wp-mysql (mysql:8.0)                                │    │
│  │ Port: 3306 (exposed to host)                        │    │
│  │ ┌────────────────────────────────────────────┐      │    │
│  │ │ Databases:                                 │      │    │
│  │ │  ├── site1_db (user: site1_user)           │      │    │
│  │ │  ├── site2_db (user: site2_user)           │      │    │
│  │ │  └── site3_db (user: site3_user)           │      │    │
│  │ └────────────────────────────────────────────┘      │    │
│  └──────────────┬──────────────────────────────────────┘    │
│                 │                                           │
│  ┌──────────────▼──────────────────────────────────────┐    │
│  │ wp-phpmyadmin (phpmyadmin/phpmyadmin)               │    │
│  │ Port: 8080                                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Request Flow

```
Browser (https://site1.test)
    │
    ├─ /etc/hosts → 127.0.0.1
    │
    ▼
Docker Host Port 443
    │
    ▼
wp-nginx:443
    │
    ├─ SSL Termination (mkcert cert)
    ├─ Match server_name: site1.test
    ├─ Root: /var/www/site1
    │
    ├─ Static files (.css, .js, images)
    │   └─ Serve directly from /var/www/site1
    │
    └─ PHP files (.php)
        │
        ▼
    fastcgi_pass php:9000
        │
        ▼
    wp-php:9000
        │
        ├─ SCRIPT_FILENAME: /var/www/site1/index.php
        ├─ Execute PHP
        │
        └─ WordPress DB Connection
            │
            ▼
        wp-mysql:3306
            │
            └─ Database: site1_db
                User: site1_user
                │
                ▼
            Return data to PHP
                │
                ▼
            Return HTML to Nginx
                │
                ▼
            Return to Browser
```

## Adding a New Site Flow

```
./new-site.sh
    │
    ├─ 1. Prompt for domain (e.g., "blog.test")
    │
    ├─ 2. Create Nginx Config
    │   └─ sed 's/DOMAIN/blog.test/g' site.conf.template
    │       > nginx/sites-available/blog.test.conf
    │       Update SITE_NAME placeholder
    │
    ├─ 3. Enable Site (Symlink)
    │   └─ ln -s ../sites-available/blog.test.conf
    │             nginx/sites-enabled/blog.test.conf
    │
    ├─ 4. Download WordPress
    │   └─ wget wordpress.org/latest.tar.gz
    │       Extract to sites/blog/
    │
    ├─ 5. Generate SSL Certificate
    │   └─ mkcert -cert-file nginx/ssl/certs/blog.test.pem
    │              -key-file nginx/ssl/private/blog.test-key.pem
    │              blog.test
    │
    ├─ 6. Offer to add to /etc/hosts
    │   └─ echo "127.0.0.1 blog.test" | sudo tee -a /etc/hosts
    │
    ├─ 7. Offer to start Docker
    │   └─ docker compose up -d
    │
    └─ 8. Done! Visit https://blog.test
            Use WordPress installer to create database
```

## Directory Mapping

```
Host Machine                    Container (wp-nginx)           Container (wp-php)
─────────────────              ──────────────────────         ──────────────────
./nginx/nginx.conf        →    /etc/nginx/nginx.conf
./nginx/sites-available/  →    /etc/nginx/sites-available/
./nginx/sites-enabled/    →    /etc/nginx/sites-enabled/
./nginx/ssl/              →    /etc/nginx/ssl/
  ├── certs/              →      ├── certs/
  └── private/            →      └── private/
./sites/                  →    /var/www/                      /var/www/
./logs/nginx/             →    /var/log/nginx/
```

## Project Structure

```
wp-docker/
├── docker-compose.yml              # Container orchestration
├── .env                            # Environment variables (DB passwords)
├── .env.example                    # Template for .env
│
├── new-site.sh                     # Site provisioning script
├── install-mkcert.sh               # mkcert installation helper
├── manage-sites.sh                 # Site management utilities
│
├── nginx/
│   ├── nginx.conf                  # Main Nginx configuration
│   ├── sites-available/            # All site configurations
│   │   ├── site.conf.template      # Template for new sites
│   │   ├── default.conf            # Default/catch-all
│   │   └── *.test.conf             # Individual site configs
│   ├── sites-enabled/              # Enabled sites (symlinks)
│   │   └── *.test.conf → ../sites-available/
│   └── ssl/
│       ├── certs/                  # SSL certificates (.pem)
│       └── private/                # Private keys (-key.pem)
│
├── sites/                          # WordPress installations
│   ├── site1/                      # WordPress files for site1.test
│   ├── site2/                      # WordPress files for site2.test
│   └── ...
│
└── logs/
    └── nginx/                      # Nginx access and error logs
```

## Key Benefits

✅ **No Container Restarts**: Nginx reloads config without downtime
✅ **No Compose Edits**: Static infrastructure, dynamic sites
✅ **Professional Pattern**: Same as production Nginx setups
✅ **SSL Everywhere**: Trusted certs via mkcert
✅ **Resource Efficient**: Single PHP pool serves all sites
✅ **Easy Debugging**: Standard Nginx config per site
✅ **Simple Workflow**: One script handles everything

## Database Creation

Databases can be created via:

1. **WordPress Installer** (Recommended)
   - Visit your site: `https://yoursite.test`
   - WordPress will prompt to create database
   - Easiest and most standard approach

2. **PhpMyAdmin**
   - Visit: `http://localhost:8080`
   - Login: `root` / password from `.env`
   - Create database manually

3. **MySQL CLI**
   ```bash
   docker exec -it wp-mysql mysql -u root -p
   CREATE DATABASE mysite_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

## Technical Details

**Container Network:** All containers on bridge network `network`
**PHP Extensions:** Pre-installed via wordpress:php8.2-fpm-alpine image
**SSL Protocol:** TLS handled automatically by modern browsers
**File Permissions:** WordPress files owned by www-data in containers
**Port Mapping:**
- 80 → HTTP (redirects to HTTPS)
- 443 → HTTPS (SSL)
- 3306 → MySQL (accessible from host)
- 8080 → PhpMyAdmin
