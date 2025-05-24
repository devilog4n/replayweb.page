#!/bin/bash

# start-auto-commit.sh - Start the auto-commit watcher process
# Usage: ./start-auto-commit.sh [interval_in_seconds] [commit_message_prefix]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHER_SCRIPT="$SCRIPT_DIR/auto-commit-watcher.sh"
PID_FILE="$SCRIPT_DIR/.auto-commit-watcher.pid"

# Default settings
DEFAULT_INTERVAL=300  # 5 minutes
DEFAULT_PREFIX="auto:"

# Command line arguments
INTERVAL="${1:-$DEFAULT_INTERVAL}"
PREFIX="${2:-$DEFAULT_PREFIX}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if watcher script exists
if [ ! -f "$WATCHER_SCRIPT" ]; then
    echo -e "${RED}Error: Watcher script not found at $WATCHER_SCRIPT${NC}"
    exit 1
fi

# Check if already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null; then
        echo -e "${YELLOW}Auto-commit watcher is already running with PID $PID${NC}"
        echo -e "${YELLOW}To stop it, run: ./stop-auto-commit.sh${NC}"
        exit 0
    else
        echo -e "${YELLOW}Found stale PID file. Previous process is not running.${NC}"
        rm -f "$PID_FILE"
    fi
fi

# Start the watcher in the background
echo -e "${BLUE}Starting auto-commit watcher...${NC}"
echo -e "${BLUE}Checking interval: ${INTERVAL} seconds${NC}"
echo -e "${BLUE}Commit prefix: ${PREFIX}${NC}"

nohup "$WATCHER_SCRIPT" "$INTERVAL" "$PREFIX" > "$SCRIPT_DIR/auto-commit-output.log" 2>&1 &
PID=$!

# Save the PID
echo "$PID" > "$PID_FILE"

echo -e "${GREEN}Auto-commit watcher started with PID $PID${NC}"
echo -e "${GREEN}Logs will be written to:${NC}"
echo -e "  $SCRIPT_DIR/auto-commit.log (commit logs)"
echo -e "  $SCRIPT_DIR/auto-commit-output.log (process output)"
echo -e "${YELLOW}To stop the watcher, run: ./stop-auto-commit.sh${NC}"
