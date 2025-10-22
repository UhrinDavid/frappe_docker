#!/bin/bash

# Check Site in Running Containers Script
# Verifies that the installed site is accessible from running Frappe containers

set -e

echo "🔍 Checking site availability in running containers..."
echo "=================================================="

SITE_NAME=${FRAPPE_SITE_NAME_HEADER}
COMPOSE_FILE="docker-compose.zerops.yaml"

if [ -z "$SITE_NAME" ]; then
    echo "❌ Error: FRAPPE_SITE_NAME_HEADER environment variable not set"
    exit 1
fi

echo "🎯 Target site: $SITE_NAME"
echo ""

# Check 1: Sites directory in backend container
echo "1️⃣ Checking sites in backend container..."
if docker compose -f $COMPOSE_FILE exec backend ls sites/ 2>/dev/null; then
    echo "✅ Sites directory accessible in backend"
    
    if docker compose -f $COMPOSE_FILE exec backend test -d "sites/$SITE_NAME" 2>/dev/null; then
        echo "✅ Site '$SITE_NAME' directory found in backend"
        echo "📁 Site contents:"
        docker compose -f $COMPOSE_FILE exec backend ls -la "sites/$SITE_NAME/" | head -10
    else
        echo "❌ Site '$SITE_NAME' directory NOT found in backend!"
    fi
else
    echo "❌ Cannot access sites directory in backend container"
fi
echo ""

# Check 2: Site in bench (backend container)
echo "2️⃣ Checking site in Frappe bench (backend)..."
BACKEND_SITES=$(docker compose -f $COMPOSE_FILE exec backend bench --site all list-sites 2>/dev/null || echo "ERROR")
if [ "$BACKEND_SITES" != "ERROR" ]; then
    echo "📋 Sites found in backend bench:"
    echo "$BACKEND_SITES"
    
    if echo "$BACKEND_SITES" | grep -q "$SITE_NAME"; then
        echo "✅ Site '$SITE_NAME' is registered in backend bench"
    else
        echo "❌ Site '$SITE_NAME' NOT registered in backend bench"
    fi
else
    echo "❌ Cannot query sites from backend bench"
fi
echo ""

# Check 3: Site accessibility via web (if frontend is running)
echo "3️⃣ Checking web accessibility..."
if curl -s -I http://localhost:8080/api/method/ping 2>/dev/null | head -1 | grep -q "200"; then
    echo "✅ Frontend is responding on port 8080"
    
    # Test site-specific access
    if curl -s -H "Host: $SITE_NAME" http://localhost:8080/api/method/frappe.ping 2>/dev/null | grep -q "pong"; then
        echo "✅ Site '$SITE_NAME' is accessible via web"
    else
        echo "⚠️  Site '$SITE_NAME' web access test inconclusive"
        echo "   This might be normal if the site is still starting up"
    fi
else
    echo "⚠️  Frontend not responding (containers may still be starting)"
fi
echo ""

# Check 4: Shared storage verification  
echo "4️⃣ Shared storage check..."
echo "🔍 Checking if site data exists in Zerops shared storage..."

if [ -d "/mnt/sharedstorage/sites" ]; then
    echo "✅ Shared storage sites directory exists"
    echo "📂 Shared storage contents:"
    ls -la /mnt/sharedstorage/sites/
    
    if [ -d "/mnt/sharedstorage/sites/$SITE_NAME" ]; then
        echo "✅ Site '$SITE_NAME' found in shared storage"
        echo "📁 Site size: $(du -sh /mnt/sharedstorage/sites/$SITE_NAME | cut -f1)"
    else
        echo "❌ Site '$SITE_NAME' NOT found in shared storage!"
    fi
else
    echo "❌ Shared storage directory not found: /mnt/sharedstorage/sites"
fi
echo ""

# Summary
echo "🎯 Summary for site: $SITE_NAME"
echo "================================"
echo "Run this script after containers are fully started to verify site availability."
echo ""
echo "If site is missing from running containers:"
echo "1. Check if installation script completed successfully"
echo "2. Verify shared storage mount: /mnt/sharedstorage/sites"  
echo "3. Check container logs: docker compose -f $COMPOSE_FILE logs backend"
echo "4. Manual verification: docker compose -f $COMPOSE_FILE exec backend bench --site all list-sites"
echo "5. Check shared storage: ls -la /mnt/sharedstorage/sites/"
echo ""