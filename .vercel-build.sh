#!/bin/bash
set -e

echo "🚀 Starting optimized Flutter Web build on Vercel..."

# -------------------------------
# Setup caching paths
# -------------------------------
FLUTTER_ROOT="/vercel/cache/flutter"
PUB_CACHE_DIR="/vercel/cache/pub-cache"

echo "📦 Using cache directories:"
echo "   Flutter SDK: $FLUTTER_ROOT"
echo "   Pub cache:   $PUB_CACHE_DIR"

# -------------------------------
# Setup Flutter SDK
# -------------------------------
if [ ! -d "$FLUTTER_ROOT" ]; then
  echo "🔹 Flutter not found in cache. Cloning..."
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"
else
  echo "✅ Using cached Flutter from $FLUTTER_ROOT"
  cd "$FLUTTER_ROOT"
  git fetch
  git pull
  cd -
fi

# Add Flutter to PATH
export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_CACHE="$PUB_CACHE_DIR"

flutter --version

# -------------------------------
# Flutter configuration & dependencies
# -------------------------------
flutter config --enable-web
flutter pub get

# -------------------------------
# Build web app (release mode)
# -------------------------------
flutter build web --release --no-tree-shake-icons

# -------------------------------
# Cache optimization summary
# -------------------------------
echo "✅ Build completed successfully."
echo "🕒 Next builds will use cached Flutter SDK and pub packages for faster deployment."
