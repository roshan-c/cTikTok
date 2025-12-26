#!/bin/bash
# package-ipa.sh - Packages an existing .app into an IPA for AltStore
# Usage: ./package-ipa.sh <path-to-.app> [version] [description]

set -e

APP_PATH="$1"
VERSION="${2:-1.0.0}"
DESCRIPTION="${3:-Bug fixes and improvements}"

if [ -z "$APP_PATH" ]; then
    echo "Usage: ./package-ipa.sh <path-to-.app> [version] [description]"
    echo ""
    echo "Example:"
    echo "  ./package-ipa.sh ~/Library/Developer/Xcode/DerivedData/cTikTok-xxx/Build/Products/Release-iphoneos/cTikTok.app 1.0.0"
    echo ""
    echo "Your available .app builds:"
    find ~/Library/Developer/Xcode/DerivedData -name "cTikTok.app" -type d 2>/dev/null | grep -v "Index.noindex" || echo "  None found"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: .app not found at $APP_PATH"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALTSTORE_DIR="$SCRIPT_DIR/altstore"
TEMP_DIR=$(mktemp -d)

echo "=== Packaging IPA ==="
echo "App: $APP_PATH"
echo "Version: $VERSION"
echo ""

# Create Payload folder and copy .app
mkdir -p "$TEMP_DIR/Payload"
cp -r "$APP_PATH" "$TEMP_DIR/Payload/"

# Create IPA
cd "$TEMP_DIR"
zip -r cTikTok.ipa Payload -x "*.DS_Store" > /dev/null

# Move to altstore folder
mkdir -p "$ALTSTORE_DIR"
mv "$TEMP_DIR/cTikTok.ipa" "$ALTSTORE_DIR/cTikTok.ipa"

# Get file size
SIZE=$(stat -f%z "$ALTSTORE_DIR/cTikTok.ipa" 2>/dev/null || stat -c%s "$ALTSTORE_DIR/cTikTok.ipa")
DATE=$(date +%Y-%m-%d)

# Update source.json
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

# Clean up
rm -rf "$TEMP_DIR"

echo "Done!"
echo "IPA: $ALTSTORE_DIR/cTikTok.ipa"
echo "Size: $(echo "$SIZE" | awk '{printf "%.2f MB", $1/1024/1024}')"
echo ""
echo "Next: Deploy to VPS and add source in AltStore: https://ctiktok.roshanc.com/altstore/source.json"
