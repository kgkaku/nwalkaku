#!/bin/bash

# Termux-compatible YouTube Live Fetcher
# Uses system-installed yt-dlp (no pip required)

# Configuration
WORK_DIR="/storage/emulated/0/r1d3x6/YOUTUBE"
YTDLP="/data/data/com.termux/files/usr/bin/yt-dlp"  # Termux binary path
GIT_REPO="https://github.com/kgkaku/nwalkaku.git"

# Files
CHANNELS_FILE="$WORK_DIR/channels.txt"
LOGOS_FILE="$WORK_DIR/logos.txt"
STATUS_FILE="$WORK_DIR/channel_status.json"

# Initialize working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || {
    echo "Failed to access $WORK_DIR"
    exit 1
}

# Check dependencies
check_deps() {
    for cmd in $YTDLP jq curl git; do
        if ! command -v "$cmd" >/dev/null; then
            echo "Missing dependency: $cmd"
            echo "Install with: pkg install $(pkg which $cmd | cut -d'/' -f4)"
            exit 1
        fi
    done
}

# Load logos into memory
declare -A LOGOS
load_logos() {
    [ -f "$LOGOS_FILE" ] && while IFS='|' read -r channel logo; do
        [ -n "$channel" ] && [ -n "$logo" ] && LOGOS["$channel"]="$logo"
    done < "$LOGOS_FILE"
}

# Main processing
process_channels() {
    while IFS= read -r channel_url || [ -n "$channel_url" ]; do
        [ -z "$channel_url" ] && continue
        
        echo "Processing: $channel_url"
        channel_name=$(basename "$channel_url" | sed 's/@//')
        channel_id=$($YTDLP --get-id "$channel_url" 2>/dev/null)
        
        # Skip if invalid channel
        [ -z "$channel_id" ] && {
            echo "❌ Invalid channel: $channel_url"
            continue
        }
        
        # Get live stream
        live_url=$($YTDLP --get-url -f "best" "https://youtube.com/channel/$channel_id/live" 2>/dev/null)
        [ -z "$live_url" ] && continue
        
        # Get logo (custom or thumbnail)
        logo_url="${LOGOS[$channel_url]}"
        [ -z "$logo_url" ] && \
            logo_url=$($YTDLP --get-thumbnail "https://youtube.com/channel/$channel_id/live" 2>/dev/null)
        
        # Create playlist
        echo "#EXTM3U
#EXTINF:-1 tvg-id=\"$channel_id\" tvg-logo=\"$logo_url\",$channel_name
$live_url" > "${channel_name}.m3u"
        
        echo "✅ Created playlist for $channel_name"
    done < "$CHANNELS_FILE"
}

# GitHub sync
sync_github() {
    git config --global user.name "kgkaku"
    git config --global user.email "kgkaku77@gmail.com"
    [ ! -d .git ] && git init && git remote add origin "$GIT_REPO"
    git add .
    git commit -m "Update: $(date +'%Y-%m-%d %H:%M')" && \
    git push -u origin main
}

# Main execution
check_deps
load_logos
process_channels
sync_github
echo "Done! Check your $WORK_DIR for playlists."
