#!/usr/bin/env bash
# DocuCraft CRDT Build Script
# Builds Rust FFI, generates Dart bindings, builds Flutter app

set -e

echo "🔨 Building DocuCraft with Loro CRDT..."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}cargo not found. Install Rust first.${NC}"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}flutter not found. Install Flutter first.${NC}"
    exit 1
fi

if ! cargo install --list | grep -q flutter_rust_bridge_codegen; then
    echo -e "${YELLOW}Installing flutter_rust_bridge_codegen...${NC}"
    cargo install flutter_rust_bridge_codegen
fi

# Step 1: Build Rust FFI library
echo -e "${YELLOW}Step 1: Building Rust FFI library...${NC}"
cd rust/core/native
cargo build --release

# Step 2: Generate FFI bindings
echo -e "${YELLOW}Step 2: Generating Flutter FFI bindings...${NC}"
flutter_rust_bridge_codegen generate

# Step 3: Build for Android
if [[ "$1" == "--android" ]] || [[ "$1" == "--all" ]]; then
    echo -e "${YELLOW}Step 3a: Building for Android targets...${NC}"
    for target in aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android; do
        echo "  Building for $target..."
        cargo build --target "$target" --release
    done
fi

# Step 4: Build for iOS
if [[ "$1" == "--ios" ]] || [[ "$1" == "--all" ]]; then
    echo -e "${YELLOW}Step 3b: Building for iOS targets...${NC}"
    for target in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
        echo "  Building for $target..."
        cargo build --target "$target" --release
    done
fi

# Step 5: Build for Desktop
if [[ "$1" == "--desktop" ]] || [[ "$1" == "--all" ]]; then
    echo -e "${YELLOW}Step 3c: Building for desktop...${NC}"
    cargo build --release
fi

cd ../../..

# Step 6: Flutter build
echo -e "${YELLOW}Step 4: Building Flutter app...${NC}"
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

if [[ "$1" == "--android" ]] || [[ "$1" == "--all" ]]; then
    flutter build apk --release
    echo -e "${GREEN}✅ Android APK: build/app/outputs/flutter-apk/app-release.apk${NC}"
fi

if [[ "$1" == "--ios" ]] || [[ "$1" == "--all" ]]; then
    flutter build ios --release --no-codesign
    echo -e "${GREEN}✅ iOS build complete${NC}"
fi

if [[ "$1" == "--desktop" ]] || [[ "$1" == "--all" ]]; then
    flutter build linux --release
    flutter build windows --release
    flutter build macos --release
    echo -e "${GREEN}✅ Desktop builds complete${NC}"
fi

echo -e "${GREEN}✅ Build complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run flutter_rust_bridge_codegen generate in rust/core/native/"
echo "  2. Run flutter pub run build_runner build"
echo "  3. Run flutter run"