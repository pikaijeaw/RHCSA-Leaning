# เฉลยข้อสอบจำลอง ชุดที่ 2

> ทำให้เสร็จและรันสคริปต์ตรวจก่อน แล้วค่อยเปิดเฉลยเฉพาะข้อที่ไม่ผ่าน

---

## ส่วน A — serverb

### A1. Reset root password ด้วย `init=/bin/bash`
1. Reboot → ที่เมนู GRUB กด `e`
2. บรรทัดที่ขึ้นต้นด้วย `linux`: ลบ `rhgb quiet` และ `console=...` ทุกตัว แล้วเพิ่ม `init=/bin/bash` ท้ายบรรทัด → `Ctrl+x`
3. จะได้ prompt `bash-5.x#` ทันที (ไม่ผ่าน systemd) แล้วพิมพ์:

```bash
mount -o remount,rw /
echo redhat2 | passwd --stdin root
touch /.autorelabel
exec /sbin/init          # บูตต่อตามปกติ (หรือ /usr/sbin/reboot -f)
```

> ถ้าคำสั่ง `reboot` ธรรมดาไม่ทำงาน เป็นเพราะไม่มี systemd รันอยู่ ให้ใช้ `exec /sbin/init` หรือ `reboot -f`

### A2. Repository
```bash
cat > /etc/yum.repos.d/exam.repo <<'EOF'
[BaseOS]
name=BaseOS
baseurl=http://192.168.122.20/repo/BaseOS
enabled=1
gpgcheck=0

[AppStream]
name=AppStream
baseurl=http://192.168.122.20/repo/AppStream
enabled=1
gpgcheck=0
EOF
dnf clean all ; dnf repolist
```

### A3. VG / LV / label
```bash
pvcreate /dev/vdb
vgcreate -s 8M datavg /dev/vdb
lvcreate -n datalv -l 50 datavg            # 50 × 8 MiB = 400 MiB
mkfs.ext4 -L DATA /dev/datavg/datalv       # หรือ e2label /dev/datavg/datalv DATA หลัง format
mkdir -p /data
echo "LABEL=DATA /data ext4 defaults 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a
blkid /dev/datavg/datalv                   # ต้องเห็น LABEL="DATA"
vgs -o vg_name,vg_extent_size datavg       # 8.00m
```

### A4. ขยาย ext4
```bash
echo keep > /data/keep.txt
lvextend -r -L 600M /dev/datavg/datalv     # -r เรียก resize2fs ให้เอง
df -h /data ; cat /data/keep.txt
```

### A5. Swap บน LV
```bash
lvcreate -n swaplv -L 256M datavg
mkswap /dev/datavg/swaplv
echo "/dev/datavg/swaplv swap swap defaults 0 0" >> /etc/fstab
swapon -a ; swapon --show
```

### A6. Default target และ journal
```bash
systemctl set-default multi-user.target
mkdir -p /var/log/journal
systemctl restart systemd-journald
journalctl --list-boots                    # หลัง reboot ต้องเห็นมากกว่า 1 บรรทัด
```

### A7. ลบ kernel argument
```bash
grubby --update-kernel=ALL --remove-args="rhgb quiet"
grubby --info=ALL | grep ^args              # ต้องไม่มี rhgb และ quiet
```
> ถ้าต้องการให้ kernel ที่ติดตั้งในอนาคตไม่มีด้วย ให้ลบออกจาก `GRUB_CMDLINE_LINUX` ใน `/etc/default/grub` ด้วย

---

## ส่วน B — servera

### B1. Network + IPv6
```bash
CON=$(nmcli -g NAME connection show --active | head -1)
nmcli con mod "$CON" ipv4.method manual ipv4.addresses 192.168.122.10/24 \
  ipv4.gateway 192.168.122.1 ipv4.dns 192.168.122.1 \
  ipv6.method manual ipv6.addresses fd00:122::10/64 connection.autoconnect yes
nmcli con up "$CON"
hostnamectl set-hostname servera.lab.example.com
ip -6 addr show | grep fd00:122::10
```

### B2. Repository
เหมือน A2

### B3. Web server ที่ `/srv/web`
```bash
systemctl start httpd ; curl -s localhost | head -3   # ได้ 403 Forbidden
ls -Zd /srv/web ; ls -Z /srv/web                      # var_t และ admin_home_t ไม่ใช่ httpd_sys_content_t

semanage fcontext -a -t httpd_sys_content_t "/srv/web(/.*)?"
restorecon -Rv /srv/web
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
systemctl enable --now httpd
curl http://servera/                                  # <h1>exam2 web OK</h1>
```
> **กับดักของข้อนี้:** ถ้ารันแค่ `restorecon` โดยไม่ทำ `semanage fcontext` ก่อน ไฟล์จะกลับไปเป็น context ค่าเริ่มต้นของ `/srv` ซึ่ง httpd ก็ยังอ่านไม่ได้

### B4. Users และ Groups
```bash
groupadd -g 4000 devops
useradd -u 2001 -G devops amy
useradd -G devops bob
useradd -s /sbin/nologin carl
for u in amy bob carl; do echo redhat | passwd --stdin $u; done
chage -M 60 -W 5 amy
chage -E 2027-12-31 bob
chage -l amy ; chage -l bob
```

### B5. sudo
```bash
usermod -aG wheel amy          # กลุ่ม wheel ใน RHEL ตั้งไว้เป็น (ALL) ALL ที่ต้องใส่ password อยู่แล้ว

cat > /etc/sudoers.d/bob <<'EOF'
bob ALL=(root) /usr/bin/systemctl, /usr/bin/journalctl
EOF
chmod 440 /etc/sudoers.d/bob
visudo -c
sudo -l -U amy ; sudo -l -U bob
```

### B6. `/srv/devops`
```bash
mkdir -p /srv/devops
chgrp devops /srv/devops
chmod 3770 /srv/devops         # 2000 SGID + 1000 sticky + 770
ls -ld /srv/devops             # drwxrws--T
```

### B7. Default ACL
```bash
mkdir -p /srv/reports
chown root:root /srv/reports
chmod 755 /srv/reports
setfacl -m u:amy:rwx,u:carl:r-x /srv/reports           # สิทธิ์ของตัว directory
setfacl -m d:u:amy:rwx,d:u:carl:r-x /srv/reports       # สิทธิ์ของไฟล์ที่จะสร้างใหม่
getfacl /srv/reports
```
> ใส่ `x` ให้ carl ที่ระดับ directory ด้วย เพราะต้องมี `x` ถึงจะ `cd` และเปิดไฟล์ข้างในได้ (ไฟล์ปกติที่สร้างใหม่จะไม่ได้ `x` อยู่แล้ว)

### B8. umask ของ amy
```bash
echo "umask 027" >> /home/amy/.bashrc
su - amy -c "umask"            # 0027
```

### B9. NFS ใน fstab
```bash
dnf install -y nfs-utils
mkdir -p /mnt/share
echo "192.168.122.20:/exports/share /mnt/share nfs ro,_netdev 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a
findmnt /mnt/share             # OPTIONS ต้องมี ro
```

### B10. autofs แบบ wildcard
```bash
dnf install -y autofs
useradd -u 1501 -M -d /netusers/remoteuser1 remoteuser1
useradd -u 1502 -M -d /netusers/remoteuser2 remoteuser2
echo "/netusers /etc/auto.netusers" > /etc/auto.master.d/netusers.autofs
echo "* -rw,sync 192.168.122.20:/exports/home/&" > /etc/auto.netusers
systemctl enable --now autofs ; systemctl restart autofs
su - remoteuser2 -c "pwd; touch ~/ok && ls -l ~/ok"
```

### B11. at
```bash
su - amy -c 'echo "touch /tmp/amy-at" | at 23:30'
atq                            # root เห็นงานของทุกคน คอลัมน์สุดท้ายต้องเป็น amy
```

### B12. Timer แบบนับเวลา
```bash
cat > /etc/systemd/system/uptimelog.service <<'EOF'
[Unit]
Description=Append uptime to log

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/uptime >> /var/log/uptime.log'
EOF

cat > /etc/systemd/system/uptimelog.timer <<'EOF'
[Unit]
Description=Log uptime every 10 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now uptimelog.timer
systemctl list-timers uptimelog.timer
```
> `OnBootSec` อย่างเดียวจะรันแค่ครั้งเดียวหลังบูต ต้องมี `OnUnitActiveSec` ด้วยถึงจะรันซ้ำ

### B13. Flatpak แบบ user
```bash
dnf install -y flatpak
su - amy -c "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
su - amy -c "flatpak install --user -y flathub org.gnome.Calculator"
su - amy -c "flatpak list --user --app"
flatpak list --system --app    # ในฐานะ root ต้องไม่เห็น Calculator
```

### B14. SSH
```bash
echo "PermitRootLogin no" > /etc/ssh/sshd_config.d/00-exam.conf
sshd -t && systemctl restart sshd
sshd -T | grep -i permitrootlogin     # permitrootlogin no

su - amy
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
ssh-copy-id amy@serverb               # ใส่ password ของ amy บน serverb (redhat)
ssh amy@serverb hostname              # ต้องไม่ถาม password
exit
```
> ไฟล์ใน `/etc/ssh/sshd_config.d/` ถูกอ่านก่อนเนื้อหาใน `sshd_config` และ sshd ใช้ค่าแรกที่เจอ จึงตั้งชื่อขึ้นต้นด้วย `00-` ให้อ่านก่อนไฟล์อื่น

### B15. Firewall
```bash
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.122.99 reject'
firewall-cmd --reload
firewall-cmd --list-all
```

### B16. find ตามขนาด
```bash
find /usr/share -type f -size +3M > /root/bigfiles.txt 2>/dev/null
wc -l /root/bigfiles.txt
```

### B17. tar + xz
```bash
tar -cJf /root/sysconfig.tar.xz /etc/sysconfig
mkdir -p /root/restore
tar -xJf /root/sysconfig.tar.xz -C /root/restore
ls /root/restore/etc/sysconfig
```

### B18. Script
```bash
cat > /usr/local/bin/mkusers <<'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: mkusers <file>"
    exit 1
fi
if [ ! -f "$1" ]; then
    echo "File not found"
    exit 2
fi
while read -r U; do
    [ -z "$U" ] && continue
    id "$U" &>/dev/null && continue
    useradd -s /sbin/nologin "$U"
done < "$1"
exit 0
EOF
chmod +x /usr/local/bin/mkusers
mkusers ; echo $?              # 1
mkusers /nope ; echo $?        # 2
```

### B19. Process และ tuned
```bash
top                            # กด P เรียงตาม CPU จะเห็น cpuhog อยู่บนสุด
ps aux --sort=-%cpu | head -5
pkill -f cpuhog                # หรือ kill <PID>
pgrep -f cpuhog || echo "หยุดแล้ว"

tuned-adm profile throughput-performance
tuned-adm active
```

---

## สุดท้าย
```bash
findmnt --verify
reboot
```
แล้วรันสคริปต์ตรวจของทั้งสองเครื่อง
