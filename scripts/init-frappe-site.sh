#!/bin/bash

# Frappe Site Initialization Script for Production Deployment
# This script runs before the main service starts to ensure the site exists and is configured

set -e

echo "🔧 Initializing Frappe site..."

# Configuration from environment variables
SITE_NAME=${FRAPPE_SITE_NAME_HEADER:-"localhost"}
DB_PASSWORD=${DB_PASSWORD:-"admin"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin"}
DB_HOST=${DB_HOST:-"db"}
DB_PORT=${DB_PORT:-"3306"}

echo "📋 Configuration: Site Name: $SITE_NAME, Database Host: $DB_HOST:$DB_PORT"

# Navigate to frappe bench directory
cd /home/frappe/frappe-bench

# Configure database and Redis connections
echo "🔗 Configuring connections..."
bench set-config -g db_host "$DB_HOST" || echo "DB host config already set"
bench set-config -gp db_port "$DB_PORT" || echo "DB port config already set"
bench set-config -g redis_cache "redis://${REDIS_CACHE}:6379" || echo "Redis cache config already set"
bench set-config -g redis_queue "redis://${REDIS_QUEUE}:6379" || echo "Redis queue config already set"
bench set-config -g redis_socketio "redis://${REDIS_QUEUE}:6379" || echo "Redis socketio config already set"
bench set-config -gp socketio_port "${SOCKETIO_PORT}" || echo "Socketio port config already set"

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
for i in {1..30}; do
    if mysql -h"$DB_HOST" -P"$DB_PORT" -uroot -p"$DB_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
        echo "✅ Database is ready!"
        break
    fi
    echo "   Attempt $i/30: Database not ready, waiting 5 seconds..."
    sleep 5
done

# Check if site exists in persistent volume
if [ -d "sites/$SITE_NAME" ]; then
    echo "✅ Site '$SITE_NAME' already exists, updating configuration"
    bench --site "$SITE_NAME" set-config db_host "$DB_HOST"
    bench --site "$SITE_NAME" set-config db_port "$DB_PORT"
    bench use "$SITE_NAME" || echo "Site already set as default"
else
    echo "🏗️  Creating new site: $SITE_NAME"
    if bench new-site "$SITE_NAME" \
        --db-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --install-app erpnext \
        --set-default; then
        echo "✅ Site created successfully!"
        
        # Install custom XML importer app
        echo "📦 Installing XML Importer app..."
        bench get-app --branch main erpnext_xml_importer https://github.com/UhrinDavid/erpnext_xml_importer.git || echo "⚠️ Failed to download XML importer"
        bench --site "$SITE_NAME" install-app erpnext_xml_importer || echo "⚠️ XML importer app installation failed"
        
        bench --site "$SITE_NAME" set-config developer_mode 0
        bench --site "$SITE_NAME" set-config maintenance_mode 0
        echo "🎉 Site '$SITE_NAME' is ready with XML Importer!"
    else
        echo "❌ Failed to create site. Checking if it exists..."
        if [ -d "sites/$SITE_NAME" ]; then
            echo "⚠️  Site directory exists but creation failed. Using existing site."
            bench use "$SITE_NAME" || echo "Could not set as default"
        else
            echo "💥 Site creation failed completely. Exiting."
            exit 1
        fi
    fi
fi

# Ensure proper ownership of sites directory
chown -R frappe:frappe sites/ || echo "Could not change ownership"
chmod -R 755 sites/ || echo "Could not change permissions"

echo "✅ Site initialization completed successfully!"