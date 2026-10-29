#!/bin/bash
# ตรวจผลข้อสอบจำลองชุดที่ 2 (RHEL 10) ส่วน B บน servera (รันเป็น root หลัง reboot)
# usage: bash check-exam2-servera.sh

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

shadow_field() { getent shadow "$1" | cut -d: -f"$2"; }

[ "$(id -u)" -eq 0 ] || { echo "ต้องรันเป็น root"; exit 1; }

echo "== B1 Network =="
check "hostname = servera.lab.example.com" test "$(hostname)" = servera.lab.example.com
check "มี IPv4 192.168.122.10/24" bash -c "ip -4 addr | grep -q '192.168.122.10/24'"
check "gateway = 192.168.122.1" bash -c "ip route | grep -q '^default via 192.168.122.1'"
check "มี IPv6 fd00:122::10/64" bash -c "ip -6 addr | grep -q 'fd00:122::10/64'"

echo "== B2 Repo =="
check "repo BaseOS ใช้งานได้" bash -c "dnf -q repolist enabled | grep -qi baseos"
check "repo AppStream ใช้งานได้" bash -c "dnf -q repolist enabled | grep -qi appstream"

echo "== B3 Web /srv/web =="
check "httpd enabled" systemctl is-enabled httpd
check "DocumentRoot ยังเป็น /srv/web" bash -c "grep -Eq '^DocumentRoot[[:space:]]+\"?/srv/web' /etc/httpd/conf/httpd.conf"
check "มีกฎ fcontext ถาวรสำหรับ /srv/web" bash -c "semanage fcontext -l -C | grep -q '^/srv/web'"
check "index.html มี type httpd_sys_content_t" bash -c "ls -Z /srv/web/index.html | grep -q httpd_sys_content_t"
check "firewall อนุญาต http (permanent)" bash -c "firewall-cmd --permanent --list-services | grep -qw http"
check "curl http://localhost/ ได้หน้าเว็บ" bash -c "curl -sf http://localhost/ | grep -q 'exam2 web OK'"

echo "== B4 Users =="
check "devops GID 4000" test "$(getent group devops | cut -d: -f3)" = 4000
check "amy UID 2001" test "$(id -u amy 2>/dev/null)" = 2001
check "amy อยู่ใน devops" bash -c "id -nG amy | grep -qw devops"
check "bob อยู่ใน devops" bash -c "id -nG bob | grep -qw devops"
check "carl ใช้ nologin" bash -c "getent passwd carl | grep -q nologin\$"
check "amy password max 60 วัน" test "$(shadow_field amy 5)" = 60
check "amy เตือนล่วงหน้า 5 วัน" test "$(shadow_field amy 6)" = 5
check "bob หมดอายุ 2027-12-31" test "$(shadow_field bob 8)" = "$(( $(date -ud 2027-12-31 +%s) / 86400 ))"

echo "== B5 sudo =="
check "amy sudo ได้ทุกคำสั่ง" bash -c "sudo -l -U amy | grep -Eq '\(ALL(: ALL)?\) ALL'"
check "amy ต้องใส่ password" bash -c "! sudo -l -U amy | grep -q NOPASSWD"
check "bob sudo systemctl ได้" bash -c "sudo -l -U bob | grep -q /usr/bin/systemctl"
check "bob sudo journalctl ได้" bash -c "sudo -l -U bob | grep -q /usr/bin/journalctl"
check "bob ไม่ได้ sudo ทุกคำสั่ง" bash -c "! sudo -l -U bob | grep -Eq '\) (NOPASSWD: )?ALL\$'"

echo "== B6 /srv/devops =="
check "group owner = devops" test "$(stat -c %G /srv/devops 2>/dev/null)" = devops
check "permission = 3770" test "$(stat -c %a /srv/devops 2>/dev/null)" = 3770

echo "== B7 /srv/reports ACL =="
check "owner root:root สิทธิ์ 755" test "$(stat -c %U:%G:%a /srv/reports 2>/dev/null)" = root:root:755
check "amy rwx ที่ directory" bash -c "getfacl -p /srv/reports | grep -q '^user:amy:rwx'"
check "carl อ่านอย่างเดียวที่ directory" bash -c "getfacl -p /srv/reports | grep -Eq '^user:carl:r-[-x]'"
check "default ACL amy rwx" bash -c "getfacl -p /srv/reports | grep -q '^default:user:amy:rwx'"
check "default ACL carl อ่านอย่างเดียว" bash -c "getfacl -p /srv/reports | grep -Eq '^default:user:carl:r-[-x]'"

echo "== B8 umask amy =="
check "umask ของ amy = 0027" test "$(su - amy -c umask 2>/dev/null)" = 0027

echo "== B9 NFS fstab =="
check "/mnt/share mount เป็น nfs" bash -c "findmnt -n -o FSTYPE /mnt/share | grep -q nfs"
check "/mnt/share เป็น read-only" bash -c "findmnt -n -o OPTIONS /mnt/share | grep -Eq '(^|,)ro(,|\$)'"
check "อยู่ใน fstab" bash -c "grep -Eq '^[^#].*/exports/share[[:space:]]+/mnt/share' /etc/fstab"

echo "== B10 autofs wildcard =="
check "remoteuser1 UID 1501 home /netusers/remoteuser1" test "$(getent passwd remoteuser1 | cut -d: -f3,6)" = 1501:/netusers/remoteuser1
check "remoteuser2 UID 1502 home /netusers/remoteuser2" test "$(getent passwd remoteuser2 | cut -d: -f3,6)" = 1502:/netusers/remoteuser2
check "autofs enabled" systemctl is-enabled autofs
check "มี map แบบ wildcard" bash -c "grep -hEq '^\*[[:space:]].*/exports/home/&' /etc/auto.* /etc/auto.master.d/* 2>/dev/null"
check "/netusers/remoteuser1 mount ได้" bash -c "ls /netusers/remoteuser1 && findmnt /netusers/remoteuser1 | grep -q nfs"
check "/netusers/remoteuser2 mount ได้" bash -c "ls /netusers/remoteuser2 && findmnt /netusers/remoteuser2 | grep -q nfs"

echo "== B11 at =="
check "มีงาน at ของ amy" bash -c "atq | awk '{print \$NF}' | grep -qx amy"

echo "== B12 uptimelog.timer =="
check "uptimelog.timer enabled" systemctl is-enabled uptimelog.timer
# ตรวจทั้งค่าที่ systemd โหลดแล้ว และค่าในไฟล์ (รองรับการเขียนได้หลายแบบ เช่น 2min, 2m, 120s)
check "OnBootSec = 2min" bash -c "systemctl show -p TimersMonotonic uptimelog.timer | grep -q 'OnBootUSec=2min' || systemctl cat uptimelog.timer | grep -Eq '^OnBootSec=[[:space:]]*(2min|2m|120s?)[[:space:]]*\$'"
check "OnUnitActiveSec = 10min" bash -c "systemctl show -p TimersMonotonic uptimelog.timer | grep -q 'OnUnitActiveUSec=10min' || systemctl cat uptimelog.timer | grep -Eq '^OnUnitActiveSec=[[:space:]]*(10min|10m|600s?)[[:space:]]*\$'"
check "service ต่อท้าย /var/log/uptime.log" bash -c "B=\$(wc -l < /var/log/uptime.log 2>/dev/null || echo 0); systemctl start uptimelog.service && test \$(wc -l < /var/log/uptime.log) -gt \$B"

echo "== B13 Flatpak (user) =="
check "amy มี remote flathub แบบ user" bash -c "su - amy -c 'flatpak remotes --user --columns=name' | grep -qx flathub"
check "Calculator ติดตั้งให้ amy" bash -c "su - amy -c 'flatpak list --user --app --columns=application' | grep -qx org.gnome.Calculator"
check "Calculator ไม่ได้ติดตั้งแบบ system" bash -c "! flatpak list --system --app --columns=application | grep -qx org.gnome.Calculator"

echo "== B14 SSH =="
check "PermitRootLogin no" bash -c "sshd -T | grep -qi '^permitrootlogin no'"
check "amy ssh ไป serverb โดยไม่ใช้ password" bash -c "su - amy -c 'ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 amy@serverb true'"

echo "== B15 Firewall =="
check "อนุญาต https (permanent)" bash -c "firewall-cmd --permanent --list-services | grep -qw https"
check "rich rule ปฏิเสธ 192.168.122.99" bash -c "firewall-cmd --permanent --list-rich-rules | grep '192.168.122.99' | grep -Eq 'reject|drop'"

echo "== B16 find =="
check "/root/bigfiles.txt ถูกต้อง" bash -c "diff -q <(sort /root/bigfiles.txt) <(find /usr/share -type f -size +3M 2>/dev/null | sort)"

echo "== B17 tar xz =="
check "/root/sysconfig.tar.xz เป็น xz" bash -c "file /root/sysconfig.tar.xz | grep -q XZ"
check "แตกไว้ที่ /root/restore/etc/sysconfig" test -d /root/restore/etc/sysconfig

echo "== B18 Script mkusers =="
check "ไม่มี arg → exit 1" bash -c "/usr/local/bin/mkusers; test \$? -eq 1"
check "ไม่มีไฟล์ → exit 2" bash -c "/usr/local/bin/mkusers /nonexistent-file; test \$? -eq 2"
TMPF=$(mktemp)
printf 'exam2u1\n\nexam2u2\namy\n' > "$TMPF"
check "สร้าง user จากไฟล์และ exit 0" bash -c "/usr/local/bin/mkusers $TMPF && id exam2u1 && id exam2u2"
check "user ใหม่ใช้ /sbin/nologin" bash -c "getent passwd exam2u1 | grep -q ':/sbin/nologin\$'"
userdel -r exam2u1 &>/dev/null; userdel -r exam2u2 &>/dev/null; rm -f "$TMPF"

echo "== B19 Process / tuned =="
check "cpuhog ไม่ได้รันอยู่" bash -c "! pgrep -f /usr/local/bin/cpuhog"
check "tuned = throughput-performance" bash -c "tuned-adm active | grep -q throughput-performance"

echo "== ทั่วไป =="
check "SELinux Enforcing" test "$(getenforce)" = Enforcing
check "fstab ไม่มี error" findmnt --verify

echo
echo "ผ่าน $PASS ข้อ / ไม่ผ่าน $FAIL ข้อ"
