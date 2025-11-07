#!/bin/bash

# WordPress Site Provisioning Script
# Workflow:
# 1. Create Nginx configuration file
# 2. Download WordPress into sites directory
# 3. Generate SSL certificates with mkcert
# 4. Show instructions for /etc/hosts
# 5. Remind to run docker compose up -d

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}✓${NC} $1"; }
print_step() { echo -e "${GREEN}[STEP]${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Get domain name
echo "======================================"
echo "  New WordPress Site Setup"
echo "======================================"
echo ""
read -p "Enter domain name (e.g., mysite.test): " domain

if [ -z "$domain" ]; then
    print_error "Domain name cannot be empty!"
fi

# Extract site name from domain (remove .test)
site_name="${domain%.test}"
site_name="${site_name//./-}"  # Replace dots with dashes

echo ""
echo "Domain: $domain"
echo "Site directory: sites/$site_name"
echo ""
read -p "Continue? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Create Nginx configuration
print_step "1/4 Creating Nginx configuration..."
mkdir -p nginx/sites-available nginx/sites-enabled

if [ -f "nginx/sites-available/${domain}.conf" ]; then
    print_warning "Config nginx/sites-available/${domain}.conf already exists. Skipping."
else
    if [ ! -f "nginx/sites-available/site.conf.template" ]; then
        print_error "Template file nginx/sites-available/site.conf.template not found!"
    fi
    
    sed "s/DOMAIN/$domain/g" nginx/sites-available/site.conf.template > "nginx/sites-available/${domain}.conf"
    sed -i "s|/var/www/SITE_NAME|/var/www/$site_name|g" "nginx/sites-available/${domain}.conf"
    sed -i "s/SITE_NAME/$site_name/g" "nginx/sites-available/${domain}.conf"
    print_info "Created nginx/sites-available/${domain}.conf"
fi

# Create symlink
if [ -L "nginx/sites-enabled/${domain}.conf" ]; then
    print_info "Symlink already exists in sites-enabled"
else
    ln -s "../sites-available/${domain}.conf" "nginx/sites-enabled/${domain}.conf"
    print_info "Created symlink in sites-enabled"
fi

# Step 2: Download WordPress
print_step "2/4 Downloading WordPress..."
mkdir -p "sites/$site_name"

if [ "$(ls -A "sites/$site_name" 2>/dev/null | grep -v '^\.gitkeep$')" ]; then
    print_warning "Directory sites/$site_name is not empty. Skipping WordPress download."
else
    print_info "Downloading WordPress..."
    tmpdir=$(mktemp -d)
    curl -fsSL https://wordpress.org/latest.tar.gz -o "$tmpdir/wordpress.tar.gz"
    tar -xzf "$tmpdir/wordpress.tar.gz" -C "$tmpdir"
    shopt -s dotglob
    mv "$tmpdir/wordpress"/* "sites/$site_name/"
    shopt -u dotglob
    rm -rf "$tmpdir"
    print_info "WordPress downloaded to sites/$site_name"
fi

# Step 3: Generate SSL certificates
print_step "3/4 Generating SSL certificates..."
mkdir -p nginx/ssl/certs nginx/ssl/private

if ! command -v mkcert >/dev/null 2>&1; then
    print_warning "mkcert not installed. Please install it: https://github.com/FiloSottile/mkcert"
    print_warning "Skipping SSL certificate generation."
else
    if [ -f "nginx/ssl/certs/${domain}.pem" ]; then
        print_info "SSL certificate already exists for ${domain}"
    else
        print_info "Installing mkcert CA (if needed)..."
        mkcert -install 2>/dev/null || true
        
        print_info "Generating certificate for ${domain}..."
        mkcert -cert-file "nginx/ssl/certs/${domain}.pem" \
               -key-file "nginx/ssl/private/${domain}-key.pem" \
               "${domain}" 2>/dev/null
        
        print_info "SSL certificates created:"
        echo "  - nginx/ssl/certs/${domain}.pem"
        echo "  - nginx/ssl/private/${domain}-key.pem"
    fi
fi

# Step 4: Instructions
print_step "4/4 Final steps..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ Site configuration complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo ""
echo "1. Add to /etc/hosts (requires sudo):"
echo -e "   ${GREEN}echo '127.0.0.1    ${domain}' | sudo tee -a /etc/hosts${NC}"
echo ""
echo "2. Start/restart Docker containers:"
echo -e "   ${GREEN}docker compose up -d${NC}"
echo ""
echo "3. Visit your site:"
echo -e "   ${GREEN}https://${domain}${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files created:"
echo "  • nginx/sites-available/${domain}.conf"
echo "  • nginx/sites-enabled/${domain}.conf → (symlink)"
echo "  • sites/${site_name}/ (WordPress files)"
echo "  • nginx/ssl/certs/${domain}.pem"
echo "  • nginx/ssl/private/${domain}-key.pem"
echo ""

# Optional: Ask to add to /etc/hosts now
echo ""
read -p "Add to /etc/hosts now? (y/n): " add_hosts
if [[ "$add_hosts" =~ ^[Yy]$ ]]; then
    if grep -q "${domain}" /etc/hosts 2>/dev/null; then
        print_info "${domain} already in /etc/hosts"
    else
        echo "127.0.0.1    ${domain}" | sudo tee -a /etc/hosts >/dev/null
        print_info "Added ${domain} to /etc/hosts"
    fi
fi

echo ""
read -p "Run 'docker compose up -d' now? (y/n): " run_docker
if [[ "$run_docker" =~ ^[Yy]$ ]]; then
    docker compose up -d
    echo ""
    print_info "Containers started! Visit: https://${domain}"
else
    print_info "Remember to run: docker compose up -d"
fi

echo ""
