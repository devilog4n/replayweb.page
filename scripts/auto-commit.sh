#!/bin/bash

# auto-commit.sh - Automatically commit and push changes to GitHub
# Usage: ./auto-commit.sh [custom commit message]

# Configuration
REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BRANCH="main"
DEFAULT_COMMIT_MESSAGE="auto: Update files"
DEFAULT_REMOTE="origin"

# Command line arguments
CUSTOM_MESSAGE="$1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to repository
cd "$REPO_PATH" || {
    echo -e "${RED}Error: Could not navigate to repository at $REPO_PATH${NC}"
    exit 1
}

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="$DEFAULT_BRANCH"
    echo -e "${YELLOW}Warning: Could not determine current branch, using $DEFAULT_BRANCH${NC}"
fi

echo -e "${BLUE}Checking for changes in $REPO_PATH (branch: $CURRENT_BRANCH)${NC}"

# Check for changes
git update-index -q --refresh
if git diff-index --quiet HEAD --; then
    # No changes
    echo -e "${YELLOW}No changes detected in tracked files${NC}"
    
    # Check for untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${GREEN}Untracked files detected${NC}"
    else
        echo -e "${YELLOW}No untracked files detected. Nothing to commit.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}Changes detected in tracked files${NC}"
fi

# Determine commit message
COMMIT_MESSAGE="${CUSTOM_MESSAGE:-$DEFAULT_COMMIT_MESSAGE}"

# Generate a timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
COMMIT_MESSAGE="$COMMIT_MESSAGE [$TIMESTAMP]"

echo -e "${BLUE}Adding all changes...${NC}"
git add .

echo -e "${BLUE}Committing changes with message: ${NC}\"$COMMIT_MESSAGE\""
git commit -m "$COMMIT_MESSAGE"

echo -e "${BLUE}Pushing to $DEFAULT_REMOTE $CURRENT_BRANCH...${NC}"
git push "$DEFAULT_REMOTE" "$CURRENT_BRANCH"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully committed and pushed changes to $DEFAULT_REMOTE/$CURRENT_BRANCH${NC}"
else
    echo -e "${RED}Error: Failed to push changes to $DEFAULT_REMOTE/$CURRENT_BRANCH${NC}"
    exit 1
fi
