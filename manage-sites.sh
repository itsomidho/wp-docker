#!/bin/bash

# WordPress Multi-Site Management Script
# Manage all WordPress sites in the Docker environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

show_help() {
    echo "WordPress Multi-Site Management Script"
    echo ""
    echo "Usage: ./manage-sites.sh [command]"
    echo ""
    echo "Commands:"
    echo "  add              - Add a new WordPress site (runs new-site.sh)"
    echo "  start [site]     - Start all sites or a specific site"
    echo "  stop [site]      - Stop all sites or a specific site"
    echo "  restart [site]   - Restart all sites or a specific site"
    echo "  list             - List all configured sites"
    echo "  logs [site]      - Show logs for all sites or a specific site"
    echo "  status           - Show status of all containers"
    echo "  hosts            - Show hosts file entries needed"
    echo "  help             - Show this help message"
    echo ""
}

list_sites() {
    print_header "=== Configured WordPress Sites ==="
    echo ""
    
    # Extract site names from docker-compose.yml
    sites=$(grep -E "^\s+[a-z0-9_]+:" docker-compose.yml | grep -v "db:\|nginx:\|phpmyadmin:" | sed 's/://g' | tr -d ' ')
    
    if [ -z "$sites" ]; then
        print_warning "No WordPress sites configured yet."
        return
    fi
    
    for site in $sites; do
        domain=$(grep "server_name" "nginx/sites/${site}.conf" 2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)
        container="wp_$site"
        status=$(docker ps -a --filter "name=$container" --format "{{.Status}}" 2>/dev/null || echo "Not created")
        
        echo "Site: $site"
        echo "  Domain: $domain"
        echo "  Container: $container"
        echo "  Status: $status"
        echo ""
    done
}

show_hosts() {
    print_header "=== Required /etc/hosts Entries ==="
    echo ""
    
    sites=$(grep -E "^\s+[a-z0-9_]+:" docker-compose.yml | grep -v "db:\|nginx:\|phpmyadmin:" | sed 's/://g' | tr -d ' ')
    
    for site in $sites; do
        domain=$(grep "server_name" "nginx/sites/${site}.conf" 2>/dev/null | awk '{print $2}' | tr -d ';' | head -1)
        echo "127.0.0.1    $domain"
    done
    
    echo ""
    print_info "Add these entries to your /etc/hosts file to access the sites locally."
}

start_sites() {
    if [ -n "$1" ]; then
        print_info "Starting site: $1"
        docker compose up -d "$1"
    else
        print_info "Starting all sites..."
        docker compose up -d
    fi
}

stop_sites() {
    if [ -n "$1" ]; then
        print_info "Stopping site: $1"
        docker compose stop "$1"
    else
        print_info "Stopping all sites..."
        docker compose down
    fi
}

restart_sites() {
    if [ -n "$1" ]; then
        print_info "Restarting site: $1"
        docker compose restart "$1"
    else
        print_info "Restarting all sites..."
        docker compose restart
    fi
}

show_logs() {
    if [ -n "$1" ]; then
        print_info "Showing logs for: $1"
        docker compose logs -f "$1"
    else
        print_info "Showing logs for all containers..."
        docker compose logs -f
    fi
}

show_status() {
    print_header "=== Docker Containers Status ==="
    echo ""
    docker compose ps
}

add_site() {
    print_info "Launching new site setup script..."
    ./new-site.sh
}

# Main
case "${1:-help}" in
    add)
        add_site
        ;;
    start)
        start_sites "$2"
        ;;
    stop)
        stop_sites "$2"
        ;;
    restart)
        restart_sites "$2"
        ;;
    list)
        list_sites
        ;;
    logs)
        show_logs "$2"
        ;;
    status)
        show_status
        ;;
    hosts)
        show_hosts
        ;;
    help|*)
        show_help
        ;;
esac
