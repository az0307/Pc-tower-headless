#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  AUTOBOROS PERFORMANCE UPGRADE v3.0
#  Aggressive tuning for Vista-era headless towers
# ═══════════════════════════════════════════════════════════════

USER_HOME="$HOME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "    +------------------------------------------+"
echo "    |      AUTOBOROS PERFORMANCE UPGRADE       |"
echo "    |      v3.0 — Squeeze every drop         |"
echo "    +------------------------------------------+"
echo ""

# -- Phase 0: Safety -------------------------------------------
echo "=== [0/9] Safety Check ==="
[[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null && { echo "FATAL: sudo required"; exit 1; }

RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024}')
echo "  RAM: ${RAM_MB}MB"

# Determine profile
if [[ ${RAM_MB%.*} -le 2048 ]]; then
    PROFILE="ULTRA"
    GRUB="quiet loglevel=3 mitigations=off zswap.enabled=1 zswap.max_pool_percent=25 zswap.compressor=lz4 zswap.zpool=zsmalloc vm.swappiness=100 vm.vfs_cache_pressure=200 vm.dirty_ratio=10 vm.dirty_background_ratio=5 vm.dirty_expire_centisecs=500 vm.dirty_writeback_centisecs=100 vm.page-cluster=3 vm.zone_reclaim_mode=1 slab_nomerge init_on_alloc=0 init_on_free=0 page_alloc.shuffle=0 nohz_full=1 rcu_nocbs=1"
    echo "  Profile: ULTRA (<=2GB) — mitigations off, aggressive reclaim"
elif [[ ${RAM_MB%.*} -le 4096 ]]; then
    PROFILE="LOW"
    GRUB="quiet loglevel=3 zswap.enabled=1 zswap.max_pool_percent=20 zswap.compressor=lz4 vm.swappiness=80 vm.vfs_cache_pressure=150 vm.dirty_ratio=15 vm.dirty_background_ratio=5"
    echo "  Profile: LOW (2-4GB) — balanced tuning"
else
    PROFILE="STANDARD"
    GRUB="quiet loglevel=3 zswap.enabled=1 zswap.max_pool_percent=15 zswap.compressor=lz4 vm.swappiness=60 vm.vfs_cache_pressure=100"
    echo "  Profile: STANDARD (>=4GB) — mild tuning"
fi

# -- Phase 1: GRUB ---------------------------------------------
echo ""
echo "=== [1/9] GRUB Kernel Parameters ==="
sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="$GRUB"/" /etc/default/grub
sudo update-grub
echo "  Updated. Reboot required."

# -- Phase 2: sysctl -------------------------------------------
echo ""
echo "=== [2/9] sysctl Tuning ==="
sudo tee /etc/sysctl.d/99-autoboros-performance.conf > /dev/null <<'SYSCTLEOF'
vm.swappiness=100
vm.vfs_cache_pressure=200
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
vm.page-cluster=3
vm.zone_reclaim_mode=1
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.core.netdev_max_backlog=30000
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1
fs.file-max=2097152
fs.nr_open=2097152
kernel.sched_latency_ns=1000000
kernel.sched_min_granularity_ns=100000
kernel.sched_wakeup_granularity_ns=50000
kernel.numa_balancing=0
kernel.kptr_restrict=1
kernel.dmesg_restrict=1
kernel.yama.ptrace_scope=1
SYSCTLEOF
sudo sysctl --system

# -- Phase 3: Filesystem ---------------------------------------
echo ""
echo "=== [3/9] Filesystem Tuning ==="
if findmnt -n -o FSTYPE / | grep -q ext4; then
    if ! findmnt -n -o OPTIONS / | grep -q noatime; then
        sudo sed -i 's|ext4  defaults|ext4  defaults,noatime,nodiratime|' /etc/fstab
        echo "  Added noatime,nodiratime"
    fi
fi
if systemctl list-unit-files | grep -q fstrim.timer; then
    sudo systemctl enable fstrim.timer
    echo "  fstrim.timer enabled"
fi

# -- Phase 4: CPU Governor -------------------------------------
echo ""
echo "=== [4/9] CPU Governor ==="
if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
    sudo apt-get install -y --no-install-recommends cpufrequtils
    if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
        GOV="ondemand"
    else
        GOV="performance"
    fi
    sudo tee /etc/default/cpufrequtils > /dev/null <<< "GOVERNOR="$GOV""
    sudo systemctl enable cpufrequtils 2>/dev/null || true
    sudo systemctl restart cpufrequtils 2>/dev/null || true
    echo "  Governor: $GOV"
fi

# -- Phase 5: Service Trimming ---------------------------------
echo ""
echo "=== [5/9] Disabling Unnecessary Services ==="
for svc in bluetooth cups-browsed cups avahi-daemon ModemManager wpa_supplicant snapd snapd.apparmor apparmor apport whoopsie speech-dispatcher rsyslog apt-daily apt-daily-upgrade e2scrub_all; do
    if systemctl list-unit-files --type=service | grep -q "^$svc"; then
        sudo systemctl stop "$svc" 2>/dev/null || true
        sudo systemctl disable "$svc" 2>/dev/null || true
        echo "  Disabled: $svc"
    fi
done
sudo systemctl mask snapd ModemManager 2>/dev/null || true

# -- Phase 6: ZRAM + Swap --------------------------------------
echo ""
echo "=== [6/9] ZRAM + Swap ==="
if [[ ${RAM_MB%.*} -lt 2048 ]]; then
    ZRAM_PCT=100
elif [[ ${RAM_MB%.*} -lt 4096 ]]; then
    ZRAM_PCT=75
else
    ZRAM_PCT=50
fi
sudo tee /etc/default/zramswap > /dev/null <<< "ALGO=lz4
PERCENT=$ZRAM_PCT
PRIORITY=100"
sudo systemctl restart zramswap

if ! swapon --show=NAME | grep -q swap; then
    [[ ${RAM_MB%.*} -le 2048 ]] && SWAP_SIZE="1G" || SWAP_SIZE="512M"
    sudo fallocate -l "$SWAP_SIZE" /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=$(echo "$SWAP_SIZE" | sed 's/G/*1024/' | sed 's/M//') 2>/dev/null
    sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
    grep -q /swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "  Swapfile: $SWAP_SIZE"
fi

# -- Phase 7: Docker Tuning ------------------------------------
echo ""
echo "=== [7/9] Docker Tuning ==="
sudo tee /etc/docker/daemon.json > /dev/null <<'DOCKEREEOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "3m", "max-file": "2" },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": { "nofile": { "Name": "nofile", "Hard": 64000, "Soft": 64000 } },
  "features": { "buildkit": true },
  "builder": { "gc": { "enabled": true, "defaultKeepStorage": "2GB" } },
  "exec-opts": ["native.cgroupdriver=systemd"]
}
DOCKEREEOF
sudo systemctl restart docker
sudo docker system prune -af --volumes 2>/dev/null || true

# -- Phase 8: Logrotate + Cron ---------------------------------
echo ""
echo "=== [8/9] Log Management ==="
sudo tee /etc/logrotate.d/autoboros-performance > /dev/null <<'LOGEOF'
/var/log/docker/*.log
/var/lib/docker/containers/*/*.log
{
    daily
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    size 5M
}
LOGEOF

sudo tee /etc/cron.weekly/autoboros-trim > /dev/null <<'CRONEOF'
#!/bin/sh
echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
fstrim -av / 2>/dev/null || true
CRONEOF
sudo chmod +x /etc/cron.weekly/autoboros-trim

# -- Phase 9: Beszel Agent -------------------------------------
echo ""
echo "=== [9/9] Beszel Agent ==="
if [[ -f "${SCRIPT_DIR}/scripts/setup-beszel.sh" ]]; then
    echo "  Run 'bash scripts/setup-beszel.sh agent-only' manually with your hub key"
else
    echo "  setup-beszel.sh not found"
fi

# -- Summary ---------------------------------------------------
echo ""
echo "    +----------------------------------------------+"
echo "    |      PERFORMANCE UPGRADE v3.0 COMPLETE       |"
echo "    +----------------------------------------------+"
echo ""
echo "  Profile: $PROFILE"
echo "  GRUB: $GRUB"
echo "  ZRAM: $(zramctl --noheadings 2>/dev/null | awk '{print $4}' || echo N/A)"
echo "  Swap: $(free -h | awk '/^Swap:/ {print $2" total, "$3" used"}')"
echo "  Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo N/A)"
echo ""
echo "  REBOOT NOW for kernel changes."
echo "  After reboot: health && mem"
echo ""
