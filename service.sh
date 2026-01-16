#!/system/bin/sh
# Zygote monitor for Android 14+ certificate injection
# Based on: https://github.com/NVISOsecurity/AlwaysTrustUserCerts
# Original author: Jeroen Beckers (NVISO.eu)
# Modified: Fixed variable bug ($pid -> $zp), added version check
# Status: UNTESTED - needs verification on Android 16

MODDIR=${0%/*}

# 路径定义
APEX_CERT_DIR=/apex/com.android.conscrypt/cacerts
SYS_CERT_DIR=/system/etc/security/cacerts
LOG_PATH="$MODDIR/service.log"
LOG_TAG="x1a0f3n9"

log() {
    echo "[$LOG_TAG] $(date '+%m-%d %H:%M:%S') $*" >> "$LOG_PATH"
}

# 检查进程是否已挂载证书目录
has_mount() {
    local pid="$1"
    [ -f "/proc/$pid/mountinfo" ] && grep -q " $APEX_CERT_DIR " "/proc/$pid/mountinfo"
}

# 注入证书到指定进程的 mount namespace
inject_certs() {
    local pid="$1"
    /system/bin/nsenter --mount=/proc/$pid/ns/mnt -- \
        /bin/mount --bind "$SYS_CERT_DIR" "$APEX_CERT_DIR" 2>/dev/null
}

# 监控 zygote 进程，确保证书持续生效
monitor_zygote() {
    log "Starting zygote monitor"
    
    while true; do
        # 收集所有 zygote 进程 PID
        zygote_pids=""
        for name in zygote zygote64; do
            for p in $(pidof "$name" 2>/dev/null); do
                zygote_pids="$zygote_pids $p"
            done
        done
        
        for zp in $zygote_pids; do
            # 检查 bind mount 是否还在
            if ! has_mount "$zp"; then
                log "Mount lost on zygote ($zp), re-injecting..."
                
                # 获取 zygote 的子进程
                children=$(ps -o pid -P "$zp" 2>/dev/null | grep -v PID)
                
                # 兼容旧版 Android ps 命令
                if [ -z "$children" ]; then
                    children=$(ps | awk -v PPID="$zp" '$3==PPID { print $2 }')
                fi
                
                # 等待 zygote 稳定（至少 5 个子进程）
                child_count=$(echo "$children" | wc -w)
                if [ "$child_count" -lt 5 ]; then
                    sleep 1
                    continue
                fi
                
                # 注入 zygote
                inject_certs "$zp"
                log "Injected into zygote ($zp)"
                
                # 注入所有子进程
                for pid in $children; do
                    if ! has_mount "$pid"; then
                        inject_certs "$pid"
                    fi
                done
                log "Injected into $child_count children"
            fi
        done
        
        sleep 5
    done
}

main() {
    echo "" > "$LOG_PATH"
    log "MoveCertificate service.sh started"
    
    # 等待系统启动完成
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 1
    done
    log "Boot completed"
    
    # 获取 SDK 版本
    sdk_version=$(getprop ro.build.version.sdk)
    sdk_version_number=$((sdk_version + 0))
    log "SDK version: $sdk_version_number"
    
    # Android 14+ (SDK 34+) 需要监控 zygote
    if [ "$sdk_version_number" -ge 34 ] && [ -d "$APEX_CERT_DIR" ]; then
        log "Android 14+ detected, starting zygote monitor"
        monitor_zygote &
    else
        log "Android <= 13 or no conscrypt, no monitor needed"
    fi
    
    log "Service initialization done"
}

main
