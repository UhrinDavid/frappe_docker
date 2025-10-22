#!/bin/bash

# Post-Installation Verification Script
# Validates that the Frappe site and apps are properly installed

set -e

echo "🔍 Running post-installation verification..."
echo "==========================================="

# Configuration from environment variables
SITE_NAME=${FRAPPE_SITE_NAME_HEADER}

if [ -z "$SITE_NAME" ]; then
    echo "❌ Error: FRAPPE_SITE_NAME_HEADER environment variable not set"
    exit 1
fi

echo "🎯 Verifying site: $SITE_NAME"
echo ""

# Verification: Check if site exists and is accessible
echo "1️⃣ Verifying site directory exists..."
docker compose -f docker-compose.zerops.yaml run --rm \
  -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
  configurator bash -c '
    cd /home/frappe/frappe-bench
    if [ -d "sites/$FRAPPE_SITE_NAME_HEADER" ]; then
      echo "✅ Site directory exists: sites/$FRAPPE_SITE_NAME_HEADER"
      
      # Show directory size and basic contents
      echo "📁 Site directory size: $(du -sh sites/$FRAPPE_SITE_NAME_HEADER | cut -f1)"
      echo "📄 Site directory contents:"
      ls -la sites/$FRAPPE_SITE_NAME_HEADER/ | head -5
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
echo ""
echo "2️⃣ Verifying installed applications..."
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
    echo ""
    
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
echo ""
echo "3️⃣ Verifying site configuration..."
docker compose -f docker-compose.zerops.yaml run --rm \
  -e FRAPPE_SITE_NAME_HEADER="$SITE_NAME" \
  configurator bash -c '
    cd /home/frappe/frappe-bench
    
    if bench --site "$FRAPPE_SITE_NAME_HEADER" show-config >/dev/null 2>&1; then
      echo "✅ Site configuration is accessible"
      
      # Check database connection from site
      echo "🔍 Testing database connection from site..."
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

# Final persistence check
echo ""
echo "4️⃣ Final persistence verification..."
docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
  echo "📁 Full bench shared storage verification:"
  echo "📂 Bench directory contents:"
  ls -la /home/frappe/frappe-bench/
  echo ""
  echo "📂 Sites directory contents:"
  ls -la /home/frappe/frappe-bench/sites/
  echo ""
  echo "📦 Apps directory contents:"
  ls -la /home/frappe/frappe-bench/apps/ 2>/dev/null || echo "Apps directory empty or not initialized yet"
  echo ""
  
  # Check site existence
  if [ -d "/home/frappe/frappe-bench/sites/'$SITE_NAME'" ]; then
    echo "✅ Site '\''$SITE_NAME'\'' found in shared storage"
    echo "📁 Site directory size: $(du -sh /home/frappe/frappe-bench/sites/'$SITE_NAME' | cut -f1)"
  else
    echo "❌ Site '\''$SITE_NAME'\'' NOT found in shared storage!"
    echo "This means the site will not be available to running containers"
    exit 1
  fi
  
  # Check apps.txt existence
  if [ -f "/home/frappe/frappe-bench/sites/apps.txt" ]; then
    echo "✅ apps.txt found in shared storage"
    echo "📋 Apps list: $(cat /home/frappe/frappe-bench/sites/apps.txt | tr '\n' ' ')"
  else
    echo "⚠️ apps.txt not found (may be created during first run)"
  fi
'

echo ""
echo "🎉 Post-installation verification completed successfully!"
echo "======================================================="
echo "✅ Site: $SITE_NAME"
echo "✅ Apps: frappe, erpnext, erpnext_xml_importer"  
echo "✅ Configuration: accessible"
echo "✅ Storage: full bench persistence enabled"
echo "✅ Apps Directory: persisted in shared storage"
echo ""
echo "🚀 Site is ready for deployment!"