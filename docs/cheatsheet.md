# RHCSA Cheat Sheet — ทบทวนก่อนสอบ

## ไฟล์สำคัญ
| ไฟล์ | ใช้ทำ |
|---|---|
| `/etc/fstab` | mount ถาวร |
| `/etc/yum.repos.d/*.repo` | repository |
| `/etc/chrony.conf` | NTP |
| `/etc/selinux/config` | โหมด SELinux ถาวร |
| `/etc/login.defs` | ค่าเริ่มต้นของ user ใหม่ (password aging) |
| `/etc/sudoers.d/` | สิทธิ์ sudo |
| `/etc/auto.master.d/*.autofs` + `/etc/auto.*` | autofs |
| `/etc/ssh/sshd_config` | SSH server |
| `/etc/systemd/journald.conf` | journal (Storage=persistent) |
| `/etc/default/grub` | GRUB |

## คำสั่งที่ต้องจำได้แม่น
```bash
# Root password
rd.break → mount -o remount,rw /sysroot → chroot /sysroot → passwd → touch /.autorelabel

# Network
nmcli con mod "<con>" ipv4.method manual ipv4.addresses IP/24 ipv4.gateway GW ipv4.dns DNS
nmcli con up "<con>" ; hostnamectl set-hostname FQDN

# Users
useradd -u UID -G grp -s /sbin/nologin user ; echo pw | passwd --stdin user
usermod -aG grp user ; chage -M 90 user ; chage -d 0 user

# Permissions
chmod 2770 dir  (SGID)    chmod 1777 dir (sticky)    setfacl -m u:user:rw file

# Services
systemctl enable --now svc ; systemctl set-default multi-user.target

# Cron
crontab -e -u user      →  m h dom mon dow command

# LVM
pvcreate /dev/X ; vgcreate -s 16M vg /dev/X ; lvcreate -n lv -L 500M vg (-l = extents)
lvextend -r -L 1G /dev/vg/lv ; vgextend vg /dev/Y

# Filesystem / mount
mkfs.xfs /dev/X ; blkid ; mount -a ; findmnt --verify
mkswap /dev/X ; swapon -a ; swapon --show

# autofs
/etc/auto.master.d/x.autofs:  /rhome  /etc/auto.rhome
/etc/auto.rhome:              user1  -rw,sync  server:/path/user1

# Firewall
firewall-cmd --permanent --add-service=http ; --add-port=82/tcp ; firewall-cmd --reload

# SELinux
semanage fcontext -a -t httpd_sys_content_t "/web(/.*)?" ; restorecon -Rv /web
semanage port -a -t http_port_t -p tcp 82
setsebool -P httpd_enable_homedirs on

# tuned / chrony
tuned-adm profile $(tuned-adm recommend)
server host iburst  →  systemctl restart chronyd ; chronyc sources

# find / grep / tar
find / -user u -type f -exec cp -a {} /dest/ \; 2>/dev/null
grep pattern file > out
tar -cjf x.tar.bz2 dir   (z=gzip j=bzip2 J=xz)

# Flatpak (ใหม่ใน RHEL 10)
flatpak remote-add --if-not-exists NAME URL.flatpakrepo ; flatpak remotes
flatpak install -y NAME app.id ; flatpak list --app ; flatpak uninstall -y app.id ; flatpak uninstall --unused

# systemd timer
/etc/systemd/system/x.service : [Service] Type=oneshot / ExecStart=/bin/bash -c '...'
/etc/systemd/system/x.timer   : [Timer] OnCalendar=Mon..Fri *-*-* 08:30:00 / Persistent=true
                                [Install] WantedBy=timers.target
systemctl daemon-reload ; systemctl enable --now x.timer ; systemctl list-timers
systemd-analyze calendar "Mon..Fri *-*-* 08:30:00"

# Containers (บทเสริม ไม่อยู่ใน objectives RHEL 10)
~/.config/containers/systemd/c.container ; systemctl --user daemon-reload ; systemctl --user start c
loginctl enable-linger user
```

## man page ที่มีตัวอย่างดี ๆ
`man nmcli-examples` · `man 5 fstab` · `man semanage-fcontext` · `man semanage-port` · `man firewalld.richlanguage` · `man 5 crontab` · `man auto.master` · `man 5 autofs` · `man lvcreate` · `man systemd.timer` · `man systemd.time` · `man flatpak-remote-add` · `man flatpak-install`

## Checklist ก่อนส่งข้อสอบ
- [ ] `findmnt --verify` ไม่มี error และ `mount -a` ผ่าน
- [ ] `getenforce` = Enforcing และ `/etc/selinux/config` = enforcing
- [ ] ทุก service ที่โจทย์สั่ง `systemctl is-enabled` = enabled
- [ ] firewall ใช้ `--permanent` แล้ว
- [ ] timer ที่สร้างอยู่ใน `systemctl list-timers` และ enable แล้ว
- [ ] แอป Flatpak ติดตั้งแบบ system (ไม่ใช่ `--user`) ถ้าโจทย์ไม่ได้สั่งอย่างอื่น
- [ ] Reboot ทั้งสองเครื่อง แล้วตรวจซ้ำทุกข้อ
