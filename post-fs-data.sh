#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in post-fs-data mode
# Android 14 cannot be earlier than Zygote
sdk_version=$(getprop ro.build.version.sdk)
# debug
#sdk_version=34
sdk_version_number=$(expr "$sdk_version" + 0)

# add logcat
LOG_PATH="$MODDIR/install.log"
LOG_TAG="x1a0f3n9"

# Keep only one up-to-date log
echo "[$LOG_TAG] Keep only one up-to-date log" >$LOG_PATH

print_log() {
    echo "[$LOG_TAG] $@" >>$LOG_PATH
}

# cert-hash 工具路径
get_cert_hash_bin() {
    local arch=$(getprop ro.product.cpu.abi)
    case "$arch" in
        arm64*) echo "$MODDIR/bin/cert-hash-arm64" ;;
        armeabi*|arm*) echo "$MODDIR/bin/cert-hash-arm" ;;
        *) echo "$MODDIR/bin/cert-hash-arm64" ;;
    esac
}

# 转换证书为 hash.0 格式
convert_cert() {
    local src="$1"
    local dest_dir="$2"
    local filename=$(basename "$src")
    local ext="${filename##*.}"
    
    # 如果已经是 .0 格式，直接复制
    if [ "$ext" = "0" ]; then
        cp -f "$src" "$dest_dir/"
        print_log "Copy: $filename"
        return 0
    fi
    
    # 检查是否是证书文件
    case "$ext" in
        pem|crt|cer|PEM|CRT|CER) ;;
        *) return 1 ;;
    esac
    
    # 使用 cert-hash 计算 hash
    local cert_hash_bin=$(get_cert_hash_bin)
    if [ -x "$cert_hash_bin" ]; then
        local hash=$("$cert_hash_bin" "$src" 2>/dev/null)
        if [ -n "$hash" ] && [ ${#hash} -eq 8 ]; then
            cp -f "$src" "$dest_dir/${hash}.0"
            print_log "Convert: $filename -> ${hash}.0"
            return 0
        fi
    fi
    
    # 如果 cert-hash 失败，直接复制原文件
    cp -f "$src" "$dest_dir/"
    print_log "Copy (no convert): $filename"
    return 0
}

move_custom_cert() {
    local src_dir="/data/local/tmp/cert"
    if [ ! -d "$src_dir" ] || [ -z "$(ls -A "$src_dir" 2>/dev/null)" ]; then
        print_log "The directory '$src_dir' is empty."
        return
    fi
    
    # 设置 cert-hash 可执行权限
    local cert_hash_bin=$(get_cert_hash_bin)
    [ -f "$cert_hash_bin" ] && chmod +x "$cert_hash_bin"
    
    for cert in "$src_dir"/*; do
        [ -f "$cert" ] || continue
        convert_cert "$cert" "$MODDIR/certificates"
        convert_cert "$cert" "/data/misc/user/0/cacerts-added"
    done
    print_log "Install $src_dir status:$?"
    
    # 清空待安装目录
    rm -rf "$src_dir"/*
    print_log "Cleared $src_dir"
}

fix_user_permissions() {
    # "Fix permissions of the system certificate directory"
    chown -R root:root /data/misc/user/0/cacerts-added/
    chmod -R 666 /data/misc/user/0/cacerts-added/
    chown system:system /data/misc/user/0/cacerts-added
    chmod 755 /data/misc/user/0/cacerts-added
    print_log "fix user certificate permissions status:$?"
}

fix_system_permissions() {
    chown root:root /system/etc/security/cacerts
    chown -R root:root /system/etc/security/cacerts/
    chmod -R 644 /system/etc/security/cacerts/
    chmod 755 /system/etc/security/cacerts
    chcon u:object_r:system_file:s0 /system/etc/security/cacerts/*
    print_log "fix permissions /system/etc/security/cacerts status:$?"
}

fix_system_permissions14() {
    chown -R system:system "$1"
    chown root:shell "$1"
    chmod -R 644 "$1"
    chmod 755 "$1"
    print_log "fix permissions: $?"
}

set_selinux_context(){
    [ "$(getenforce)" = "Enforcing" ] || return 0
    default_selinux_context=u:object_r:system_file:s0
    selinux_context=$(ls -Zd $1 | awk '{print $1}')

    if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
        chcon -R $selinux_context $2
    else
        chcon -R $default_selinux_context $2
    fi
}

compatible(){
    # compatible adguard or other
    # Hash 47ec1af8 is for "AdGuard Intermediate CA" intermediate.
    print_log "Compatible adguard"
    cert_dir="$MODDIR/certificates"
    print_log "Running compatibility cleanup for potentially conflicting certificates."

    # Remove by filename pattern (hash: 47ec1af8.*)
    rm -f "$cert_dir"/47ec1af8.*
    print_log "Removed files matching '47ec1af8.*'."

    # Remove by content string "Guard Personal Intermediate"
    for cert_file in "$cert_dir"/*; do
        # Ensure it is a file before trying to read it
        if [ -f "$cert_file" ]; then
            # Use grep -q for a silent, efficient check
            if grep -q "Guard Personal Intermediate" "$cert_file"; then
                print_log "Removing file containing 'Guard Personal Intermediate': $(basename "$cert_file")"
                rm -f "$cert_file"
            fi
        fi
    done
    print_log "Compatibility cleanup status:$?"
}

# Android version <= 13 execute
if [ "$sdk_version_number" -le 33 ]; then
    print_log "start move cert !"
    print_log "current sdk version is $sdk_version_number"
    
    # 确保目录存在
    mkdir -p $MODDIR/certificates
    mkdir -p /data/misc/user/0/cacerts-added
    
    print_log "Backup /system/etc/security/cacerts"
    cp /system/etc/security/cacerts/* $MODDIR/certificates/ 2>/dev/null || true
    print_log "Backup /data/misc/user/0/cacerts-added"
    cp /data/misc/user/0/cacerts-added/* $MODDIR/certificates/ 2>/dev/null || true
    
    # Android 13 or lower versions perform
    move_custom_cert
    fix_user_permissions
    compatible

    selinux_context=$(ls -Zd /system/etc/security/cacerts | awk '{print $1}')
    mount -t tmpfs tmpfs /system/etc/security/cacerts
    print_log "mount /system/etc/security/cacerts status:$?"
    
    cp -f $MODDIR/certificates/* /system/etc/security/cacerts
    print_log "Install /system/etc/security/cacerts status:$?"
    fix_system_permissions
    print_log "certificates installed"
    
    if [ "$(getenforce)" = "Enforcing" ]; then
        default_selinux_context=u:object_r:system_file:s0
        if [ -n "$selinux_context" ] && [ "$selinux_context" != "?" ]; then
            chcon -R $selinux_context /system/etc/security/cacerts
        else
            chcon -R $default_selinux_context /system/etc/security/cacerts
        fi
    fi
else

    print_log "start move cert !"
    print_log "current sdk version is $sdk_version_number"
    
    # 确保目录存在
    mkdir -p $MODDIR/certificates
    mkdir -p /data/misc/user/0/cacerts-added
    
    mount -t tmpfs tmpfs $MODDIR/certificates
    print_log "mount $MODDIR/certificates status:$?"
    print_log "Backup /apex/com.android.conscrypt/cacerts"
    cp /apex/com.android.conscrypt/cacerts/* $MODDIR/certificates/ 2>/dev/null || true
    print_log "Backup /data/misc/user/0/cacerts-added"
    cp /data/misc/user/0/cacerts-added/* $MODDIR/certificates/ 2>/dev/null || true
    
    move_custom_cert
    fix_user_permissions
    fix_system_permissions14 $MODDIR/certificates
    compatible

    print_log "find system conscrypt directory"
    apex_dir=$(find /apex -type d -name "com.android.conscrypt@*")
    print_log "find conscrypt directory: $apex_dir"

    set_selinux_context /apex/com.android.conscrypt/cacerts $MODDIR/certificates
    # These two directories are mapped to the same block
    mount -o bind $MODDIR/certificates /apex/com.android.conscrypt/cacerts
    print_log "mount bind $MODDIR/certificates /apex/com.android.conscrypt/cacerts status:$?"
    mount -o bind $MODDIR/certificates $apex_dir/cacerts
    for pid in 1 $(pgrep zygote) $(pgrep zygote64); do
            nsenter --mount=/proc/${pid}/ns/mnt -- mount --bind $MODDIR/certificates /apex/com.android.conscrypt/cacerts
            nsenter --mount=/proc/${pid}/ns/mnt -- mount --bind $MODDIR/certificates $apex_dir/cacerts
    done
    print_log "mount bind $MODDIR/certificates $apex_dir/cacerts status:$?"
    print_log "certificates installed"
fi
