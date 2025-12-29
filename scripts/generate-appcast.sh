#!/bin/bash
set -e

if [ $# -lt 4 ]; then
  echo "Usage: $0 <archive.zip> <version> <build_number> <download_url>"
  exit 1
fi

ARCHIVE="$1"
VERSION="$2"
BUILD_NUMBER="$3"
DOWNLOAD_URL="$4"
MIN_SYSTEM_VERSION="${5:-12.0}"

if [ ! -f "$ARCHIVE" ]; then
  echo "Error: Archive not found: $ARCHIVE"
  exit 1
fi

if [ -z "$SPARKLE_EDDSA_PRIVATE_KEY" ]; then
  echo "Error: SPARKLE_EDDSA_PRIVATE_KEY environment variable not set"
  exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SIGN_UPDATE=""
for path in \
  "$PROJECT_ROOT/.build/artifacts/sparkle/Sparkle/bin/sign_update" \
  "/tmp/Sparkle/bin/sign_update" \
  "$(which sign_update 2>/dev/null)"; do
  if [ -x "$path" ]; then
    SIGN_UPDATE="$path"
    break
  fi
done

if [ -z "$SIGN_UPDATE" ]; then
  echo "Error: sign_update tool not found"
  echo "Download Sparkle from https://github.com/sparkle-project/Sparkle/releases"
  exit 1
fi

FILE_SIZE=$(stat -f%z "$ARCHIVE" 2>/dev/null || stat -c%s "$ARCHIVE")
SIGNATURE=$("$SIGN_UPDATE" "$ARCHIVE" --ed-key-file <(echo "$SPARKLE_EDDSA_PRIVATE_KEY") 2>/dev/null)
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'edSignature="[^"]*"' | sed 's/edSignature="//;s/"//')
PUB_DATE=$(date -R 2>/dev/null || date "+%a, %d %b %Y %H:%M:%S %z")

OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT}"

cat > "${OUTPUT_DIR}/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Blurry Updates</title>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
      <enclosure url="${DOWNLOAD_URL}" sparkle:edSignature="${ED_SIGNATURE}"
                 length="${FILE_SIZE}" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
EOF

echo "Generated appcast.xml at ${OUTPUT_DIR}/appcast.xml"
echo "Version: ${VERSION} (build ${BUILD_NUMBER})"
echo "Download URL: ${DOWNLOAD_URL}"
echo "File size: ${FILE_SIZE}"
