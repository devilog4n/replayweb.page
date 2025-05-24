#!/bin/bash

# auto-commit-watcher.sh - Monitor repository for changes and trigger auto-commit
# Usage: ./auto-commit-watcher.sh [interval_in_seconds] [commit_message_prefix]

# Configuration
REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.sh"
DEFAULT_INTERVAL=300  # 5 minutes
DEFAULT_PREFIX="auto:"
LOG_FILE="$SCRIPT_DIR/auto-commit.log"
CHECKPOINT_FILE="$SCRIPT_DIR/.last_commit_state"

# Command line arguments
INTERVAL="${1:-$DEFAULT_INTERVAL}"
PREFIX="${2:-$DEFAULT_PREFIX}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if auto-commit script exists
if [ ! -f "$AUTO_COMMIT_SCRIPT" ]; then
    echo -e "${RED}Error: Auto-commit script not found at $AUTO_COMMIT_SCRIPT${NC}"
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "$timestamp - $1"
    echo "$timestamp - $1" >> "$LOG_FILE"
}

# Function to check for changes in the repository
check_for_changes() {
    cd "$REPO_PATH" || {
        log "${RED}Error: Could not navigate to repository at $REPO_PATH${NC}"
        return 1
    }
    
    # Get the current state of the repository
    git update-index -q --refresh
    
    # Check if there are changes to tracked files
    if ! git diff-index --quiet HEAD --; then
        return 0  # Changes detected
    fi
    
    # Check if there are untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        return 0  # Untracked files detected
    fi
    
    return 1  # No changes detected
}

# Function to save the current state
save_state() {
    cd "$REPO_PATH" || return 1
    
    # Get the latest commit hash
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "none")
    
    # Get a list of untracked files
    local untracked_files=$(git ls-files --others --exclude-standard | sort | tr '\n' ' ')
    
    # Get a checksum of tracked files
    local tracked_checksum=$(git ls-files -s | md5sum)
    
    # Save to checkpoint file
    echo "$commit_hash" > "$CHECKPOINT_FILE"
    echo "$untracked_files" >> "$CHECKPOINT_FILE"
    echo "$tracked_checksum" >> "$CHECKPOINT_FILE"
}

# Function to check if state has changed
state_changed() {
    cd "$REPO_PATH" || return 0  # Assume changed if we can't check
    
    # If checkpoint file doesn't exist, state has changed
    if [ ! -f "$CHECKPOINT_FILE" ]; then
        return 0
    fi
    
    # Read the saved state
    local saved_commit_hash=$(sed -n '1p' "$CHECKPOINT_FILE")
    local saved_untracked=$(sed -n '2p' "$CHECKPOINT_FILE")
    local saved_checksum=$(sed -n '3p' "$CHECKPOINT_FILE")
    
    # Get the current state
    local current_commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "none")
    local current_untracked=$(git ls-files --others --exclude-standard | sort | tr '\n' ' ')
    local current_checksum=$(git ls-files -s | md5sum)
    
    # Compare
    if [ "$saved_commit_hash" != "$current_commit_hash" ] || \
       [ "$saved_untracked" != "$current_untracked" ] || \
       [ "$saved_checksum" != "$current_checksum" ]; then
        return 0  # State has changed
    fi
    
    return 1  # State has not changed
}

# Main loop
log "${GREEN}Starting auto-commit watcher for $REPO_PATH${NC}"
log "${BLUE}Checking for changes every $INTERVAL seconds${NC}"
log "${BLUE}Commit message prefix: $PREFIX${NC}"

# Initial state save
save_state

while true; do
    if state_changed; then
        log "${YELLOW}Repository state changed, checking for committable changes...${NC}"
        
        if check_for_changes; then
            log "${GREEN}Changes detected, running auto-commit...${NC}"
            
            # Generate commit message with timestamp
            TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
            COMMIT_MESSAGE="$PREFIX Update at $TIMESTAMP"
            
            # Run the auto-commit script
            bash "$AUTO_COMMIT_SCRIPT" "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1
            
            if [ $? -eq 0 ]; then
                log "${GREEN}Auto-commit successful${NC}"
            else
                log "${RED}Auto-commit failed, check the log for details${NC}"
            fi
        else
            log "${BLUE}No committable changes detected${NC}"
        fi
        
        # Update the state after commit attempt
        save_state
    else
        log "${BLUE}No changes detected${NC}"
    fi
    
    # Wait for the next check
    sleep "$INTERVAL"
done
