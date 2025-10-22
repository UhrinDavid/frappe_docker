#!/bin/bash

# Database and Redis Connection Check Script
# Validates that all required services are available before proceeding with deployment

set -e

echo "🔗 Checking service connections..."
echo "================================="

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

# Check 1: Database Connection
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
echo ""

# Check 2: Redis Cache Connection
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
echo ""

# Check 3: Redis Queue Connection
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
echo ""

# Summary
echo "🎯 All service connections verified successfully!"
echo "   ✅ Database (MariaDB): $DB_HOST:$DB_PORT"
echo "   ✅ Redis Cache: rediscache:6379"
echo "   ✅ Redis Queue: redisqueue:6379"
echo ""
echo "Proceeding with deployment..."