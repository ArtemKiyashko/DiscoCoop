#!/bin/bash
# xwd replacement for Steam Deck

OUTPUT="screenshot.png"
if [ $# -gt 0 ]; then
    OUTPUT="${*: -1}"
fi

# Ensure .png extension
case "$OUTPUT" in
    *.png) ;;
    *.xwd) OUTPUT="${OUTPUT%.xwd}.png" ;;
    *) OUTPUT="$OUTPUT.png" ;;
esac

# Try available screenshot tools
if command -v gnome-screenshot &> /dev/null; then
    gnome-screenshot -f "$OUTPUT"
elif command -v spectacle &> /dev/null; then
    spectacle -b -n -o "$OUTPUT"  
elif command -v scrot &> /dev/null; then
    scrot "$OUTPUT"
elif command -v flameshot &> /dev/null; then
    flameshot full -p "$(dirname "$OUTPUT")" -f "$(basename "$OUTPUT")"
else
    echo "Warning: No screenshot tools available" >&2
    # Create empty file as fallback
    touch "$OUTPUT"
fi