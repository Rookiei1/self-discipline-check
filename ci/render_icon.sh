#!/bin/bash
# Render the Watch app icon from ci/AppIcon.svg: 1024x1024, no alpha channel.
set -euo pipefail
ICON="RebootWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
mkdir -p "$(dirname "$ICON")"
rsvg-convert -w 1024 -h 1024 ci/AppIcon.svg -o /tmp/RebootWatch-AppIcon-render.png
sips -s format jpeg /tmp/RebootWatch-AppIcon-render.png --out /tmp/RebootWatch-AppIcon-flat.jpg >/dev/null
sips -s format png /tmp/RebootWatch-AppIcon-flat.jpg --out "$ICON" >/dev/null
WIDTH="$(sips -g pixelWidth "$ICON" | awk '/pixelWidth/ {print $2}')"
HEIGHT="$(sips -g pixelHeight "$ICON" | awk '/pixelHeight/ {print $2}')"
ALPHA="$(sips -g hasAlpha "$ICON" | awk '/hasAlpha/ {print $2}')"
echo "AppIcon: ${WIDTH}x${HEIGHT}, alpha=${ALPHA}"
test "$WIDTH" = "1024"
test "$HEIGHT" = "1024"
test "$ALPHA" = "no"
