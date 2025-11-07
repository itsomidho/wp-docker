.PHONY: help up down restart logs status add-site clean backup install-mkcert

# Default target
help:
	@echo "WordPress Multi-Site Docker Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make install-mkcert  - Install mkcert for SSL certificates"
	@echo "  make up              - Start all containers"
	@echo "  make down            - Stop all containers"
	@echo "  make restart         - Restart all containers"
	@echo "  make logs            - View all logs"
	@echo "  make status          - Show container status"
	@echo "  make add-site        - Add a new WordPress site"
	@echo "  make clean           - Remove all containers (keeps data)"
	@echo "  make clean-all       - Remove everything including volumes (⚠️ deletes data)"
	@echo "  make backup          - Backup all databases"
	@echo "  make shell-php       - Access PHP container"
	@echo "  make shell-db        - Access MySQL container"
	@echo "  make shell-nginx     - Access Nginx container"
	@echo "  make reload-nginx    - Test and reload Nginx config"

# Install mkcert
install-mkcert:
	./install-mkcert.sh

# Start all containers
up:
	docker compose up -d
	@echo "Containers started. Give MySQL 30 seconds to initialize if this is the first run."

# Stop all containers
down:
	docker compose down

# Restart all containers
restart:
	docker compose restart

# View logs
logs:
	docker compose logs -f

# Show container status
status:
	docker compose ps

# Add new site
add-site:
	./new-site.sh

# Clean up containers (keep data)
clean:
	docker compose down

# Clean everything including volumes
clean-all:
	@echo "⚠️  WARNING: This will delete all WordPress files and databases!"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose down -v; \
		rm -rf sites/*/; \
		echo "All data removed."; \
	else \
		echo "Cancelled."; \
	fi

# Backup all databases
backup:
	@mkdir -p backups
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	echo "Creating backup..."; \
	docker exec wp-mysql mysqldump -u root -p$$(grep DB_ROOT_PASSWORD .env | cut -d '=' -f2) --all-databases > backups/all_databases_$$timestamp.sql; \
	echo "Backup saved to: backups/all_databases_$$timestamp.sql"

# Access PHP container shell
shell-php:
	docker exec -it wp-php sh

# Access MySQL container shell
shell-db:
	docker exec -it wp-mysql bash

# Access Nginx container shell
shell-nginx:
	docker exec -it wp-nginx sh

# Test and reload Nginx
reload-nginx:
	docker exec wp-nginx nginx -t
	docker exec wp-nginx nginx -s reload
