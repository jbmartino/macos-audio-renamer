#!/usr/bin/env bash
# Writes appcast.xml, the Sparkle feed, listing macOS-Audio-Renamer-<version>.dmg as the latest
# release, and signs the DMG's entry with the EdDSA key. The feed and DMG are attached to the
# GitHub release, and Info.plist's SUFeedURL points at releases/latest/download/appcast.xml, so
# every copy updates straight to the newest release. Release notes are this tag's commit subjects.
# Usage: scripts/make-appcast.sh <version>
#
#   SPARKLE_PRIVATE_KEY  EdDSA private key (GitHub secret); unset = the login keychain's
#                        "macos-audio-renamer" key
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/make-appcast.sh <version>}"
REPO="jbmartino/macos-audio-renamer"
DMG="macOS-Audio-Renamer-${VERSION}.dmg"
[[ -f "$DMG" ]] || { echo "error: $DMG not found; run scripts/build-dmg.sh $VERSION first" >&2; exit 1; }
SIGN_UPDATE=.build/artifacts/sparkle/Sparkle/bin/sign_update

sign() {
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    "$SIGN_UPDATE" --ed-key-file - "$@" <<<"$SPARKLE_PRIVATE_KEY"
  else
    "$SIGN_UPDATE" --account macos-audio-renamer "$@"
  fi
}

SIGNATURE="$(sign -p "$DMG")"
LENGTH="$(stat -f %z "$DMG")"
MIN_SYSTEM="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" Info.plist)"

# Notes: commit subjects since the previous tag, minus docs/chore noise.
TAG="v${VERSION}"
RANGE="HEAD"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && RANGE="$TAG"
PREV="$(git describe --tags --abbrev=0 "${RANGE}^" 2>/dev/null || true)"
NOTES="$(git log --no-merges --pretty='%s' ${PREV:+"$PREV.."}"$RANGE" \
  | grep -Ev '^(docs|chore|ci|test)(\(.*\))?:' \
  | sed -E 's/^[a-z]+(\([^)]*\))?: //; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s|.*|<li>&</li>|' || true)"
[[ -n "$NOTES" ]] || NOTES="<li>Bug fixes and improvements.</li>"
STYLE='<style>:root{color-scheme:light dark}body{font:13px/1.45 -apple-system,sans-serif}ul{margin:0;padding-left:18px}li{margin:3px 0}</style>'

cat >appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>macOS Audio Renamer</title>
    <link>https://github.com/${REPO}/releases/latest/download/appcast.xml</link>
    <item>
      <title>macOS Audio Renamer ${VERSION}</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_SYSTEM}</sparkle:minimumSystemVersion>
      <description><![CDATA[${STYLE}<ul>
${NOTES}
</ul>]]></description>
      <sparkle:fullReleaseNotesLink>https://github.com/${REPO}/releases/tag/${TAG}</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/${REPO}/releases/download/${TAG}/${DMG}" length="${LENGTH}" type="application/x-apple-diskimage" sparkle:edSignature="${SIGNATURE}"/>
    </item>
  </channel>
</rss>
XML
echo "Created appcast.xml for $DMG"
