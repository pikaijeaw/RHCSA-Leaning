#!/bin/bash
# ตรวจผลข้อสอบจำลองชุดที่ 1 ส่วน B บน servera (รันเป็น root หลัง reboot)
# usage: bash check-servera.sh

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

[ "$(id -u)" -eq 0 ] || { echo "ต้องรันเป็น root"; exit 1; }

echo "== B1 Network =="
check "hostname = servera.lab.example.com" test "$(hostname)" = servera.lab.example.com
check "มี IP 192.168.122.10/24" bash -c "ip -4 addr | grep -q '192.168.122.10/24'"
check "gateway = 192.168.122.1" bash -c "ip route | grep -q '^default via 192.168.122.1'"

echo "== B2 Repo =="
check "repo BaseOS ใช้งานได้" bash -c "dnf -q repolist enabled | grep -qi baseos"
check "repo AppStream ใช้งานได้" bash -c "dnf -q repolist enabled | grep -qi appstream"

echo "== B3 Web port 82 =="
check "httpd enabled" systemctl is-enabled httpd
check "httpd active" systemctl is-active httpd
check "SELinux อนุญาต port 82" bash -c "semanage port -l | grep '^http_port_t' | grep -qw 82"
check "firewall เปิด 82/tcp (permanent)" bash -c "firewall-cmd --permanent --list-ports | grep -qw 82/tcp"
check "curl :82/file1 ได้" bash -c "curl -sf http://localhost:82/file1 | grep -q exam"

echo "== B4 Users =="
check "group sysmgrs มีอยู่" getent group sysmgrs
check "natasha อยู่ใน sysmgrs" bash -c "id -nG natasha | grep -qw sysmgrs"
check "harry อยู่ใน sysmgrs" bash -c "id -nG harry | grep -qw sysmgrs"
check "sarah ใช้ nologin" bash -c "getent passwd sarah | grep -q nologin\$"
check "sarah ไม่อยู่ใน sysmgrs" bash -c "! id -nG sarah | grep -qw sysmgrs"

echo "== B5 /home/managers =="
check "group owner = sysmgrs" test "$(stat -c %G /home/managers 2>/dev/null)" = sysmgrs
check "permission = 2770" test "$(stat -c %a /home/managers 2>/dev/null)" = 2770

echo "== B6 Cron =="
check "natasha cron 14:23" bash -c "crontab -l -u natasha | grep -Eq '^23[[:space:]]+14[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*'"
check "natasha cron ทุก 2 นาที" bash -c "crontab -l -u natasha | grep -q '^\*/2'"

echo "== B7 NTP =="
check "chronyd enabled" systemctl is-enabled chronyd
check "chrony ใช้ serverb" bash -c "grep -Eq '^server[[:space:]]+(192.168.122.20|serverb)' /etc/chrony.conf"

echo "== B8 autofs =="
check "remoteuser1 UID 1501" test "$(id -u remoteuser1 2>/dev/null)" = 1501
check "autofs enabled" systemctl is-enabled autofs
check "/rhome/remoteuser1 mount ได้" bash -c "ls /rhome/remoteuser1 && findmnt /rhome/remoteuser1 | grep -q nfs"

echo "== B9 ACL =="
check "/var/tmp/fstab owner root:root" test "$(stat -c %U:%G /var/tmp/fstab 2>/dev/null)" = root:root
check "natasha rw" bash -c "getfacl -p /var/tmp/fstab | grep -q '^user:natasha:rw-'"
check "harry ---" bash -c "getfacl -p /var/tmp/fstab | grep -q '^user:harry:---'"
check "other r--" bash -c "getfacl -p /var/tmp/fstab | grep -q '^other::r--'"

echo "== B10-B13 =="
check "alex UID 3456" test "$(id -u alex 2>/dev/null)" = 3456
check "/root/findfiles มีไฟล์ของ harry" bash -c "find /root/findfiles -user harry -type f | grep -q ."
check "/root/lines ถูกต้อง" bash -c "diff -q <(grep ich /usr/share/dict/words) /root/lines"
check "/root/backup.tar.bz2 เป็น bzip2" bash -c "file /root/backup.tar.bz2 | grep -q bzip2"

echo "== B14 Script =="
check "myusers ไม่มี arg → exit 1" bash -c "/usr/local/bin/myusers; test \$? -eq 1"
check "myusers /bin/bash แสดง natasha" bash -c "/usr/local/bin/myusers /bin/bash | grep -qx natasha"

echo "== B15 =="
check "PASS_MAX_DAYS = 20" bash -c "grep -Eq '^PASS_MAX_DAYS[[:space:]]+20' /etc/login.defs"
check "natasha sudo ไม่ต้องใส่ password" bash -c "su - natasha -c 'sudo -n true'"

echo "== ทั่วไป =="
check "SELinux Enforcing" test "$(getenforce)" = Enforcing
check "fstab ไม่มี error" findmnt --verify

echo
echo "ผ่าน $PASS ข้อ / ไม่ผ่าน $FAIL ข้อ"
