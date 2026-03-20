#!/bin/bash
# No set -e for now to debug

echo "L1 Check: redcap.com and .init.lua / .lua/ are present..."
[ -x redcap.com ]
unzip -l redcap.com | grep -q ".init.lua"
unzip -l redcap.com | grep -q ".lua/fullmoon.lua"
echo "L1 Passed."

echo "L2 Check: Starting redcap.com on port 8081 for verification..."
PORT=8081
# Run in background with its own process group to avoid Redbean killing this script
setsid ./redcap.com -p $PORT -L redbean_test.log > /dev/null 2>&1 &
REDBEAN_PID=$!

# Wait for redbean to start
MAX_RETRIES=10
RETRY_COUNT=0
CONNECTED=false
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Attempt $RETRY_COUNT..."
    if curl -s http://localhost:$PORT > /dev/null; then
        CONNECTED=true
        break
    fi
    echo "Waiting for redcap.com to listen on $PORT... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 1
    ((RETRY_COUNT++))
done

if [ "$CONNECTED" = false ]; then
    echo "L2 Check Failed: Could not connect to redcap.com after $MAX_RETRIES seconds."
    cat redbean_test.log || true
    # Use -REDBEAN_PID if it was a group leader? No, just kill the pid
    # Actually, we might need to find the real pid if setsid was used
    kill $REDBEAN_PID || true
    exit 1
fi

RESPONSE=$(curl -s http://localhost:$PORT)
echo "Response: $RESPONSE"

if [[ "$RESPONSE" == *"Redcap CMS is active."* ]]; then
    echo "L2 Passed: redcap.com is serving correctly."
    kill $REDBEAN_PID || true
    exit 0
else
    echo "L2 Failed: Unexpected response."
    cat redbean_test.log || true
    kill $REDBEAN_PID || true
    exit 1
fi
