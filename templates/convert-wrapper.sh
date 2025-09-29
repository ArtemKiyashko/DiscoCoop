#!/bin/bash
# ImageMagick convert replacement

if command -v ffmpeg &> /dev/null && [ $# -ge 2 ]; then
    # Use ffmpeg for actual conversions
    INPUT=""
    OUTPUT=""
    for arg in "$@"; do
        if [[ -f "$arg" ]]; then
            INPUT="$arg"
        elif [[ "$arg" == *"."* && "$arg" != "-"* ]]; then
            OUTPUT="$arg" 
        fi
    done
    
    if [[ -n "$INPUT" && -n "$OUTPUT" ]]; then
        ffmpeg -y -i "$INPUT" "$OUTPUT" 2>/dev/null
    else
        echo "Warning: Basic convert support" >&2
    fi
else
    echo "Warning: convert basic support" >&2
    echo "Note: Install ffmpeg for full support" >&2
fi