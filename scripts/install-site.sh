#!/bin/bash#!/bin/bash



# Main Frappe/ERPNext Site Installation Orchestrator# Frappe/ERPNext Site Installation Script

# Coordinates the complete site installation process using modular scripts# This script creates and configures a new Frappe site with ERPNext and custom apps

# Runs during Zerops deployment before starting application services

set -e

set -e

echo "🚀 Starting Frappe/ERPNext Installation Process"

echo "=============================================="echo "🚀 Starting Frappe site installation..."

echo "Timestamp: $(date)"

echo ""# Step 1: Prepare shared storage using Docker container

echo "📁 Preparing shared storage..."

# Configuration from environment variables (no defaults - must be provided)docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '

SITE_NAME=${FRAPPE_SITE_NAME_HEADER}  echo "Creating shared storage directory..."

DB_PASSWORD=${DB_PASSWORD}  mkdir -p /home/frappe/frappe-bench/sites

ADMIN_PASSWORD=${ADMIN_PASSWORD}  chmod 755 /home/frappe/frappe-bench/sites

DB_HOST=${DB_HOST}  echo "✅ Shared storage prepared at /home/frappe/frappe-bench/sites"

DB_PORT=${DB_PORT}'

REDIS_CACHE=${REDIS_CACHE}

REDIS_QUEUE=${REDIS_QUEUE}# Step 2: Check service connections using Docker container  

SOCKETIO_PORT=${SOCKETIO_PORT}echo "🔗 Checking service connections..."

docker compose -f docker-compose.zerops.yaml run --rm \

echo "📋 Installation Configuration:"  -e DB_HOST="$DB_HOST" \

echo "  - Site Name: $SITE_NAME"  -e DB_PORT="$DB_PORT" \

echo "  - Database Host: $DB_HOST:$DB_PORT"  -e ROOT_USER="$ROOT_USER" \

echo "  - Redis Cache: $REDIS_CACHE"  -e DB_PASSWORD="$DB_PASSWORD" \

echo "  - Redis Queue: $REDIS_QUEUE"  configurator bash -c '

echo ""    echo "1️⃣ Checking database connection..."

    echo "   Host: $DB_HOST:$DB_PORT"

# Step 1: Prepare shared storage    echo "   User: $ROOT_USER"

echo "STEP 1: Shared Storage Preparation"

echo "=================================="    DB_ATTEMPTS=0

chmod +x scripts/prepare-storage.sh    while [ $DB_ATTEMPTS -lt 10 ] && ! mariadb -h ${DB_HOST} -P ${DB_PORT} -u ${ROOT_USER} -p${DB_PASSWORD} -e "SELECT 1;" 2>/dev/null; do

./scripts/prepare-storage.sh        DB_ATTEMPTS=$((DB_ATTEMPTS + 1))

        echo "   Database not ready (attempt $DB_ATTEMPTS/10), waiting 5 seconds..."

# Step 2: Check service connections        sleep 5

echo "STEP 2: Service Connection Validation"    done

echo "===================================="

chmod +x scripts/check-services.sh    if [ $DB_ATTEMPTS -ge 10 ]; then

./scripts/check-services.sh        echo "❌ Database connection failed after 10 attempts"

        exit 1

# Step 3: Install Frappe site and apps    fi

echo "STEP 3: Frappe Site Installation"    echo "✅ Database connection established"

echo "==============================="

chmod +x scripts/install-frappe.sh    echo "2️⃣ Checking Redis cache connection..."

./scripts/install-frappe.sh    echo "   Host: rediscache:6379"



# Step 4: Post-installation verification    REDIS_CACHE_ATTEMPTS=0

echo "STEP 4: Post-Installation Verification"    while [ $REDIS_CACHE_ATTEMPTS -lt 10 ] && ! redis-cli -h rediscache -p 6379 ping 2>/dev/null; do

echo "====================================="        REDIS_CACHE_ATTEMPTS=$((REDIS_CACHE_ATTEMPTS + 1))

chmod +x scripts/post-install-check.sh        echo "   Redis cache not ready (attempt $REDIS_CACHE_ATTEMPTS/10), waiting 5 seconds..."

./scripts/post-install-check.sh        sleep 5

    done

echo ""

echo "🎯 INSTALLATION PROCESS COMPLETED SUCCESSFULLY!"    if [ $REDIS_CACHE_ATTEMPTS -ge 10 ]; then

echo "=============================================="        echo "❌ Redis cache connection failed after 10 attempts"

echo "✅ Shared storage prepared"        exit 1

echo "✅ Service connections verified"    fi

echo "✅ Frappe site installed"    echo "✅ Redis cache connection established"

echo "✅ Post-installation checks passed"

echo ""    echo "3️⃣ Checking Redis queue connection..."

echo "🚀 Site '$SITE_NAME' is ready for deployment!"    echo "   Host: redisqueue:6379"

echo "Timestamp: $(date)"
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