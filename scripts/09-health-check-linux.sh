#!/usr/bin/env bash
set +e

run_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'SKIP_ROOT_REQUIRED: %s\n' "$*" >&2
    return 127
  fi
}

printf '===== IDENTITY / BOOT =====\n'
date; hostnamectl 2>/dev/null || true; uname -a; uptime; cat /etc/os-release 2>/dev/null

printf '\n===== EFI =====\n'
if [[ -d /sys/firmware/efi ]]; then echo EFI_MODE=YES; else echo EFI_MODE=NO; fi
command -v efibootmgr >/dev/null 2>&1 && run_root efibootmgr -v || true

printf '\n===== ROOT / USB / BLOCK =====\n'
findmnt -no SOURCE,FSTYPE,OPTIONS /
findmnt /boot /boot/efi 2>/dev/null || true
lsblk -e7 -o NAME,PATH,TRAN,SIZE,MODEL,VENDOR,FSTYPE,FSVER,LABEL,UUID,PARTUUID,MOUNTPOINTS
run_root blkid 2>/dev/null || true
lsusb 2>/dev/null || true

printf '\n===== EFI FILES =====\n'
find /boot/efi/EFI -maxdepth 3 -type f -print 2>/dev/null || true

printf '\n===== CPU / MEMORY =====\n'
lscpu; free -h; grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo

printf '\n===== PCI + DRIVERS =====\n'
lspci -nnk 2>/dev/null || true

printf '\n===== NETWORK =====\n'
ip -br link; ip -br addr; ip route
ss -lntp 2>/dev/null | grep -E '(:22[[:space:]]|Local Address)' || true
for i in /sys/class/net/*; do
  n=${i##*/}; [[ "$n" == lo ]] && continue
  echo "--- $n ---"
  command -v ethtool >/dev/null 2>&1 && run_root ethtool "$n" 2>/dev/null | grep -E 'Speed:|Duplex:|Link detected:' || true
done

printf '\n===== FILESYSTEM =====\n'
df -hT; df -ih

printf '\n===== FAILED UNITS =====\n'
systemctl --failed --no-pager 2>/dev/null || true

printf '\n===== BOOT ERRORS =====\n'
run_root journalctl -b -p err..alert --no-pager 2>/dev/null || true

printf '\n===== KERNEL HARDWARE WARNINGS =====\n'
run_root dmesg -T 2>/dev/null | grep -Ei 'error|fail|warn|usb|xhci|ehci|ahci|ata[0-9]|e1000e|firmware|acpi' | tail -n 250 || true

printf '\n===== HWMON =====\n'
for h in /sys/class/hwmon/hwmon*; do
  [[ -e "$h" ]] || continue
  echo "--- $h $(cat "$h/name" 2>/dev/null) ---"
  grep -H . "$h"/{temp*,fan*,pwm*} 2>/dev/null | head -n 120
done
command -v sensors >/dev/null 2>&1 && sensors || true
printf '\n===== END =====\n'
