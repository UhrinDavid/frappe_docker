#!/bin/bash

# Shared Storage Preparation Script
# Prepares Zerops shared storage for complete Frappe bench persistence

set -e

echo "📁 Preparing shared storage for Frappe bench..."
echo "=============================================="

# Use Docker container to set up shared storage with proper permissions
docker compose -f docker-compose.zerops.yaml run --rm configurator bash -c '
  echo "🔧 Setting up shared storage for full bench persistence..."
  
  # Check if this is a fresh bench or existing one
  if [ ! -d "/home/frappe/frappe-bench/apps" ]; then
    echo "🆕 Fresh bench setup detected - initializing complete bench structure"
    
    # The bench directory is mounted, so we need to work within it
    cd /home/frappe/frappe-bench
    
    # Create essential subdirectories
    mkdir -p sites apps logs config
    echo "✅ Created essential bench directories"
    
    # Set proper permissions for the entire bench
    chmod -R 755 .
    echo "✅ Set bench permissions (755)"
    
  else
    echo "♻️ Existing bench found - verifying structure..."
    
    # Verify essential directories exist
    cd /home/frappe/frappe-bench
    for dir in sites apps logs config; do
      if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "✅ Created missing directory: $dir"
      else
        echo "📂 Directory exists: $dir"
      fi
    done
    
    # Ensure proper permissions
    chmod -R 755 .
    echo "✅ Verified/updated bench permissions"
  fi
  
  # Show bench structure
  echo "📋 Bench directory structure:"
  ls -la /home/frappe/frappe-bench/
  
  echo "🎯 Shared storage preparation completed!"
'

echo "✅ Shared storage prepared successfully!"
echo ""