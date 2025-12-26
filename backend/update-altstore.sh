#!/bin/bash
# update-altstore.sh - Updates the AltStore source with a new IPA
# Usage: ./update-altstore.sh <path-to-ipa> <version> [version-description]

set -e

IPA_PATH="$1"
VERSION="$2"
DESCRIPTION="${3:-Bug fixes and improvements}"

if [ -z "$IPA_PATH" ] || [ -z "$VERSION" ]; then
    echo "Usage: ./update-altstore.sh <path-to-ipa> <version> [version-description]"
    echo "Example: ./update-altstore.sh ~/Desktop/cTikTok.ipa 1.0.1 \"Added new features\""
    exit 1
fi

if [ ! -f "$IPA_PATH" ]; then
    echo "Error: IPA file not found at $IPA_PATH"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALTSTORE_DIR="$SCRIPT_DIR/altstore"

# Copy IPA
echo "Copying IPA to altstore folder..."
cp "$IPA_PATH" "$ALTSTORE_DIR/cTikTok.ipa"

# Get file size
SIZE=$(stat -f%z "$ALTSTORE_DIR/cTikTok.ipa" 2>/dev/null || stat -c%s "$ALTSTORE_DIR/cTikTok.ipa")

# Get today's date
DATE=$(date +%Y-%m-%d)

# Update source.json
echo "Updating source.json..."
cat > "$ALTSTORE_DIR/source.json" << EOF
{
  "name": "cTikTok",
  "identifier": "com.roshanc.ctiktok.source",
  "subtitle": "Share TikToks with your girlfriend",
  "sourceURL": "https://ctiktok.roshanc.com/altstore/source.json",
  "apps": [
    {
      "name": "cTikTok",
      "bundleIdentifier": "com.roshanc.ctiktok",
      "developerName": "Roshan",
      "subtitle": "Share TikToks without TikTok",
      "version": "$VERSION",
      "versionDate": "$DATE",
      "versionDescription": "$DESCRIPTION",
      "downloadURL": "https://ctiktok.roshanc.com/altstore/cTikTok.ipa",
      "localizedDescription": "A private app for sharing TikTok videos and slideshows. Features a TikTok-style vertical swipe interface, automatic video transcoding, and support for photo slideshows with audio.",
      "iconURL": "https://ctiktok.roshanc.com/altstore/icon.png",
      "tintColor": "E91E63",
      "size": $SIZE,
      "screenshotURLs": []
    }
  ],
  "news": []
}
EOF

echo "Done! AltStore source updated to version $VERSION"
echo ""
echo "Next steps:"
echo "1. Copy the app icon to: $ALTSTORE_DIR/icon.png"
echo "2. Deploy to your VPS: docker compose down && docker compose up -d --build"
echo "3. Add source in AltStore: https://ctiktok.roshanc.com/altstore/source.json"
