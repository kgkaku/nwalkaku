#!/bin/bash

# ==============================================
# CONFIGURATION
# ==============================================
M3U_PLAYLIST="playlist.m3u"
JSON_PLAYLIST="playlist.json"
LOG_FILE="playlist_log.txt"
CHANNELS_FILE="channels.txt"
LOCAL_DIR="/storage/emulated/0/r1d3x6/YOUTUBE"
GIT_REPO="git@github.com:kgkaku/nwalkaku.git"  # Changed repo name
GIT_BRANCH="main"
TIMEOUT_SECONDS=15

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================
# INITIAL SETUP
# ==============================================
mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR" || exit

# Fix Git security
git config --global --add safe.directory "$LOCAL_DIR"

# ==============================================
# GITHUB SETUP
# ==============================================
setup_github() {
    echo -e "${CYAN}Configuring GitHub...${NC}"
    
    # SSH Setup
    mkdir -p ~/.ssh
    [ ! -f ~/.ssh/known_hosts ] && ssh-keyscan github.com >> ~/.ssh/known_hosts
    
    # Initialize Git
    if [ ! -d .git ]; then
        git init --quiet
        git remote add origin "$GIT_REPO"
        git checkout -b "$GIT_BRANCH" --quiet
    else
        # Ensure remote is correct
        git remote set-url origin "$GIT_REPO"
    fi
}

# ==============================================
# CHANNEL PROCESSING
# ==============================================
process_channels() {
    echo -e "${CYAN}Processing channels...${NC}"
    
    # Initialize files
    echo "#EXTM3U" > "$M3U_PLAYLIST"
    echo '[' > "$JSON_PLAYLIST"
    
    local total=$(grep -v '^#' "$CHANNELS_FILE" | wc -l)
    local count=0
    local success=0
    local first_entry=true
    
    while IFS='|' read -r name url; do
        # Skip empty/commented lines
        [[ -z "$name" || "$name" == \#* ]] && continue
        
        ((count++))
        echo -ne "${YELLOW}Processing $count/$total:${NC} $name..."
        
        # Fetch data with timeout
        stream=$(timeout $TIMEOUT_SECONDS yt-dlp -f "best" -g --no-warnings "$url" 2>> "$LOG_FILE")
        if [ -z "$stream" ]; then
            echo -e "${RED} FAILED${NC}"
            continue
        fi
        
        logo=$(timeout $TIMEOUT_SECONDS yt-dlp --get-thumbnail "$url" 2>> "$LOG_FILE")
        id=$(timeout $TIMEOUT_SECONDS yt-dlp --get-id "$url" 2>> "$LOG_FILE")
        
        # Write to M3U
        echo -e "#EXTINF:-1 tvg-logo=\"${logo}\",$name\n$stream" >> "$M3U_PLAYLIST"
        
        # Write to JSON
        if $first_entry; then
            first_entry=false
        else
            echo "," >> "$JSON_PLAYLIST"
        fi
        echo -n "{\"name\":\"$name\",\"logo\":\"${logo}\",\"url\":\"$stream\",\"id\":\"${id}\"}" >> "$JSON_PLAYLIST"
        
        echo -e "${GREEN} OK${NC}"
        ((success++))
    done < <(grep -v '^#' "$CHANNELS_FILE")
    
    echo "]" >> "$JSON_PLAYLIST"
    echo -e "\n${GREEN}Processed $success/$total channels successfully${NC}"
}

# ==============================================
# GITHUB PUSH (UPDATED)
# ==============================================
push_to_github() {
    echo -e "${CYAN}Pushing to GitHub...${NC}"
    
    # Ensure we're on the correct branch
    git checkout -b "$GIT_BRANCH" --quiet 2>/dev/null || git branch -M "$GIT_BRANCH"
    
    git add .
    git commit -m "Auto-update $(date +'%Y-%m-%d %H:%M')" --quiet
    
    # First try normal push
    if git push -u origin "$GIT_BRANCH" --quiet 2>/dev/null; then
        echo -e "${GREEN}Success!${NC}"
    else
        # Fallback to force push
        echo -e "${YELLOW}Retrying with force push...${NC}"
        if git push -u origin "$GIT_BRANCH" --force --quiet; then
            echo -e "${GREEN}Success!${NC}"
        else
            echo -e "${RED}Push failed!${NC}"
            echo "Manual recovery:"
            echo "1. cd $LOCAL_DIR"
            echo "2. git branch -M main"
            echo "3. git push -u origin main --force"
            return 1
        fi
    fi
    
    echo -e "View at: ${YELLOW}https://github.com/kgkaku/nwalkaku${NC}"
}

# ==============================================
# MAIN EXECUTION
# ==============================================
clear
echo -e "${CYAN}YouTube Playlist Generator${NC}"
echo -e "============================\n"

# Verify channels file exists
if [ ! -f "$CHANNELS_FILE" ]; then
    echo -e "${RED}Error: Missing $CHANNELS_FILE${NC}"
    echo "Create it with format: Channel Name|URL"
    exit 1
fi

setup_github
process_channels
push_to_github

echo -e "\n${GREEN}Done!${NC}"
