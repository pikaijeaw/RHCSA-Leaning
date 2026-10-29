# เฉลยข้อสอบจำลอง ชุดที่ 1

> ลองทำเองให้เสร็จก่อนค่อยเปิดดู แต่ละข้อมีวิธีทำและวิธีตรวจ

---

## ส่วน A — serverb

### A1. Reset root password
1. Reboot → ที่เมนู GRUB กด `e`
2. ท้ายบรรทัด `linux ...` เพิ่ม `rd.break` → `Ctrl+x`
3. ใช้คำสั่งต่อไปนี้

```bash
mount -o remount,rw /sysroot
chroot /sysroot
echo trootent | passwd --stdin root
touch /.autorelabel
exit
exit
```
ตรวจ: login ด้วย root / `trootent`

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

### A3. ขยาย LV
```bash
lvextend -r -L 230M /dev/myvol/vo
df -h /reports        # ประมาณ 225M–230M
```
ถ้า VG ไม่พอ: `vgextend myvol /dev/vdX` ก่อน

### A4. Swap 512 MiB
```bash
lsblk                                   # หาดิสก์ที่มีที่ว่าง เช่น /dev/vdc
fdisk /dev/vdc                          # n → Enter → Enter → +512M → t → swap → w
partprobe /dev/vdc
mkswap /dev/vdc1
echo "UUID=$(blkid -s UUID -o value /dev/vdc1) swap swap defaults 0 0" >> /etc/fstab
swapon -a
swapon --show                           # ต้องเห็นทั้ง swap เดิมและใหม่
```

### A5. LV qa
```bash
fdisk /dev/vdc                          # n → +1G (ต้องมากกว่า 960M) → t → lvm → w
partprobe /dev/vdc
pvcreate /dev/vdc2
vgcreate -s 16M qagroup /dev/vdc2
lvcreate -n qa -l 60 qagroup
mkfs.vfat /dev/qagroup/qa
mkdir -p /mnt/qa
echo "/dev/qagroup/qa /mnt/qa vfat defaults 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a
vgdisplay qagroup | grep "PE Size"      # 16.00 MiB
lvdisplay /dev/qagroup/qa | grep "Current LE"   # 60
```

### A6. tuned
```bash
dnf install -y tuned
systemctl enable --now tuned
tuned-adm recommend
tuned-adm profile virtual-guest         # ตามค่าที่ recommend แสดง
tuned-adm active
```

---

## ส่วน B — servera

### B1. Network
```bash
nmcli con show
nmcli con mod "<ชื่อ connection>" ipv4.method manual \
  ipv4.addresses 192.168.122.10/24 ipv4.gateway 192.168.122.1 \
  ipv4.dns 192.168.122.1 connection.autoconnect yes
nmcli con up "<ชื่อ connection>"
hostnamectl set-hostname servera.lab.example.com
```

### B2. Repository
เหมือน A2

### B3. Web server port 82
```bash
semanage port -a -t http_port_t -p tcp 82
restorecon -Rv /var/www/html
firewall-cmd --permanent --add-port=82/tcp
firewall-cmd --reload
systemctl enable --now httpd ; systemctl restart httpd
curl http://servera:82/file1          # ต้องได้คำว่า exam
```

### B4. Users และ Groups
```bash
groupadd sysmgrs
useradd -G sysmgrs natasha
useradd -G sysmgrs harry
useradd -s /sbin/nologin sarah
for u in natasha harry sarah; do echo flectrag | passwd --stdin $u; done
```

### B5. Shared directory
```bash
mkdir -p /home/managers
chgrp sysmgrs /home/managers
chmod 2770 /home/managers
ls -ld /home/managers                 # drwxrws---. root sysmgrs
```

### B6. Cron
```bash
crontab -e -u natasha
```
```
23 14 * * * /usr/bin/echo hello
*/2 * * * * logger "EX200 in progress"
```
```bash
systemctl enable --now crond
crontab -l -u natasha
```

### B7. NTP
```bash
sed -i 's/^pool/#pool/' /etc/chrony.conf
echo "server 192.168.122.20 iburst" >> /etc/chrony.conf
systemctl enable --now chronyd ; systemctl restart chronyd
chronyc sources                       # ต้องเห็น ^* 192.168.122.20
```

### B8. autofs
```bash
dnf install -y autofs nfs-utils
useradd -u 1501 -M -d /rhome/remoteuser1 remoteuser1
echo "/rhome /etc/auto.rhome" > /etc/auto.master.d/rhome.autofs
echo "remoteuser1 -rw,sync 192.168.122.20:/exports/home/remoteuser1" > /etc/auto.rhome
systemctl enable --now autofs ; systemctl restart autofs
su - remoteuser1 -c "pwd; touch ~/ok && ls -l ~/ok"
```
> บน serverb ต้องให้ directory `/exports/home/remoteuser1` เป็นของ UID 1501 ด้วย: `chown 1501 /exports/home/remoteuser1`

### B9. ACL
```bash
cp /etc/fstab /var/tmp/fstab
chown root:root /var/tmp/fstab
chmod 644 /var/tmp/fstab
setfacl -m u:natasha:rw- /var/tmp/fstab
setfacl -m u:harry:--- /var/tmp/fstab
getfacl /var/tmp/fstab
```

### B10. UID
```bash
useradd -u 3456 alex
echo flectrag | passwd --stdin alex
id alex
```

### B11. find
```bash
mkdir -p /root/findfiles
find / -user harry -type f -exec cp -a {} /root/findfiles/ \; 2>/dev/null
ls -l /root/findfiles
```
> ใส่ `-type f` เพื่อเลือกเฉพาะไฟล์ เพราะ `cp -a` copy แบบ recursive อยู่แล้ว ถ้าไม่ใส่ จะ copy ทั้ง home directory ของ harry (รวมไฟล์ที่ไม่ใช่ของ harry) มาด้วย

### B12. grep
```bash
grep ich /usr/share/dict/words > /root/lines
wc -l /root/lines
```

### B13. tar
```bash
tar -cjf /root/backup.tar.bz2 /usr/local
file /root/backup.tar.bz2             # bzip2 compressed data
```

### B14. Script
```bash
cat > /usr/local/bin/myusers <<'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: myusers <shell>"
    exit 1
fi
awk -F: -v sh="$1" '$7 == sh {print $1}' /etc/passwd
EOF
chmod +x /usr/local/bin/myusers
myusers ; echo $?
myusers /sbin/nologin
```

### B15. Password aging และ sudo
```bash
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   20/' /etc/login.defs
grep ^PASS_MAX_DAYS /etc/login.defs

echo '%sysmgrs ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/sysmgrs
visudo -c
su - natasha -c "sudo -n id -u"       # ต้องได้ 0
```

### B16. Flatpak
```bash
dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.gnome.TextEditor     # รันเป็น root = ติดตั้งแบบ system
flatpak list --app --columns=application,installation   # ต้องเห็น system
```
> ห้ามใส่ `--user` เพราะโจทย์ต้องการให้ทุก user ใช้ได้

### B17. systemd timer
```bash
cat > /etc/systemd/system/diskreport.service <<'EOF'
[Unit]
Description=Disk usage report

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/df -h > /root/diskreport.txt'
EOF

cat > /etc/systemd/system/diskreport.timer <<'EOF'
[Unit]
Description=Disk report on weekdays at 08:30

[Timer]
OnCalendar=Mon..Fri *-*-* 08:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now diskreport.timer
systemctl list-timers diskreport.timer
systemctl start diskreport.service && cat /root/diskreport.txt   # ทดสอบ
```
- `Persistent=true` = ถ้าเครื่องปิดอยู่ตอนถึงเวลา ให้รันทันทีที่เปิดเครื่อง
- ต้องห่อด้วย `/bin/bash -c` เพราะ `ExecStart` ไม่ได้รันผ่าน shell จึงใช้ `>` ตรง ๆ ไม่ได้

---

## สุดท้าย
```bash
findmnt --verify
reboot
```
แล้วตรวจซ้ำทุกข้อ หรือรัน `bash exam/check-servera.sh`
