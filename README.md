# WordPress Docker Multi-Site Boilerplate

A professional Docker-based development environment for running **unlimited WordPress sites** with Nginx (sites-available/enabled), PHP-FPM, MySQL, and PhpMyAdmin.

**Perfect for**: agencies, developers managing multiple projects, or anyone running several WordPress sites locally.

## ✨ Features

- 🚀 **Unlimited Sites**: Simple workflow without editing `docker-compose.yml`
- 🔒 **SSL via mkcert**: Trusted local HTTPS certificates
- 🔧 **Nginx sites-available/enabled**: Professional configuration management
- 🐘 **Single PHP-FPM Pool**: Official WordPress PHP 8.2-FPM image serving all sites
- 🗄️ **MySQL 8.0**: Shared database server (separate database per site)
- 📊 **PhpMyAdmin**: Web-based MySQL administration
- ⚡ **Optimized**: OPcache, Gzip, FastCGI tuning

---

## 📋 Prerequisites

- **Docker** (20.10+) and **Docker Compose** (2.0+)
- **mkcert** for local SSL certificates
- Linux/macOS (Windows WSL2 supported)

### Install mkcert (Ubuntu/Debian)

```bash
sudo apt install libnss3-tools
wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
chmod +x mkcert
sudo mv mkcert /usr/local/bin/
mkcert -install
```

---

## 🚀 Quick Start

### The Simple Workflow

Adding a new WordPress site involves 5 simple steps:

1. **Create Nginx config** → `nginx/sites-available/yoursite.test.conf`
2. **Download WordPress** → `sites/yoursite/`
3. **Generate SSL cert** → `mkcert yoursite.test`
4. **Add to /etc/hosts** → `127.0.0.1 yoursite.test`
5. **Start containers** → `docker-compose up -d`

### Option 1: Automated (Recommended)

Use the `new-site.sh` script:

```bash
./new-site.sh
```

Enter your domain (e.g., `mysite.test`) and the script will:
- Create Nginx configuration
- Download latest WordPress
- Generate SSL certificates
- Offer to add to /etc/hosts
- Offer to start Docker containers

Visit `https://mysite.test` and complete the WordPress installation!

**Database Setup:** Use WordPress installer or PhpMyAdmin to create the database.

### Option 2: Manual Setup

```bash
# 1. Create Nginx configuration
DOMAIN="mysite.test"
SITE_NAME="mysite"

sed "s/DOMAIN/$DOMAIN/g" nginx/sites-available/site.conf.template > nginx/sites-available/${DOMAIN}.conf
sed -i "s|/var/www/SITE_NAME|/var/www/$SITE_NAME|g" nginx/sites-available/${DOMAIN}.conf
ln -s ../sites-available/${DOMAIN}.conf nginx/sites-enabled/${DOMAIN}.conf

# 2. Download WordPress
mkdir -p sites/$SITE_NAME && cd sites/$SITE_NAME
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1 && rm latest.tar.gz
cd ../..

# 3. Generate SSL certificate
mkcert -cert-file nginx/ssl/certs/${DOMAIN}.pem \
       -key-file nginx/ssl/private/${DOMAIN}-key.pem \
       $DOMAIN

# 4. Add to /etc/hosts
echo "127.0.0.1    $DOMAIN" | sudo tee -a /etc/hosts

# 5. Start Docker
docker compose up -d
```

---

## 🌐 Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Your WordPress Sites | `https://yoursite.test` | Set during WP installation |
| PhpMyAdmin | `http://localhost:8080` | Username: `root`<br>Password: See `.env` |
| MySQL (external) | `localhost:3306` | Username: `root`<br>Password: See `.env` |

---

## 📂 Project Structure

```
wp-docker/
├── docker-compose.yml           # Container orchestration
├── .env                         # Environment variables (DB passwords)
├── new-site.sh                  # Automated site provisioning ⭐
├── install-mkcert.sh            # mkcert installation helper
├── manage-sites.sh              # Site management utilities
│
├── nginx/
│   ├── nginx.conf              # Main Nginx config
│   ├── sites-available/        # All site configurations
│   │   ├── site.conf.template  # Template for new sites
│   │   ├── default.conf        # Catch-all/default site
│   │   └── *.test.conf         # Your site configs
│   ├── sites-enabled/          # Symlinks to enabled sites
│   │   └── *.test.conf → ../sites-available/
│   └── ssl/
│       ├── certs/              # SSL certificates (.pem)
│       └── private/            # SSL private keys (-key.pem)
│
└── sites/                      # WordPress installations
    ├── site1/                  # Site 1 WordPress files
    ├── site2/                  # Site 2 WordPress files
    └── ...
```

---

## 🔧 WordPress Database Setup

When installing WordPress, use these database settings:

- **Database Name**: Create via PhpMyAdmin or MySQL CLI (e.g., `mysite_db`)
- **Username**: `root` (or create dedicated user)
- **Password**: Check `.env` file → `DB_ROOT_PASSWORD`
- **Database Host**: `mysql`
- **Table Prefix**: `wp_`

### Create Database (via CLI)

```bash
# Connect to MySQL
docker exec -it wp-mysql mysql -u root -p

# Enter password from .env

# Create database and user
CREATE DATABASE mysite_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'mysite_user'@'%' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON mysite_db.* TO 'mysite_user'@'%';
FLUSH PRIVILEGES;
EXIT;
```

---

## 📖 Documentation

- **[QUICK-SETUP.md](QUICK-SETUP.md)** - ⚡ Fast setup guide (< 5 minutes)
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture overview
- **[SETUP-COMPLETE.md](SETUP-COMPLETE.md)** - Post-setup verification

---

## 🎯 Example Workflow

Let's add a site called `portfolio.test`:

```bash
# Run the automated script
./new-site.sh

# Or manually:
DOMAIN="portfolio.test"
sed "s/DOMAIN/$DOMAIN/g" nginx/sites-available/site.conf.template > nginx/sites-available/${DOMAIN}.conf
sed -i "s|/var/www/SITE_NAME|/var/www/portfolio|g" nginx/sites-available/${DOMAIN}.conf
ln -s ../sites-available/${DOMAIN}.conf nginx/sites-enabled/${DOMAIN}.conf

mkdir -p sites/portfolio && cd sites/portfolio
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1 && rm latest.tar.gz
cd ../..

mkcert -cert-file nginx/ssl/certs/portfolio.test.pem \
       -key-file nginx/ssl/private/portfolio.test-key.pem \
       portfolio.test

echo "127.0.0.1    portfolio.test" | sudo tee -a /etc/hosts

docker compose up -d
```

Visit `https://portfolio.test` and install WordPress!

---

## 🛠️ Common Commands

```bash
# Start all containers
docker compose up -d

# Stop all containers
docker compose down

# View logs
docker compose logs -f nginx
docker compose logs -f php

# Restart Nginx (after config changes)
docker exec wp-nginx nginx -s reload

# Test Nginx configuration
### Nginx Configuration Error?

docker exec wp-nginx nginx -t

# Access MySQL CLI
docker exec -it wp-mysql mysql -u root -p

# Fix file permissions
sudo chown -R $USER:$USER sites/yoursite
```

---

## 🐛 Troubleshooting

### SSL Certificate Not Trusted?
```bash
mkcert -install
```

### Can't Access Site?
```bash
# Verify /etc/hosts entry
cat /etc/hosts | grep yoursite.test

# Check Nginx config
docker exec wp-nginx nginx -t

# Check containers are running
docker compose ps
```

### 502 Bad Gateway?
```bash
# Restart PHP-FPM
docker compose restart php

# Check PHP logs
docker compose logs php
```

### Permission Denied?
```bash
# Fix ownership
sudo chown -R $USER:$USER sites/
```

---

## 🔐 Security Notes

- This setup is for **local development only**
- `.env` contains database passwords (never commit to git)
- mkcert certificates are trusted locally only
- For production, use proper SSL certificates (Let's Encrypt)

---

## 🤝 Contributing

Contributions welcome! Please open an issue or pull request.

---

## 📄 License

MIT License - feel free to use for personal or commercial projects.

---

## ⚙️ Technical Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Web Server | Nginx (Alpine) | Reverse proxy, SSL termination, static files |
| PHP | WordPress Official Image (PHP 8.2-FPM) | WordPress execution |
| Database | MySQL 8.0 | Data storage |
| DB Admin | PhpMyAdmin | Database management UI |
| SSL | mkcert | Local trusted certificates |
| Orchestration | Docker Compose | Container management |

---

## 🎓 Learn More

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [WordPress Documentation](https://wordpress.org/support/)
- [mkcert on GitHub](https://github.com/FiloSottile/mkcert)

---

**Happy developing!** 🚀
