# ⚡ Quick Setup Guide

Get WordPress running in **less than 5 minutes**.

---

## 📋 Prerequisites

```bash
# Install mkcert (Ubuntu/Debian)
sudo apt install libnss3-tools
wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
chmod +x mkcert
sudo mv mkcert /usr/local/bin/
mkcert -install
```

---

## 🚀 Setup in 3 Steps

### 1️⃣ Clone & Configure

```bash
git clone <your-repo-url> wp-docker
cd wp-docker

# Edit .env if needed (optional)
nano .env
```

### 2️⃣ Add Your First Site

**Option A: Automated (Recommended)**

```bash
./new-site.sh
```

Enter your domain (e.g., `mysite.test`) and follow prompts.

**Option B: Manual**

```bash
DOMAIN="mysite.test"
SITE_NAME="mysite"

# 1. Create Nginx config
sed "s/DOMAIN/$DOMAIN/g" nginx/sites-available/site.conf.template > nginx/sites-available/${DOMAIN}.conf
sed -i "s|/var/www/SITE_NAME|/var/www/$SITE_NAME|g" nginx/sites-available/${DOMAIN}.conf
ln -s ../sites-available/${DOMAIN}.conf nginx/sites-enabled/${DOMAIN}.conf

# 2. Download WordPress
mkdir -p sites/$SITE_NAME && cd sites/$SITE_NAME
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1 && rm latest.tar.gz
cd ../..

# 3. Generate SSL
mkcert -cert-file nginx/ssl/certs/${DOMAIN}.pem \
       -key-file nginx/ssl/private/${DOMAIN}-key.pem \
       $DOMAIN

# 4. Add to hosts
echo "127.0.0.1    $DOMAIN" | sudo tee -a /etc/hosts

# 5. Start Docker
docker compose up -d
```

### 3️⃣ Install WordPress

1. Visit `https://mysite.test`
2. Create database in PhpMyAdmin: `http://localhost:8080`
   - Username: `root`
   - Password: See `.env` file
3. Complete WordPress installation with database credentials:
   - **Database Name**: `mysite_db` (created in PhpMyAdmin)
   - **Username**: `root`
   - **Password**: From `.env` → `DB_ROOT_PASSWORD`
   - **Database Host**: `mysql`
   - **Table Prefix**: `wp_`

**Done!** 🎉

---

## 🌐 Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Your Site | `https://mysite.test` | Set during WP install |
| PhpMyAdmin | `http://localhost:8080` | root / (see .env) |
| MySQL | `localhost:3306` | root / (see .env) |

---

## ➕ Add More Sites

```bash
./new-site.sh
```

Or repeat Step 2 with a different domain name. **No need to restart Docker Compose!**

---

## 🛠️ Common Commands

```bash
# Start containers
docker compose up -d

# Stop containers
docker compose down

# Restart Nginx (after config changes)
docker exec wp-nginx nginx -s reload

# View logs
docker compose logs -f nginx
docker compose logs -f php

# MySQL CLI
docker exec -it wp-mysql mysql -u root -p

# Fix permissions
sudo chown -R $USER:$USER sites/
```

---

## 🐛 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| **SSL not trusted** | `mkcert -install` |
| **Can't access site** | Check `/etc/hosts` has `127.0.0.1 yoursite.test` |
| **502 Bad Gateway** | `docker compose restart php` |
| **Permission denied** | `sudo chown -R $USER:$USER sites/` |
| **Nginx config error** | `docker exec wp-nginx nginx -t` |

---

## 📖 Full Documentation

For detailed information, see:
- **[README.md](README.md)** - Complete documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical details
- **[SETUP-COMPLETE.md](SETUP-COMPLETE.md)** - Post-setup info

---

**Happy coding!** 🚀
