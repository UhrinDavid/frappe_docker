#!/bin/bash

# Service Connection Check Script for Zerops Managed Services
# Validates that MariaDB and Redis services are ready before installation

set -e

echo "🔗 Checking Zerops managed service connections..."
echo "==============================================="

# Step 0: Verify shared storage accessibility
echo "0️⃣ Verifying shared storage accessibility..."
docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
    echo "   Testing shared storage mount..."
    
    # Check if the sites directory is accessible
    if [ -d "/home/frappe/frappe-bench/sites" ]; then
        echo "✅ Shared storage directory accessible: /home/frappe/frappe-bench/sites"
        
        # Test write permissions
        if touch /home/frappe/frappe-bench/sites/.storage-test 2>/dev/null; then
            echo "✅ Shared storage is writable"
            rm -f /home/frappe/frappe-bench/sites/.storage-test
        else
            echo "❌ Shared storage is not writable!"
            exit 1
        fi
        
        # Show storage info
        echo "📂 Storage info:"
        df -h /home/frappe/frappe-bench/sites | tail -1
    else
        echo "❌ Shared storage directory not accessible!"
        echo "Expected: /home/frappe/frappe-bench/sites"
        exit 1
    fi
'
echo ""

# Configuration from environment variables
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
ROOT_USER=${ROOT_USER}
DB_PASSWORD=${DB_PASSWORD}

if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$ROOT_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ Error: Missing required database environment variables"
    echo "Required: DB_HOST, DB_PORT, ROOT_USER, DB_PASSWORD"
    exit 1
fi

# Run connection checks within Docker container to access Zerops network
docker compose -f docker-compose.zerops.yaml run --rm \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e ROOT_USER="$ROOT_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  configurator bash -c '
    echo "1️⃣ Testing MariaDB connection..."
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
    echo ""

    echo "2️⃣ Testing Redis cache connection..."
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
    echo ""

    echo "3️⃣ Testing Redis queue connection..."
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
    echo ""
    
    echo "🎯 All service connections verified successfully!"
    echo "   ✅ Storage: /home/frappe/frappe-bench/sites (writable)"
    echo "   ✅ MariaDB: $DB_HOST:$DB_PORT"
    echo "   ✅ Redis Cache: rediscache:6379"
    echo "   ✅ Redis Queue: redisqueue:6379"
'

echo "✅ All Zerops managed services and storage are ready!"
echo ""