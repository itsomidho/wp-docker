#!/bin/bash

# Setup script for mkcert on Linux/macOS
# Installs mkcert and initializes local CA for trusted SSL certificates

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "======================================"
echo "  mkcert Installer & CA Setup"
echo "======================================"
echo ""

# Check if mkcert is already installed
if command -v mkcert >/dev/null 2>&1; then
  print_info "mkcert is already installed: $(which mkcert)"
  mkcert -install
  print_info "Local CA installed/updated."
  exit 0
fi

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Linux*)
    print_info "Detected Linux"
    
    # Check for libnss3-tools
    if ! dpkg -l | grep -q libnss3-tools; then
      print_info "Installing libnss3-tools..."
      sudo apt update && sudo apt install -y libnss3-tools
    fi
    
    print_info "Downloading mkcert for Linux..."
    MKCERT_URL="https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64"
    curl -fsSL "$MKCERT_URL" -o /tmp/mkcert
    chmod +x /tmp/mkcert
    sudo mv /tmp/mkcert /usr/local/bin/mkcert
    ;;
    
  Darwin*)
    print_info "Detected macOS"
    
    if ! command -v brew >/dev/null 2>&1; then
      print_error "Homebrew not found. Install from https://brew.sh"
      exit 1
    fi
    
    print_info "Installing mkcert via Homebrew..."
    brew install mkcert
    ;;
    
  *)
    print_error "Unsupported OS: $OS"
    print_warn "Please install mkcert manually from https://github.com/FiloSottile/mkcert"
    exit 1
    ;;
esac

# Install local CA
print_info "Installing local CA..."
mkcert -install

echo ""
print_info "mkcert installed successfully!"
print_info "You can now run ./new-site.sh to provision WordPress sites with SSL."
