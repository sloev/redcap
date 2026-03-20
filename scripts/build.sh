#!/bin/bash
set -e

REDBEAN_URL="https://redbean.dev/redbean-3.0.0.com"

echo "Downloading base Redbean..."
wget -qO base.com $REDBEAN_URL
chmod +x base.com

echo "Building redcap.com..."
cp base.com redcap.com
zip redcap.com .init.lua .lua/db.lua .lua/api.lua .lua/markdown.lua .lua/fullmoon.lua .lua/blueprints.lua admin/index.html admin/dashboard.html

echo "Building redcap-fleet.com..."
cp base.com redcap-fleet.com
mkdir -p .tmp_fleet
cp .lua/fleet_init.lua .tmp_fleet/.init.lua
zip -j redcap-fleet.com .tmp_fleet/.init.lua
zip redcap-fleet.com fleet/index.html fleet/login.html
rm -rf .tmp_fleet

echo "Build complete."
ls -lh redcap.com redcap-fleet.com
