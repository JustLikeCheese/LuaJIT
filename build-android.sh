#!/bin/bash

# Configuration
LUAJIT_ROOT="."
ARTIFACTS_DIR="$LUAJIT_ROOT/luajit-build"

# Define output directories
DIR_ROOT_BIN="$ARTIFACTS_DIR/luajit-bin"
DIR_ROOT_LIB="$ARTIFACTS_DIR/luajit"
DIR_ROOT_INC="$ARTIFACTS_DIR/luajit-include"

TARGET_ARCHS="armeabi-v7a x86 arm64-v8a x86_64"

# HOST_OS
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$HOST_OS" in
    linux*) HOST_TAG="linux-x86_64" ;;
    darwin*) HOST_TAG="darwin-x86_64" ;;
    *) echo "Unsupported host OS: $HOST_OS"; exit 1 ;;
esac

# Android NDK check
NDK="${ANDROID_NDK_HOME:-$ANDROID_NDK_LATEST_HOME}"
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
    echo "Error: ANDROID_NDK_HOME is not set."
    exit 1
fi

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
NDKB="$TOOLCHAIN/bin"

# Clean previous builds
echo "Cleaning up previous builds..."
rm -rf "$ARTIFACTS_DIR"
mkdir -p "$DIR_ROOT_INC"

# Function to build for a specific architecture
build_for_arch() {
  ARCH_NAME=$1
  echo "########## Building for ${ARCH_NAME} ##########"
  case "$ARCH_NAME" in
    "armeabi-v7a")
      NDKAPI=16
      TARGET_TRIPLE=armv7a-linux-androideabi
      NDKARCH="-march=armv7-a -mthumb -mfpu=neon -mfloat-abi=softfp -D__ARM_ARCH_7A__"
      HOST_CC="gcc -m32"
      ;;
    "x86")
      NDKAPI=16
      TARGET_TRIPLE=i686-linux-android
      NDKARCH="-march=i686 -msse3 -mfpmath=sse"
      HOST_CC="gcc -m32"
      ;;
    "arm64-v8a")
      NDKAPI=21
      TARGET_TRIPLE=aarch64-linux-android
      NDKARCH="-DLJ_ABI_SOFTFP=0 -DLJ_ARCH_HASFPU=1 -DLUAJIT_ENABLE_GC64"
      HOST_CC="gcc"
      ;;
    "x86_64")
      NDKAPI=21
      TARGET_TRIPLE=x86_64-linux-android
      NDKARCH="-march=x86-64 -msse4.2 -DLUAJIT_ENABLE_GC64"
      HOST_CC="gcc"
      ;;
    *)
      echo "Unsupported architecture: $ARCH_NAME"
      exit 1
      ;;
  esac

  CC="$NDKB/clang"
  COMPILER_TARGET="$TARGET_TRIPLE$NDKAPI"
  COMMON_FLAGS="-DLUAJIT_ENABLE_LUA52COMPAT"

  make -C "$LUAJIT_ROOT/src" clean
  make -C "$LUAJIT_ROOT/src" libluajit.a \
       HOST_CC="$HOST_CC" \
       CROSS="$NDKB/llvm-" \
       STATIC_CC="$CC --target=$COMPILER_TARGET -fPIC" \
       DYNAMIC_CC="$CC --target=$COMPILER_TARGET -fPIC" \
       TARGET_LD="$CC --target=$COMPILER_TARGET" \
       TARGET_AR="$NDKB/llvm-ar rcus" \
       TARGET_STRIP="$NDKB/llvm-strip" \
       TARGET_CFLAGS="-O2 -fomit-frame-pointer -ffast-math" \
       TARGET_FLAGS="$NDKARCH $COMMON_FLAGS"
  
  # Prepare sub-dirs
  mkdir -p "$DIR_ROOT_LIB/$ARCH_NAME"
  # 1. Copy Libs (Static lib for Android) -> luajit/
  mv "$LUAJIT_ROOT/src/libluajit.a" "$DIR_ROOT_LIB/$ARCH_NAME/libluajit.a"
  # 2. Copy Minilua (Host version) to root
  if [ -f "$LUAJIT_ROOT/src/host/minilua" ]; then
    cp "$LUAJIT_ROOT/src/host/minilua" "$ARTIFACTS_DIR/minilua-$ARCH_NAME"
  elif [ -f "$LUAJIT_ROOT/src/minilua" ]; then
    cp "$LUAJIT_ROOT/src/minilua" "$ARTIFACTS_DIR/minilua-$ARCH_NAME"
  else
    echo "Warning: minilua not found for $ARCH_NAME"
  fi

  # 3. Copy Buildvm (Host version used for this target)
  if [ -f "$LUAJIT_ROOT/src/host/buildvm" ]; then
    cp "$LUAJIT_ROOT/src/host/buildvm" "$ARTIFACTS_DIR/buildvm-$ARCH_NAME"
  else
    echo "Warning: buildvm not found for $ARCH_NAME"
  fi
}

for arch in $TARGET_ARCHS; do
  build_for_arch "$arch"
done

# Copy Headers
cp "$LUAJIT_ROOT/src/lua.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/lualib.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/lauxlib.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/luaconf.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/luajit.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/lua.hpp" "$DIR_ROOT_INC/"

echo "Build successful! Artifacts are in $ARTIFACTS_DIR"