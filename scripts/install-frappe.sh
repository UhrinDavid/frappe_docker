#!/bin/bash

# Frappe Site Installation Script
# Creates and configures a new Frappe site with ERPNext and custom apps

set -e

echo "🏗️ Installing Frappe site and applications..."
echo "============================================"

# Configuration from environment variables
SITE_NAME=${FRAPPE_SITE_NAME_HEADER}
DB_PASSWORD=${DB_PASSWORD}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

if [ -z "$SITE_NAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "❌ Error: Missing required environment variables"
    echo "Required: FRAPPE_SITE_NAME_HEADER, DB_PASSWORD, ADMIN_PASSWORD"
    exit 1
fi

# Check if site already exists to avoid reinstallation
echo "🔍 Checking for existing site installation..."
SITE_EXISTS=$(docker compose --project-name herbatica-erpnext -f docker-compose.zerops.yaml run --rm backend bash -c '
  cd /home/frappe/frappe-bench 2>/dev/null || exit 1
  if [ -d "sites/'$FRAPPE_SITE_NAME_HEADER'" ] && bench --site all list-sites 2>/dev/null | grep -q "'$FRAPPE_SITE_NAME_HEADER'"; then
    echo "EXISTS"
  else
    echo "NOT_EXISTS"
  fi
' 2>/dev/null || echo "NOT_EXISTS")

if [ "$SITE_EXISTS" = "EXISTS" ]; then
    echo "♻️ Site '$SITE_NAME' already exists - running migration..."
    
    docker compose --project-name herbatica-erpnext -f docker-compose.zerops.yaml run --rm backend \
      bench --site "$SITE_NAME" migrate
    
    echo "✅ Existing site updated successfully!"
    exit 0
fi

echo "🆕 No existing site found - proceeding with fresh installation"
echo ""

echo "📋 Site Configuration:"
echo "  - Site Name: $SITE_NAME"
echo "  - Database Password: [HIDDEN]"
echo "  - Admin Password: [HIDDEN]"

# Create site using backend container (during build phase)
echo "🚀 Creating site using backend container..."
echo "Using 'docker compose run' for build-time execution..."
echo ""

# Use docker compose run (not exec) because containers are not running during build
docker compose --project-name herbatica-erpnext -f docker-compose.zerops.yaml run --rm backend \
  bench new-site --mariadb-user-host-login-scope=% --db-root-password "$DB_PASSWORD" --install-app erpnext --admin-password "$ADMIN_PASSWORD" "$SITE_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Site '$SITE_NAME' created successfully!"
    
    # Install XML Importer app if available
    echo "📦 Installing XML Importer app..."
    docker compose --project-name herbatica-erpnext -f docker-compose.zerops.yaml run --rm backend \
      bench --site "$SITE_NAME" install-app erpnext  erpnext_xml_importer
    
    if [ $? -eq 0 ]; then
        echo "✅ XML Importer app installed successfully!"
    else
        echo "⚠️ XML Importer app installation failed (app may not be available)"
    fi
else
    echo "❌ Site creation failed!"
    exit 1
fi

echo ""
echo "🎉 Frappe site installation completed successfully!"
echo "==============================================="
echo "✅ Site: $SITE_NAME"
echo "✅ Apps: frappe, erpnext, erpnext_xml_importer"
echo "✅ Ready for deployment!"