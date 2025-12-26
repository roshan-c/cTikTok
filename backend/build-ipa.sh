#!/bin/bash
# build-ipa.sh - Builds the iOS app and creates an unsigned IPA for AltStore
# Usage: ./build-ipa.sh [version] [version-description]

set -e

VERSION="${1:-1.0.0}"
DESCRIPTION="${2:-Bug fixes and improvements}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../cTikTok"
BACKEND_DIR="$SCRIPT_DIR"
ALTSTORE_DIR="$BACKEND_DIR/altstore"
BUILD_DIR="$SCRIPT_DIR/build-tmp"

# Clean up
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/Payload"

echo "=== Building cTikTok IPA ==="
echo "Version: $VERSION"
echo ""

# Build the app
echo "1. Building app with xcodebuild..."
cd "$PROJECT_DIR"

xcodebuild -project cTikTok.xcodeproj \
    -scheme cTikTok \
    -configuration Release \
    -sdk iphoneos \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | grep -E "(Build |error:|warning:|\*\*)" || true

# Find the .app
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/cTikTok.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed - cTikTok.app not found"
    echo "Looking in: $APP_PATH"
    exit 1
fi

echo "2. Found app at: $APP_PATH"

# Create IPA
echo "3. Creating IPA..."
cp -r "$APP_PATH" "$BUILD_DIR/Payload/"
cd "$BUILD_DIR"
zip -r cTikTok.ipa Payload -x "*.DS_Store"

# Move to altstore folder
echo "4. Moving IPA to altstore folder..."
mv "$BUILD_DIR/cTikTok.ipa" "$ALTSTORE_DIR/cTikTok.ipa"

# Get file size
SIZE=$(stat -f%z "$ALTSTORE_DIR/cTikTok.ipa" 2>/dev/null || stat -c%s "$ALTSTORE_DIR/cTikTok.ipa")
DATE=$(date +%Y-%m-%d)

# Update source.json
echo "5. Updating source.json..."
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
rm -rf "$BUILD_DIR"

echo ""
echo "=== Done! ==="
echo "IPA created: $ALTSTORE_DIR/cTikTok.ipa"
echo "Size: $(echo "$SIZE" | awk '{printf "%.2f MB", $1/1024/1024}')"
echo ""
echo "Next steps:"
echo "1. Deploy to VPS: cd ~/ctiktok/backend && docker compose down && docker compose up -d --build"
echo "2. Add source in AltStore: https://ctiktok.roshanc.com/altstore/source.json"
