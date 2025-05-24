#!/bin/bash

# stop-auto-commit.sh - Stop the auto-commit watcher process

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.auto-commit-watcher.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    echo -e "${YELLOW}Auto-commit watcher is not running (no PID file found)${NC}"
    exit 0
fi

# Read the PID
PID=$(cat "$PID_FILE")

# Check if process is running
if ! ps -p "$PID" > /dev/null; then
    echo -e "${YELLOW}Auto-commit watcher is not running (process $PID not found)${NC}"
    rm -f "$PID_FILE"
    exit 0
fi

# Stop the process
echo -e "${BLUE}Stopping auto-commit watcher (PID: $PID)...${NC}"
kill "$PID"

# Check if process was stopped
sleep 1
if ps -p "$PID" > /dev/null; then
    echo -e "${YELLOW}Process didn't stop with SIGTERM, trying SIGKILL...${NC}"
    kill -9 "$PID"
    sleep 1
    
    if ps -p "$PID" > /dev/null; then
        echo -e "${RED}Failed to stop the process${NC}"
        exit 1
    fi
fi

# Remove PID file
rm -f "$PID_FILE"

echo -e "${GREEN}Auto-commit watcher stopped successfully${NC}"
