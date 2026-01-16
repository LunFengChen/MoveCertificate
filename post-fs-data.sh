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
echo "[$LOG_TAG] $(date '+%Y-%m-%d %H:%M:%S') Start" >$LOG_PATH

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

# 转换证书为 hash.0 格式并复制到目标目录，返回 hash
convert_and_copy_cert() {
    local src="$1"
    local dest_dir="$2"
    local filename=$(basename "$src")
    local ext="${filename##*.}"
    local hash=""
    
    local cert_hash_bin=$(get_cert_hash_bin)
    
    # 如果已经是 .0 格式
    if [ "$ext" = "0" ]; then
        hash="${filename%.0}"
        cp -f "$src" "$dest_dir/"
        print_log "Copy: $filename -> $dest_dir/"
        echo "$hash"
        return 0
    fi
    
    # 检查是否是证书文件
    case "$ext" in
        pem|crt|cer|PEM|CRT|CER) ;;
        *) 
            print_log "Skip: $filename (unsupported format)"
            return 1 
        ;;
    esac
    
    # 使用 cert-hash 计算 hash
    if [ -x "$cert_hash_bin" ]; then
        hash=$("$cert_hash_bin" "$src" 2>/dev/null)
        if [ -n "$hash" ] && [ ${#hash} -eq 8 ]; then
            cp -f "$src" "$dest_dir/${hash}.0"
            print_log "Convert: $filename -> ${hash}.0"
            echo "$hash"
            return 0
        else
            print_log "Failed: $filename (cert-hash returned invalid hash)"
        fi
    else
        print_log "Failed: $filename (cert-hash not executable)"
    fi
    
    return 1
}

# 安装待安装区的证书（包括 /data/local/tmp/cert 和用户证书目录）
install_pending_certs() {
    local installed_list="$MODDIR/installed.list"
    local total_installed=0
    local total_failed=0
    
    # 设置 cert-hash 可执行权限
    local cert_hash_bin=$(get_cert_hash_bin)
    if [ -f "$cert_hash_bin" ]; then
        chmod +x "$cert_hash_bin"
        print_log "cert-hash: $cert_hash_bin"
    else
        print_log "Warning: cert-hash not found at $cert_hash_bin"
    fi
    
    # 处理单个目录的证书
    install_from_dir() {
        local src_dir="$1"
        [ -d "$src_dir" ] || return
        
        local file_count=$(ls -1 "$src_dir" 2>/dev/null | wc -l)
        if [ "$file_count" -eq 0 ]; then
            print_log "Skip: $src_dir (empty)"
            return
        fi
        
        print_log "Processing: $src_dir ($file_count files)"
        
        for cert in "$src_dir"/*; do
            [ -f "$cert" ] || continue
            
            # 转换并复制证书
            local hash=$(convert_and_copy_cert "$cert" "$MODDIR/certificates")
            
            if [ -n "$hash" ] && [ ${#hash} -eq 8 ]; then
                # 记录到 installed.list
                if ! grep -q "^${hash}:" "$installed_list" 2>/dev/null; then
                    echo "${hash}:user" >> "$installed_list"
                    print_log "Recorded: ${hash}:user"
                    total_installed=$((total_installed + 1))
                else
                    print_log "Skip: ${hash} (already in list)"
                fi
            else
                total_failed=$((total_failed + 1))
            fi
        done
        
        # 清空目录
        rm -rf "$src_dir"/*
        print_log "Cleared: $src_dir"
    }
    
    # 处理两个待安装目录
    install_from_dir "/data/local/tmp/cert"
    install_from_dir "/data/misc/user/0/cacerts-added"
    
    # 删除空的待安装目录
    rmdir "/data/local/tmp/cert" 2>/dev/null || true
    
    print_log "Pending certs: installed=$total_installed, failed=$total_failed"
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
    
    print_log "Backup /system/etc/security/cacerts"
    cp /system/etc/security/cacerts/* $MODDIR/certificates/ 2>/dev/null || true
    
    # 安装待安装区的证书
    install_pending_certs
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
    
    mount -t tmpfs tmpfs $MODDIR/certificates
    print_log "mount $MODDIR/certificates status:$?"
    print_log "Backup /apex/com.android.conscrypt/cacerts"
    cp /apex/com.android.conscrypt/cacerts/* $MODDIR/certificates/ 2>/dev/null || true
    
    # 安装待安装区的证书
    install_pending_certs
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
    print_log "Total certs in system: $(ls -1 $MODDIR/certificates/*.0 2>/dev/null | wc -l)"
fi

print_log "$(date '+%Y-%m-%d %H:%M:%S') Done"
