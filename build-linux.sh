#!/bin/bash

# Configuration
LUAJIT_ROOT="."
ARTIFACTS_DIR="$LUAJIT_ROOT/luajit-build"

DIR_ROOT_BIN="$ARTIFACTS_DIR/luajit-bin"
DIR_ROOT_LIB="$ARTIFACTS_DIR/luajit"
DIR_ROOT_INC="$ARTIFACTS_DIR/luajit-include"

# Cleaning
rm -rf "$ARTIFACTS_DIR"
mkdir -p "$DIR_ROOT_INC"

# Function to build
build_linux_arch() {
    ARCH_NAME=$1
    echo "########## Building for Linux ${ARCH_NAME} ##########"
    
    make -C "$LUAJIT_ROOT/src" clean
    
    if [ "$ARCH_NAME" == "x86" ]; then
        # 32-bit build
        make -C "$LUAJIT_ROOT/src" CC="gcc -m32"
    else
        # 64-bit build (default)
        make -C "$LUAJIT_ROOT/src"
    fi

    mkdir -p "$DIR_ROOT_BIN/$ARCH_NAME"
    mkdir -p "$DIR_ROOT_LIB/$ARCH_NAME"

    # 1. Copy Binaries
    cp "$LUAJIT_ROOT/src/luajit" "$DIR_ROOT_BIN/$ARCH_NAME/"
    
    # 2. Copy Libs
    cp "$LUAJIT_ROOT/src/libluajit.a" "$DIR_ROOT_LIB/$ARCH_NAME/"
    # Also copy .so if generated, usually libluajit.so
    if [ -f "$LUAJIT_ROOT/src/libluajit.so" ]; then
        cp "$LUAJIT_ROOT/src/libluajit.so" "$DIR_ROOT_LIB/$ARCH_NAME/"
    fi

    # 3. Copy Minilua to root with arch name
    if [ -f "$LUAJIT_ROOT/src/host/minilua" ]; then
        cp "$LUAJIT_ROOT/src/host/minilua" "$ARTIFACTS_DIR/minilua-$ARCH_NAME"
    elif [ -f "$LUAJIT_ROOT/src/minilua" ]; then
        cp "$LUAJIT_ROOT/src/minilua" "$ARTIFACTS_DIR/minilua-$ARCH_NAME"
    else
        echo "Warning: minilua not found for $ARCH_NAME"
    fi

    # 3.5 Copy Buildvm
    if [ -f "$LUAJIT_ROOT/src/host/buildvm" ]; then
        cp "$LUAJIT_ROOT/src/host/buildvm" "$ARTIFACTS_DIR/buildvm-$ARCH_NAME"
    else
        echo "Warning: buildvm not found for $ARCH_NAME"
    fi
}

# Build x64
build_linux_arch "x64"

# Build x86 (requires multilib)
build_linux_arch "x86"

# Copy Headers
cp "$LUAJIT_ROOT/src/lua.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/lualib.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/lauxlib.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/luaconf.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/luajit.h" "$DIR_ROOT_INC/"
cp "$LUAJIT_ROOT/src/lua.hpp" "$DIR_ROOT_INC/"

echo "Linux Build Successful"