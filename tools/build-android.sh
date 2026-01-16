#!/bin/bash
# 编译 cert-hash 为 Android 静态二进制
# 需要 Android NDK

set -e

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "请设置 ANDROID_NDK_HOME 环境变量"
    echo "例如: export ANDROID_NDK_HOME=~/Android/Sdk/ndk/25.2.9519653"
    exit 1
fi

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"

mkdir -p ../bin

# ARM64 (大多数现代设备)
echo "Building arm64..."
$TOOLCHAIN/bin/aarch64-linux-android21-clang -static -O2 -o ../bin/cert-hash-arm64 cert-hash.c

# ARM32 (老设备)
echo "Building arm..."
$TOOLCHAIN/bin/armv7a-linux-androideabi21-clang -static -O2 -o ../bin/cert-hash-arm cert-hash.c

# x86_64 (模拟器)
echo "Building x86_64..."
$TOOLCHAIN/bin/x86_64-linux-android21-clang -static -O2 -o ../bin/cert-hash-x86_64 cert-hash.c

echo "Done! Binaries in ../bin/"
ls -la ../bin/cert-hash-*
