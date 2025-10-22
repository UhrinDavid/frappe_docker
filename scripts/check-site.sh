#!/bin/bash

# ERPNext Site Health Check Script
# Checks if the ERPNext site is properly installed and running
# Script can be used for troubleshooting site issues directly in docker environment

set -e

echo "🔍 ERPNext Site Health Check"
echo "============================="

# Configuration from environment variables
SITE_NAME=${FRAPPE_SITE_NAME_HEADER}
COMPOSE_FILE="docker-compose.zerops.yaml"

# Database and Redis env vars expected to be provided by zerops/compose
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
ROOT_USER=${ROOT_USER}
DB_PASSWORD=${DB_PASSWORD}
REDIS_CACHE=${REDIS_CACHE}
REDIS_QUEUE=${REDIS_QUEUE}
SOCKETIO_PORT=${SOCKETIO_PORT}

if [ -z "$SITE_NAME" ]; then
    echo "❌ Error: FRAPPE_SITE_NAME_HEADER environment variable not set"
    exit 1
fi

echo "📋 Checking site: $SITE_NAME"
echo ""

# Check 1: Container Status
echo "1️⃣ Checking container status..."
if docker compose -f $COMPOSE_FILE ps | grep -q "Up"; then
    echo "✅ Containers are running"
    docker compose -f $COMPOSE_FILE ps
else
    echo "❌ Some containers are not running"
    docker compose -f $COMPOSE_FILE ps
fi
echo ""

# Check 2: Site Directory
echo "2️⃣ Checking site directory..."
if docker compose -f $COMPOSE_FILE exec -T backend test -d "sites/$SITE_NAME"; then
    echo "✅ Site directory exists: sites/$SITE_NAME"
    echo "📁 Site directory contents:"
    docker compose -f $COMPOSE_FILE exec -T backend ls -la "sites/$SITE_NAME/"
else
    echo "❌ Site directory not found: sites/$SITE_NAME"
fi
echo ""

# Check 3: Site in Bench
echo "3️⃣ Checking site in Frappe bench..."
SITES_LIST=$(docker compose -f $COMPOSE_FILE exec -T backend bench --site all list-sites 2>/dev/null || echo "")
if echo "$SITES_LIST" | grep -q "$SITE_NAME"; then
    echo "✅ Site is registered in Frappe bench"
    echo "📝 All sites: $SITES_LIST"
else
    echo "❌ Site not found in Frappe bench"
    echo "📝 Available sites: $SITES_LIST"
fi
echo ""

# Check 4: Site Configuration
echo "4️⃣ Checking site configuration..."
if docker compose -f $COMPOSE_FILE exec -T backend bench --site "$SITE_NAME" show-config &>/dev/null; then
    echo "✅ Site configuration is accessible"
    echo "⚙️ Site config excerpt:"
    docker compose -f $COMPOSE_FILE exec -T backend bench --site "$SITE_NAME" show-config | head -10
else
    echo "❌ Cannot access site configuration"
fi
echo ""

# Check 5: Installed Apps
echo "5️⃣ Checking installed apps..."
APPS_LIST=$(docker compose -f $COMPOSE_FILE exec -T backend bench --site "$SITE_NAME" list-apps 2>/dev/null || echo "")
if [ -n "$APPS_LIST" ]; then
    echo "✅ Apps are installed:"
    echo "$APPS_LIST"
    
    # Check for ERPNext specifically
    if echo "$APPS_LIST" | grep -q "erpnext"; then
        echo "✅ ERPNext app is installed"
    else
        echo "⚠️ ERPNext app not found in installed apps"
    fi
    
    # Check for custom XML Importer app
    if echo "$APPS_LIST" | grep -q "erpnext_xml_importer"; then
        echo "✅ XML Importer app is installed"
    else
        echo "⚠️ XML Importer app not found"
    fi
else
    echo "❌ Cannot retrieve installed apps list"
fi
echo ""

# Check 6: Database Connection
echo "6️⃣ Checking database connection..."
DB_NAME="${SITE_NAME//./_}"
DB_CMD="mariadb -h\"$DB_HOST\" -P\"$DB_PORT\" -u\"$ROOT_USER\" -p\"$DB_PASSWORD\" -e \"USE \\\`$DB_NAME\\\`; SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='$DB_NAME';\""

if docker compose -f $COMPOSE_FILE exec -T backend bash -lc "$DB_CMD" >/dev/null 2>&1; then
        echo "✅ Database connection successful and schema exists (or command ran)"
else
    echo "❌ Cannot connect to database"
fi
echo ""

# Check 6.1: Redis connectivity (parse host:port if needed)
echo "6️⃣.a Checking Redis connections..."
parse_redis_host_port() {
    # Accept formats: host:port or redis://host:port or host
    local input="$1"
    local host port
    if [[ "$input" =~ ^redis:// ]]; then
        input=${input#redis://}
    fi
    if [[ "$input" =~ : ]]; then
        host=${input%%:*}
        port=${input##*:}
    else
        host="$input"
        port=6379
    fi
    echo "$host" "$port"
}

for entry in "${REDIS_CACHE}" "${REDIS_QUEUE}"; do
    if [ -z "$entry" ]; then
        echo "⚠️  Redis entry missing (one of REDIS_CACHE/REDIS_QUEUE)"
        continue
    fi
    read host port <<< $(parse_redis_host_port "$entry")
    echo "Checking Redis at $host:$port"

    # Prefer redis-cli if available inside container, fallback to nc
    if docker compose -f $COMPOSE_FILE exec -T backend bash -lc "command -v redis-cli >/dev/null 2>&1"; then
        if docker compose -f $COMPOSE_FILE exec -T backend bash -lc "redis-cli -h $host -p $port ping" 2>/dev/null | grep -q PONG; then
            echo "✅ redis-cli: $host:$port replied PONG"
        else
            echo "❌ redis-cli: $host:$port did not reply PONG"
        fi
    else
        if docker compose -f $COMPOSE_FILE exec -T backend bash -lc "command -v nc >/dev/null 2>&1"; then
            if docker compose -f $COMPOSE_FILE exec -T backend bash -lc "echo > /dev/tcp/$host/$port" >/dev/null 2>&1; then
                echo "✅ TCP connect to $host:$port succeeded"
            else
                echo "❌ TCP connect to $host:$port failed"
            fi
        else
            echo "⚠️  Neither redis-cli nor nc available inside backend container; cannot test Redis connectivity"
        fi
    fi
done


# Check 7: Web Access
echo "7️⃣ Checking web access..."
if curl -s -I http://localhost:8080/api/method/ping | head -1 | grep -q "200 OK"; then
    echo "✅ Web server is responding"
    
    # Check if site is accessible
    if curl -s -H "Host: $SITE_NAME" http://localhost:8080/api/method/frappe.ping | grep -q "pong"; then
        echo "✅ Site is accessible via web"
    else
        echo "⚠️ Site may not be responding correctly"
    fi
else
    echo "❌ Web server is not responding"
fi
echo ""

# Summary
echo "🎯 Health Check Summary"
echo "======================"
echo "Site Name: $SITE_NAME"
echo "Timestamp: $(date)"
echo ""
echo "For detailed troubleshooting, check container logs:"
echo "  docker compose -f $COMPOSE_FILE logs backend"
echo "  docker compose -f $COMPOSE_FILE logs frontend"
echo ""