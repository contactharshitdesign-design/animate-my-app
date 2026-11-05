#!/bin/zsh
# Scaffold a native SwiftUI + three.js animated app from the template.
#   new_app.sh <AppName> <parent-dir> [bundle.id]
# AppName must be a valid Swift identifier (letters/digits, starts with a letter), e.g. SleepyBear, Onboarding.
set -e
NAME=$1; PARENT=$2; BUNDLE=${3:-com.example.${(L)NAME}}
[[ -z $NAME || -z $PARENT ]] && { echo "usage: new_app.sh <AppName> <parent-dir> [bundle.id]"; exit 1; }
[[ $NAME =~ '^[A-Za-z][A-Za-z0-9]*$' ]] || { echo "AppName must be letters/digits and start with a letter"; exit 1; }
TEMPLATE="${0:A:h}/../assets/template"
DEST="${PARENT:A}/$NAME"
[[ -e $DEST ]] && { echo "$DEST already exists"; exit 1; }

mkdir -p "$DEST"
cp -R "$TEMPLATE/" "$DEST/"
# rename __APP__ paths (deepest first), then fill placeholders in text files
for p in ${(On)$(cd "$DEST" && find . -name '*__APP__*')}; do
  mv "$DEST/$p" "$DEST/${p:h}/${${p:t}//__APP__/$NAME}"
done
grep -rlI -e '__APP__' -e '__BUNDLE__' "$DEST" --exclude=three.min.js | while read f; do
  sed -i '' -e "s/__APP__/$NAME/g" -e "s/__BUNDLE__/$BUNDLE/g" "$f"
done
echo "created $DEST"
echo "  project : $DEST/$NAME.xcodeproj   scheme: $NAME   bundle: $BUNDLE"
echo "  next    : build with the iOS Simulator build tool, then: xcrun simctl launch booted $BUNDLE"
