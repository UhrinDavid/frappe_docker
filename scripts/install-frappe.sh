#!/bin/bash

# Frappe Site Installation Script
# Creates and configures a new Frappe site with ERPNext and custom apps

set -e

echo "🏗️ Installing Frappe site and applications..."
echo "============================================"

# First, check if site already exists to avoid reinstallation
echo "🔍 Checking for existing site installation..."
SITE_EXISTS=$(docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
  cd /home/frappe/frappe-bench 2>/dev/null || exit 1
  if [ -d "sites/'$FRAPPE_SITE_NAME_HEADER'" ] && bench --site all list-sites 2>/dev/null | grep -q "'$FRAPPE_SITE_NAME_HEADER'"; then
    echo "EXISTS"
  else
    echo "NOT_EXISTS"
  fi
' 2>/dev/null || echo "NOT_EXISTS")

if [ "$SITE_EXISTS" = "EXISTS" ]; then
    echo "♻️ Site '$FRAPPE_SITE_NAME_HEADER' already exists - skipping installation"
    echo "🔄 Running migration to ensure site is up to date..."
    
    docker compose -f docker-compose.zerops.yaml run --rm \
      -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
      configurator bash -c '
        cd /home/frappe/frappe-bench
        echo "Running site migration..."
        bench --site "$FRAPPE_SITE_NAME_HEADER" migrate
        echo "✅ Migration completed"
      '
    
    echo "✅ Existing site updated successfully!"
    echo ""
    exit 0
fi

echo "🆕 No existing site found - proceeding with fresh installation"
echo ""

# Configuration from environment variables (no defaults - must be provided)
SITE_NAME=${FRAPPE_SITE_NAME_HEADER}
DB_PASSWORD=${DB_PASSWORD}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
REDIS_CACHE=${REDIS_CACHE}
REDIS_QUEUE=${REDIS_QUEUE}
SOCKETIO_PORT=${SOCKETIO_PORT}

if [ -z "$SITE_NAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "❌ Error: Missing required environment variables"
    echo "Required: FRAPPE_SITE_NAME_HEADER, DB_PASSWORD, ADMIN_PASSWORD"
    exit 1
fi

echo "📋 Site Configuration:"
echo "  - Site Name: $SITE_NAME"
echo "  - Database Host: $DB_HOST:$DB_PORT"
echo "  - Redis Cache: $REDIS_CACHE"
echo "  - Redis Queue: $REDIS_QUEUE"
echo ""

# Start with a fresh container to install the site
echo "📦 Starting Frappe site installation container..."

# Run the installation inside a Docker container
docker compose -f docker-compose.zerops.yaml run --rm \
  -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  -e REDIS_CACHE="$REDIS_CACHE" \
  -e REDIS_QUEUE="$REDIS_QUEUE" \
  -e SOCKETIO_PORT="$SOCKETIO_PORT" \
  configurator bash -c '
    echo "🏗️  Setting up Frappe configuration..."
    
    # Navigate to bench directory
    cd /home/frappe/frappe-bench
    
    # Set up basic configuration
    ls -1 apps > sites/apps.txt
    bench set-config -g db_host $DB_HOST
    bench set-config -gp db_port $DB_PORT
    bench set-config -g redis_cache "redis://$REDIS_CACHE"
    bench set-config -g redis_queue "redis://$REDIS_QUEUE"
    bench set-config -g redis_socketio "redis://$REDIS_QUEUE"
    bench set-config -gp socketio_port $SOCKETIO_PORT
    
    echo "✅ Frappe configuration completed"
    
    # Check if site already exists
    if [ ! -d "sites/$FRAPPE_SITE_NAME_HEADER" ]; then
      echo "🆕 Creating new site: $FRAPPE_SITE_NAME_HEADER"
      
      bench new-site "$FRAPPE_SITE_NAME_HEADER" \
        --mariadb-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket
      
      echo "✅ Site created successfully"
      
      echo "📦 Installing ERPNext app..."
      bench --site "$FRAPPE_SITE_NAME_HEADER" install-app erpnext
      echo "✅ ERPNext installed successfully"
      
      echo "🔧 Installing custom XML Importer app (pre-installed in image)..."
      bench --site "$FRAPPE_SITE_NAME_HEADER" install-app xml_importer
      echo "✅ XML Importer app installed to site successfully"
      
      echo "🔄 Running site migration..."
      bench --site "$FRAPPE_SITE_NAME_HEADER" migrate
      echo "✅ Site migration completed"
      
      echo "🎉 Site installation completed successfully!"
    else
      echo "♻️  Site $FRAPPE_SITE_NAME_HEADER already exists"
      echo "🔄 Running migration to ensure site is up to date..."
      bench --site "$FRAPPE_SITE_NAME_HEADER" migrate
      echo "✅ Migration completed"
    fi
  '

echo "✅ Frappe site installation completed!"
echo ""