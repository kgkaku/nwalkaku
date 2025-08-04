#!/bin/bash

# ==============================================
# CONFIGURATION
# ==============================================
M3U_PLAYLIST="playlistm3u"
JSON_PLAYLIST="playlist.json"
LOG_FILE="playlistlog.txt"
CHANNELS_FILE="channels.txt"
LOCAL_DIR="/storage/emulated/0/r1d3x6/YOUTUBE"
GIT_REPO="git@github.com:kgkaku/nwalkaku.git"
GIT_BRANCH="main"
TIMEOUT_SECONDS=15  # Increased timeout to 15 seconds

# Colors for output
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

# Fix Git security error
git config --global --add safe.directory "$LOCAL_DIR"

# ==============================================
# GITHUB SSH SETUP
# ==============================================
setup_github() {
    echo -e "${CYAN}Configuring GitHub SSH...${NC}"
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
        ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
        chmod 600 ~/.ssh/known_hosts
    fi
    
    git config --global user.name "Playlist Push Bot"
    git config --global user.email "221880753+kgkaku@users.noreply.github.com"  # Replace with your GitHub no-reply email
}

# ==============================================
# CHANNEL PROCESSING
# ==============================================
process_channels() {
    echo -e "${CYAN}Processing channels...${NC}"
    
    # Initialize files
    echo "#EXTM3U" > "$M3U_PLAYLIST"
    echo '[' > "$JSON_PLAYLIST"
    
    local total=$(wc -l < "$CHANNELS_FILE")
    local count=0
    local success=0
    local first_entry=true
    
    while IFS= read -r line; do
        ((count++))
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        
        echo -ne "${YELLOW}Processing $count/$total:${NC} ${line%%|*}..."
        
        # Extract URL and name (format: "Channel Name|URL")
        local name="${line%%|*}"
        local url="${line#*|}"
        
        # Fetch stream with timeout
        local stream=$(timeout $TIMEOUT_SECONDS yt-dlp -f "best" -g --no-warnings "$url" 2>> "$LOG_FILE")
        
        if [ -z "$stream" ]; then
            echo -e "${RED} TIMEOUT${NC}"
            continue
        fi
        
        # Get metadata
        local logo=$(timeout $TIMEOUT_SECONDS yt-dlp --get-thumbnail "$url" 2>> "$LOG_FILE")
        local id=$(timeout $TIMEOUT_SECONDS yt-dlp --get-id "$url" 2>> "$LOG_FILE")
        
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
    done < "$CHANNELS_FILE"
    
    # Finalize JSON
    echo -e "\n]" >> "$JSON_PLAYLIST"
    echo -e "\n${GREEN}Processed $success/$total channels successfully${NC}"
}

# ==============================================
# GIT PUSH
# ==============================================
push_to_github() {
    echo -e "${CYAN}Pushing to GitHub...${NC}"
    
    if [ ! -d .git ]; then
        git init --quiet
        git remote add origin "$GIT_REPO"
        git branch -M "$GIT_BRANCH"
    fi
    
    git add .
    git commit -m "Auto-update $(date +'%Y-%m-%d %H:%M')" --quiet
    
    if git push -u origin "$GIT_BRANCH" --quiet; then
        echo -e "${GREEN}Success!${NC} View at:"
        echo -e "${YELLOW}https://github.com/$(echo $GIT_REPO | cut -d: -f2 | sed 's/.git$//')${NC}"
    else
        echo -e "${RED}Push failed!${NC} Debug with:"
        echo "cd $LOCAL_DIR && GIT_SSH_COMMAND='ssh -v' git push"
    fi
}

# ==============================================
# MAIN EXECUTION
# ==============================================
clear
echo -e "${CYAN}YouTube Playlist Generator${NC}"
echo -e "============================\n"

setup_github
process_channels
push_to_github

echo -e "\n${GREEN}Done!${NC}"