#!/bin/bash

# Shared Storage Preparation Script
# Prepares Zerops shared storage for Frappe site data

set -e

echo "📁 Preparing shared storage for Frappe..."
echo "========================================"

# Use Docker container to set up shared storage with proper permissions
docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
  echo "🔧 Setting up shared storage directory..."
  
  # Create the sites directory if it doesn'\''t exist
  if [ ! -d "/home/frappe/frappe-bench/sites" ]; then
    mkdir -p /home/frappe/frappe-bench/sites
    echo "✅ Created sites directory"
  else
    echo "📂 Sites directory already exists"
  fi
  
  # Set proper permissions
  chmod 755 /home/frappe/frappe-bench/sites
  echo "✅ Set directory permissions (755)"
  
  # Show directory info
  echo "📋 Directory info:"
  ls -la /home/frappe/frappe-bench/ | grep sites
  
  echo "🎯 Shared storage preparation completed!"
'

echo "✅ Shared storage prepared successfully!"
echo ""