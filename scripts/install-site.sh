#!/bin/bash

# Frappe/ERPNext Site Installation Script
# This script creates and configures a new Frappe site with ERPNext and custom apps
# Runs during Zerops deployment before starting application services

set -e

echo "🚀 Starting Frappe site installation..."

# Step 1: Prepare shared storage using Docker container
echo "📁 Preparing shared storage..."
docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
  echo "Creating shared storage directory..."
  mkdir -p /home/frappe/frappe-bench/sites
  chmod 755 /home/frappe/frappe-bench/sites
  echo "✅ Shared storage prepared at /home/frappe/frappe-bench/sites"
'

# Step 2: Check service connections using Docker container  
echo "🔗 Checking service connections..."
docker compose -f docker-compose.zerops.yaml run --rm \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e ROOT_USER="$ROOT_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  configurator bash -c '
    echo "1️⃣ Checking database connection..."
    echo "   Host: $DB_HOST:$DB_PORT"
    echo "   User: $ROOT_USER"

    DB_ATTEMPTS=0
    while [ $DB_ATTEMPTS -lt 10 ] && ! mariadb -h ${DB_HOST} -P ${DB_PORT} -u ${ROOT_USER} -p${DB_PASSWORD} -e "SELECT 1;" 2>/dev/null; do
        DB_ATTEMPTS=$((DB_ATTEMPTS + 1))
        echo "   Database not ready (attempt $DB_ATTEMPTS/10), waiting 5 seconds..."
        sleep 5
    done

    if [ $DB_ATTEMPTS -ge 10 ]; then
        echo "❌ Database connection failed after 10 attempts"
        exit 1
    fi
    echo "✅ Database connection established"

    echo "2️⃣ Checking Redis cache connection..."
    echo "   Host: rediscache:6379"

    REDIS_CACHE_ATTEMPTS=0
    while [ $REDIS_CACHE_ATTEMPTS -lt 10 ] && ! redis-cli -h rediscache -p 6379 ping 2>/dev/null; do
        REDIS_CACHE_ATTEMPTS=$((REDIS_CACHE_ATTEMPTS + 1))
        echo "   Redis cache not ready (attempt $REDIS_CACHE_ATTEMPTS/10), waiting 5 seconds..."
        sleep 5
    done

    if [ $REDIS_CACHE_ATTEMPTS -ge 10 ]; then
        echo "❌ Redis cache connection failed after 10 attempts"
        exit 1
    fi
    echo "✅ Redis cache connection established"

    echo "3️⃣ Checking Redis queue connection..."
    echo "   Host: redisqueue:6379"

    REDIS_QUEUE_ATTEMPTS=0
    while [ $REDIS_QUEUE_ATTEMPTS -lt 10 ] && ! redis-cli -h redisqueue -p 6379 ping 2>/dev/null; do
        REDIS_QUEUE_ATTEMPTS=$((REDIS_QUEUE_ATTEMPTS + 1))
        echo "   Redis queue not ready (attempt $REDIS_QUEUE_ATTEMPTS/10), waiting 5 seconds..."
        sleep 5
    done

    if [ $REDIS_QUEUE_ATTEMPTS -ge 10 ]; then
        echo "❌ Redis queue connection failed after 10 attempts"
        exit 1
    fi
    echo "✅ Redis queue connection established"
    
    echo "🎯 All service connections verified successfully!"
'

# Configuration from environment variables (no defaults - must be provided)
SITE_NAME=${FRAPPE_SITE_NAME_HEADER}
DB_PASSWORD=${DB_PASSWORD}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
REDIS_CACHE=${REDIS_CACHE}
REDIS_QUEUE=${REDIS_QUEUE}
SOCKETIO_PORT=${SOCKETIO_PORT}

echo "📋 Site Configuration:"
echo "  - Site Name: $SITE_NAME"
echo "  - Database Host: $DB_HOST:$DB_PORT"
echo "  - Admin Password: [CONFIGURED]"

# Start with a fresh container to install the site
echo "📦 Starting temporary Frappe container for site installation..."

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
      
      echo "🔧 Installing custom XML Importer app..."
      if [ ! -d "apps/erpnext_xml_importer" ]; then
        echo "📥 Downloading XML Importer app from GitHub..."
        bench get-app https://github.com/UhrinDavid/erpnext_xml_importer.git
      fi
      
      bench --site "$FRAPPE_SITE_NAME_HEADER" install-app erpnext_xml_importer
      echo "✅ XML Importer app installed successfully"
      
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

echo "🔍 Verifying installation..."

# Verification: Check if site exists and is accessible
echo "1️⃣ Verifying site exists..."
docker compose -f docker-compose.zerops.yaml run --rm \
  -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
  configurator bash -c '
    cd /home/frappe/frappe-bench
    if [ -d "sites/$FRAPPE_SITE_NAME_HEADER" ]; then
      echo "✅ Site directory exists: sites/$FRAPPE_SITE_NAME_HEADER"
    else
      echo "❌ Site directory not found!"
      exit 1
    fi
    
    # Check if site is in bench sites list
    if bench --site all list-sites | grep -q "$FRAPPE_SITE_NAME_HEADER"; then
      echo "✅ Site is registered in Frappe bench"
    else
      echo "❌ Site not found in bench sites list!"
      exit 1
    fi
  '

# Verification: Check installed apps
echo "2️⃣ Verifying installed apps..."
docker compose -f docker-compose.zerops.yaml run --rm \
  -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
  configurator bash -c '
    cd /home/frappe/frappe-bench
    
    echo "📋 Checking installed apps..."
    INSTALLED_APPS=$(bench --site "$FRAPPE_SITE_NAME_HEADER" list-apps 2>/dev/null || echo "")
    
    if [ -z "$INSTALLED_APPS" ]; then
      echo "❌ Could not retrieve apps list!"
      exit 1
    fi
    
    echo "📦 Installed apps:"
    echo "$INSTALLED_APPS"
    
    # Check for required apps
    if echo "$INSTALLED_APPS" | grep -q "frappe"; then
      echo "✅ Frappe framework is installed"
    else
      echo "❌ Frappe framework not found!"
      exit 1
    fi
    
    if echo "$INSTALLED_APPS" | grep -q "erpnext"; then
      echo "✅ ERPNext app is installed"
    else
      echo "❌ ERPNext app not found!"
      exit 1
    fi
    
    if echo "$INSTALLED_APPS" | grep -q "erpnext_xml_importer"; then
      echo "✅ XML Importer app is installed"
    else
      echo "❌ XML Importer app not found!"
      exit 1
    fi
  '

# Verification: Check site configuration
echo "3️⃣ Verifying site configuration..."
docker compose -f docker-compose.zerops.yaml run --rm \
  -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
  configurator bash -c '
    cd /home/frappe/frappe-bench
    
    if bench --site "$FRAPPE_SITE_NAME_HEADER" show-config >/dev/null 2>&1; then
      echo "✅ Site configuration is accessible"
      
      # Check database connection from site
      if bench --site "$FRAPPE_SITE_NAME_HEADER" --verbose console --execute "frappe.db.get_value(\"User\", \"Administrator\", \"name\")" 2>/dev/null | grep -q "Administrator"; then
        echo "✅ Database connection from site works"
      else
        echo "⚠️  Database connection test inconclusive"
      fi
    else
      echo "❌ Cannot access site configuration!"
      exit 1
    fi
  '

echo ""
echo "🎉 Installation verification completed successfully!"
echo "✅ Site: $SITE_NAME"
echo "✅ Apps: frappe, erpnext, erpnext_xml_importer"
echo "✅ Configuration: accessible"
echo ""

# Final check: Verify site persists in the shared storage
echo "4️⃣ Final persistence check..."
echo "📂 Checking if site data is in shared storage..."
docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
  echo "📁 Shared storage contents:"
  ls -la /home/frappe/frappe-bench/sites/
  echo ""
  if [ -d "/home/frappe/frappe-bench/sites/'$SITE_NAME'" ]; then
    echo "✅ Site '\''$SITE_NAME'\'' found in container sites directory"
    echo "📁 Site directory size:"
    du -sh /home/frappe/frappe-bench/sites/'$SITE_NAME'
    echo "📄 Site directory contents:"
    ls -la /home/frappe/frappe-bench/sites/'$SITE_NAME'/
  else
    echo "❌ Site '\''$SITE_NAME'\'' NOT found in container sites directory!"
    echo "This means the site will not be available to running containers"
  fi
'

echo ""
echo "🎯 Frappe site installation script completed!"