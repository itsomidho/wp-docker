#!/bin/bash

# One-line installer for wp-local-dev:
#   curl -fsSL https://raw.githubusercontent.com/itsomidho/wp-local-dev/main/install.sh | bash
#   wget -qO- https://raw.githubusercontent.com/itsomidho/wp-local-dev/main/install.sh | bash
#
# Clones the repo, sets up .env from .env.example, and symlinks `wpdev` onto
# PATH. Doesn't touch the rest of the host system otherwise — no sudo, no
# package installs. Docker itself and mkcert (trusted local SSL) are
# separate, deliberate steps (see README / `wpdev install-mkcert`) since
# they're bigger asks than cloning a dev environment.

set -e

REPO_URL="https://github.com/itsomidho/wp-local-dev.git"
INSTALL_DIR="${WP_LOCAL_DEV_DIR:-$HOME/wp-local-dev}"
BIN_DIR="${WP_LOCAL_DEV_BIN_DIR:-$HOME/.local/bin}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info()    { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

echo "wp-local-dev installer"
echo "======================="
echo

command -v git >/dev/null 2>&1 || print_error "git is required but not found. Install it and re-run."
command -v docker >/dev/null 2>&1 || print_error "docker is required but not found. Install Docker first: https://docs.docker.com/get-docker/"
docker compose version >/dev/null 2>&1 || print_error "docker compose (the v2 plugin) is required but not found."
print_info "git, docker, and docker compose found"

if [ -e "$INSTALL_DIR" ]; then
    if [ -d "$INSTALL_DIR/.git" ] && git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null | grep -q "wp-local-dev"; then
        print_warning "${INSTALL_DIR} already looks like a wp-local-dev checkout — leaving it as-is, skipping clone"
    else
        print_error "${INSTALL_DIR} already exists and isn't a wp-local-dev checkout. Set WP_LOCAL_DEV_DIR to a different path and re-run."
    fi
else
    print_info "Cloning into ${INSTALL_DIR}"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

if [ -f .env ]; then
    print_warning ".env already exists, leaving it as-is"
else
    cp .env.example .env
    print_info "Created .env from .env.example"
fi

chmod +x wpdev install-mkcert.sh 2>/dev/null || true

mkdir -p "$BIN_DIR"
ln -sf "${INSTALL_DIR}/wpdev" "${BIN_DIR}/wpdev"
print_info "Linked wpdev -> ${BIN_DIR}/wpdev"

case ":$PATH:" in
    *":${BIN_DIR}:"*) ;;
    *)
        print_warning "${BIN_DIR} isn't on your PATH yet — add this to your shell profile:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

echo
print_info "Installed at ${INSTALL_DIR}"
echo
echo "Next steps:"
echo "  wpdev install-mkcert   # one-time: trusted local SSL"
echo "  wpdev up                # start the stack"
echo "  wpdev add                # provision your first site"
