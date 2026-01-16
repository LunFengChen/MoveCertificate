#!/bin/bash
# MoveCertificate 构建脚本

set -e

VERSION="v1.0.0"
AUTHOR="x1a0f3n9"
CERT_DIR=""
SCAN_DIRS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version) VERSION="$2"; shift 2 ;;
        -a|--author) AUTHOR="$2"; shift 2 ;;
        -c|--certs) CERT_DIR="$2"; shift 2 ;;
        -s|--scan) SCAN_DIRS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./build.sh [OPTIONS]"
            echo "  -v, --version   版本号 (default: v1.0.0)"
            echo "  -a, --author    作者 (default: x1a0f3n9)"
            echo "  -c, --certs     证书目录，打包进模块（支持 .0/.pem/.crt/.cer）"
            echo "  -s, --scan      WebUI扫描目录，逗号分隔"
            exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "Building MoveCertificate $VERSION by $AUTHOR"

# 更新 module.prop
cat > module.prop << EOF
id=MoveCertificate
name=MoveCertificate
version=$VERSION
versionCode=$(echo $VERSION | tr -d 'v.')
author=$AUTHOR
description=Move certificates to system store. Magisk/KernelSU/APatch. Android 7-15.
EOF

# 更新 WebUI 版本
sed -i "s|v[0-9.]*\s*·\s*by\s*[^<]*|$VERSION · by $AUTHOR|" webroot/index.html

# 自定义扫描目录
if [ -n "$SCAN_DIRS" ]; then
    JS_ARRAY=$(echo "$SCAN_DIRS" | sed "s/,/','/g" | sed "s/^/'/" | sed "s/$/'/")
    sed -i "s|var SCAN_PATHS = \[.*\];|var SCAN_PATHS = [$JS_ARRAY];|" webroot/index.html
fi

# 复制证书目录
rm -rf certificates 2>/dev/null || true
if [ -n "$CERT_DIR" ] && [ -d "$CERT_DIR" ]; then
    echo "Packaging certificates from $CERT_DIR"
    mkdir -p certificates
    cp "$CERT_DIR"/* certificates/ 2>/dev/null || true
    echo "Found $(ls certificates/ 2>/dev/null | wc -l) certificates"
fi

# 打包
rm -f MoveCertificate-*.zip
OUTPUT="MoveCertificate-${AUTHOR}.zip"

zip -r "$OUTPUT" META-INF webroot module.prop post-fs-data.sh service.sh system.prop customize.sh \
    $([ -d certificates ] && echo "certificates") \
    $([ -d bin ] && echo "bin") \
    -x "*.git*" -x "*.idea*" -x "*.vscode*" -x "build.sh" -x "config.sh" -x "tools/*"

rm -rf certificates 2>/dev/null || true

echo "Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
