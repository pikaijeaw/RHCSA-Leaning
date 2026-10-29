#!/bin/bash
# ตรวจผลข้อสอบจำลองชุดที่ 2 (RHEL 10) ส่วน A บน serverb (รันเป็น root หลัง reboot)
# usage: bash check-exam2-serverb.sh

PASS=0
FAIL=0

check() {
    local desc="$1"; shift
    if "$@" &>/dev/null; then
        echo -e "[\e[32mPASS\e[0m] $desc"
        PASS=$((PASS + 1))
    else
        echo -e "[\e[31mFAIL\e[0m] $desc"
        FAIL=$((FAIL + 1))
    fi
}

# ขนาด LV เป็น MiB (ตัวเลขจำนวนเต็ม)
lv_mib() { lvs --noheadings --units m --nosuffix -o lv_size "$1" 2>/dev/null | awk '{printf "%d", $1}'; }

[ "$(id -u)" -eq 0 ] || { echo "ต้องรันเป็น root"; exit 1; }

echo "== A1 root password =="
echo "(ตรวจเอง: login เป็น root ด้วย password redhat2)"

echo "== A2 Repo =="
check "repo BaseOS ใช้งานได้" bash -c "dnf -q repolist enabled | grep -qi baseos"
check "repo AppStream ใช้งานได้" bash -c "dnf -q repolist enabled | grep -qi appstream"

echo "== A3 datavg / datalv =="
check "VG datavg มี PE size 8 MiB" bash -c "test \"\$(vgs --noheadings --units m --nosuffix -o vg_extent_size datavg | tr -d ' ')\" = 8.00"
check "datalv เป็น ext4" test "$(blkid -s TYPE -o value /dev/datavg/datalv 2>/dev/null)" = ext4
check "datalv มี label DATA" test "$(blkid -s LABEL -o value /dev/datavg/datalv 2>/dev/null)" = DATA
check "fstab ใช้ LABEL=DATA กับ /data" bash -c "grep -Eq '^LABEL=\"?DATA\"?[[:space:]]+/data[[:space:]]' /etc/fstab"
check "/data ถูก mount" findmnt /data

echo "== A4 ขยาย datalv =="
SIZE=$(lv_mib /dev/datavg/datalv)
check "datalv ขนาด 570-630 MiB (ตอนนี้ ${SIZE:-?} MiB)" test "${SIZE:-0}" -ge 570 -a "${SIZE:-0}" -le 630
FS=$(df -m --output=size /data 2>/dev/null | tail -1 | tr -d ' ')
check "filesystem ขยายตามแล้ว (ตอนนี้ ${FS:-?} MiB)" test "${FS:-0}" -ge 520
check "/data/keep.txt ยังอยู่" grep -q keep /data/keep.txt

echo "== A5 swaplv =="
SW=$(lv_mib /dev/datavg/swaplv)
check "swaplv ขนาด 256 MiB (ตอนนี้ ${SW:-?} MiB)" test "${SW:-0}" -ge 240 -a "${SW:-0}" -le 272
check "swaplv เปิดใช้งานอยู่" bash -c "grep -q \"^\$(readlink -f /dev/datavg/swaplv) \" /proc/swaps"
check "swaplv อยู่ใน fstab" bash -c "grep -Eq '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab && grep -Eq '(datavg/swaplv|datavg-swaplv|UUID=$(blkid -s UUID -o value /dev/datavg/swaplv))' /etc/fstab"

echo "== A6 target / journal =="
check "default target = multi-user.target" test "$(systemctl get-default)" = multi-user.target
check "journal เก็บถาวร" bash -c "test -d /var/log/journal/\$(cat /etc/machine-id)"

echo "== A7 kernel args =="
check "ไม่มี rhgb ใน kernel ใด" bash -c "! grubby --info=ALL | grep ^args | grep -qw rhgb"
check "ไม่มี quiet ใน kernel ใด" bash -c "! grubby --info=ALL | grep ^args | grep -qw quiet"

echo "== ทั่วไป =="
check "SELinux Enforcing" test "$(getenforce)" = Enforcing
check "fstab ไม่มี error" findmnt --verify

echo
echo "ผ่าน $PASS ข้อ / ไม่ผ่าน $FAIL ข้อ"
