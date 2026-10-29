# บทที่ 04 — Software, Services, Scheduling และ Logging

## 1. การจัดการ Software ด้วย dnf

**หลักการ:** RHEL ติดตั้งโปรแกรมเป็น package (`.rpm`) โดยดึงจาก **repository** `dnf` จะจัดการ dependency ให้อัตโนมัติ

```bash
dnf repolist                 # ดู repo ที่เปิดใช้งาน
dnf search httpd             # ค้นหา
dnf info httpd               # รายละเอียด
dnf install -y httpd         # ติดตั้ง
dnf remove httpd             # ลบ
dnf update                   # อัปเดตทั้งหมด
dnf provides /usr/bin/semanage   # คำสั่งนี้อยู่ใน package ไหน
dnf provides */semanage
dnf group list               # กลุ่ม package
dnf group install "Development Tools"
dnf history                  # ประวัติ
rpm -qa | grep httpd         # package ที่ติดตั้งแล้ว
rpm -qf /etc/ssh/sshd_config # ไฟล์นี้มาจาก package ไหน
rpm -ql httpd                # ไฟล์ใน package
```

### ตั้งค่า Repository (ออกสอบเกือบ 100%)

> **แนวข้อสอบ:** "ตั้งค่า repository ให้เครื่องนี้ใช้
> `http://content.example.com/rhel10/x86_64/dvd/BaseOS` และ
> `http://content.example.com/rhel10/x86_64/dvd/AppStream`"

**วิธีที่ 1 — เขียนไฟล์เอง**

```bash
vim /etc/yum.repos.d/local.repo
```

```ini
[BaseOS]
name=BaseOS
baseurl=http://content.example.com/rhel10/x86_64/dvd/BaseOS
enabled=1
gpgcheck=0

[AppStream]
name=AppStream
baseurl=http://content.example.com/rhel10/x86_64/dvd/AppStream
enabled=1
gpgcheck=0
```

> ถ้าโจทย์ให้ GPG key มา ให้ใช้ `gpgcheck=1` และ `gpgkey=http://.../RPM-GPG-KEY-redhat-release`

**วิธีที่ 2 — ใช้คำสั่ง**

```bash
dnf config-manager --add-repo http://content.example.com/rhel10/x86_64/dvd/BaseOS
dnf config-manager --add-repo http://content.example.com/rhel10/x86_64/dvd/AppStream
# แล้วเพิ่ม gpgcheck=0 ในไฟล์ที่สร้างขึ้นใน /etc/yum.repos.d/
```

ตรวจ: `dnf clean all && dnf repolist && dnf install -y tree`

*ใน Lab ของเรา ใช้ `http://192.168.122.20/repo/BaseOS` และ `.../AppStream` จาก serverb*

### Flatpak (หัวข้อใหม่ใน objectives ของ RHEL 10)

**หลักการ:** Flatpak เป็นอีกวิธีหนึ่งในการติดตั้งโปรแกรม (ส่วนใหญ่เป็นโปรแกรม GUI) แยกจาก RPM โดยสิ้นเชิง

| RPM / dnf | Flatpak |
|---|---|
| ติดตั้งลงระบบโดยตรง ใช้ library ร่วมกับ OS | ทำงานใน **sandbox** แยกจาก OS |
| ดึงจาก **repository** (`/etc/yum.repos.d/`) | ดึงจาก **remote** (`flatpak remotes`) |
| ชื่อ package เช่น `firefox` | ชื่อ **application ID** แบบ reverse-DNS เช่น `org.mozilla.firefox` |
| dependency = package อื่น | dependency = **runtime** (เช่น `org.gnome.Platform`) ติดตั้งให้อัตโนมัติ |

ตั้งแต่ RHEL 10 โปรแกรมเดสก์ท็อปบางตัว เช่น Firefox, LibreOffice, Thunderbird ไม่มีให้ติดตั้งเป็น RPM แล้ว แต่แจกเป็น Flatpak แทน หัวข้อนี้จึงถูกเพิ่มเข้ามาในข้อสอบ

ติดตั้งแบบได้ 2 ระดับ:
- **system** (ค่าเริ่มต้น เมื่อรันเป็น root): ทุก user ใช้ได้ เก็บที่ `/var/lib/flatpak`
- **user** (`--user`): เฉพาะ user คนนั้น เก็บที่ `~/.local/share/flatpak`

#### 1) ตั้งค่า remote (คล้ายการตั้ง repo)

```bash
dnf install -y flatpak

# เพิ่ม remote จากไฟล์ .flatpakrepo ที่โจทย์ให้ (ไฟล์นี้มี URL และ GPG key อยู่ข้างใน)
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# remote ของ Red Hat (ต้อง login ด้วยบัญชี Red Hat ก่อนติดตั้งได้)
flatpak remote-add --if-not-exists rhel https://flatpaks.redhat.io/rhel.flatpakrepo
podman login registry.redhat.io

flatpak remotes                          # ดู remote ทั้งหมด
flatpak remotes --show-details           # ดู URL ด้วย
flatpak remote-modify --disable flathub  # ปิด remote ชั่วคราว
flatpak remote-modify --enable flathub
flatpak remote-delete flathub            # ลบ remote

# ติดตั้งเฉพาะ user ตัวเอง
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

#### 2) ค้นหา ติดตั้ง และลบ

```bash
flatpak search gedit                     # ค้นจากทุก remote
flatpak remote-ls flathub --app          # ดูแอปทั้งหมดใน remote
flatpak install -y flathub org.gnome.gedit    # ติดตั้ง (ระบุ remote + application ID)
flatpak list --app                       # ดูแอปที่ติดตั้งแล้ว
flatpak info org.gnome.gedit             # รายละเอียด (version, remote, ขนาด)
flatpak run org.gnome.gedit              # รันแอป
flatpak update -y                        # อัปเดตทุกแอป
flatpak uninstall -y org.gnome.gedit     # ลบแอป
flatpak uninstall --unused -y            # ลบ runtime ที่ไม่มีแอปไหนใช้แล้ว
```

> **แนวข้อสอบ:** "ตั้งค่า flatpak remote ชื่อ `myapps` จาก `http://content.example.com/flatpak/myapps.flatpakrepo`
> แล้วติดตั้งแอป `org.example.Notes` ให้ทุก user ใช้ได้"
>
> ```bash
> flatpak remote-add --if-not-exists myapps http://content.example.com/flatpak/myapps.flatpakrepo
> flatpak install -y myapps org.example.Notes
> flatpak list --app                 # ต้องเห็น org.example.Notes ที่มี Installation = system
> ```
>
> ข้อควรระวัง: ถ้าใส่ `--user` หรือรันเป็น user ธรรมดา แอปจะไม่ถูกติดตั้งแบบ system ซึ่งไม่ตรงกับที่โจทย์สั่ง

---

## 2. systemd — จัดการ Service

**หลักการ:** systemd คือ process แรกของระบบ (PID 1) ทำหน้าที่เปิด/ปิด service ต่าง ๆ แต่ละ service เรียกว่า **unit** (`.service`, `.target`, `.timer`, `.mount`, ...)

- `start/stop` = เปิด/ปิด **ตอนนี้**
- `enable/disable` = เปิด/ไม่เปิด **ตอนบูต**
- `enable --now` = ทั้งสองอย่างพร้อมกัน **← ใช้อันนี้ในห้องสอบ**

```bash
systemctl status sshd
systemctl start httpd
systemctl stop httpd
systemctl restart httpd
systemctl reload httpd          # โหลด config ใหม่โดยไม่ตัด connection
systemctl enable --now httpd
systemctl disable --now httpd
systemctl is-enabled httpd
systemctl is-active httpd
systemctl mask telnet.socket    # ห้ามเปิดโดยเด็ดขาด
systemctl list-units --type=service
systemctl list-unit-files --state=enabled
systemctl --failed
systemctl daemon-reload         # หลังแก้ไฟล์ unit
```

### Boot target

| Target | ความหมาย |
|---|---|
| `multi-user.target` | โหมดข้อความ ไม่มี GUI |
| `graphical.target` | มี GUI |
| `rescue.target` | single-user สำหรับซ่อม |
| `emergency.target` | ขั้นต่ำสุด mount `/` แบบอ่านอย่างเดียว |

```bash
systemctl get-default
systemctl set-default multi-user.target   # ถาวร
systemctl isolate graphical.target        # เปลี่ยนตอนนี้
```

---

## 3. การจัดการ Process

```bash
ps aux                       # process ทั้งหมด
ps -ef | grep httpd
pgrep -l sshd
top                          # real-time (กด k เพื่อ kill, r เพื่อ renice, q ออก)
kill 1234                    # ส่ง SIGTERM (15) ขอให้หยุดดี ๆ
kill -9 1234                 # SIGKILL บังคับหยุด
pkill -u harry               # kill ทุก process ของ harry
nice -n 10 tar czf /tmp/a.tgz /usr    # รันด้วย priority ต่ำ (nice สูง = ใจดี = ช้า)
renice -n 5 -p 1234          # ปรับ priority ของ process ที่รันอยู่
```

ค่า nice: `-20` (สำคัญสุด) ถึง `19` (สำคัญน้อยสุด) ค่าเริ่มต้น `0` user ธรรมดาเพิ่มได้อย่างเดียว ลดไม่ได้

### tuned — profile ประสิทธิภาพ

> **แนวข้อสอบ:** "ตั้ง tuned profile ให้เป็นค่าที่ระบบแนะนำ"

```bash
dnf install -y tuned
systemctl enable --now tuned
tuned-adm recommend          # ดูค่าที่แนะนำ (เช่น virtual-guest)
tuned-adm profile virtual-guest
tuned-adm active             # ตรวจ
```

---

## 4. Scheduling: cron, at, systemd timer

### cron — งานที่ทำซ้ำ

รูปแบบ: `นาที ชั่วโมง วันที่ เดือน วันในสัปดาห์ คำสั่ง`

```
┌───── นาที (0-59)
│ ┌───── ชั่วโมง (0-23)
│ │ ┌───── วันที่ (1-31)
│ │ │ ┌───── เดือน (1-12)
│ │ │ │ ┌───── วันในสัปดาห์ (0-7, 0 และ 7 = อาทิตย์)
│ │ │ │ │
* * * * *  command
```

| ตัวอย่าง | ความหมาย |
|---|---|
| `*/5 * * * *` | ทุก 5 นาที |
| `30 14 * * *` | ทุกวัน 14:30 |
| `0 9 * * 1-5` | จันทร์–ศุกร์ 9:00 |
| `23 14 * * *` | ทุกวัน 14:23 |
| `0 */2 * * *` | ทุก 2 ชั่วโมง |
| `0 0 1 * *` | วันที่ 1 ของทุกเดือน เที่ยงคืน |

```bash
crontab -e -u natasha        # แก้ crontab ของ natasha (ในฐานะ root)
crontab -l -u natasha        # ดู
crontab -r -u natasha        # ลบ
```

> **แนวข้อสอบ:** "user `natasha` ต้องรันคำสั่ง `/usr/bin/echo hiya` ทุกวันเวลา 14:23"
>
> ```bash
> crontab -e -u natasha
> 23 14 * * * /usr/bin/echo hiya
> ```
>
> "รัน `logger "EX200 in progress"` ทุก 2 นาที ในนาม natasha"
>
> ```
> */2 * * * * logger "EX200 in progress"
> ```
> ตรวจ: `systemctl status crond` และ `tail -f /var/log/messages`

### at — งานครั้งเดียว

```bash
echo "date > /tmp/at.txt" | at now + 5 minutes
at 17:00 tomorrow
atq                 # ดูคิว
atrm 3              # ลบงานหมายเลข 3
```

### systemd timer (ถูกเน้นใน RHEL 10)

**หลักการ:** timer คือ cron ในแบบของ systemd ต้องมี **2 ไฟล์ที่ชื่อเดียวกัน**:

```
backup.timer   ──(ถึงเวลา)──►  backup.service  ──►  รันคำสั่ง
   "เมื่อไร"                       "ทำอะไร"
```

ข้อดีเมื่อเทียบกับ cron: ดู log ได้ด้วย `journalctl -u`, กำหนดให้รันย้อนหลังได้ถ้าเครื่องปิดอยู่ตอนถึงเวลา (`Persistent=true`), และสั่งให้รอ service อื่นก่อนได้

#### ตัวอย่าง: backup /etc ทุกวันตี 2

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Backup /etc

[Service]
Type=oneshot
ExecStart=/usr/bin/tar czf /root/etc-backup.tar.gz /etc
```

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily backup of /etc

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now backup.timer      # enable ตัว .timer ไม่ใช่ .service
systemctl list-timers                    # ดูเวลาที่จะรันครั้งถัดไป (NEXT) และครั้งล่าสุด (LAST)
systemctl start backup.service           # ทดสอบรันทันที
journalctl -u backup.service             # ดูผล
```

> ไฟล์ `.service` ที่ถูก timer เรียก **ไม่ต้องมี** `[Install]` และไม่ต้อง enable

#### รูปแบบเวลาที่ใช้บ่อย

| ตัวเลือก | ตัวอย่าง | ความหมาย |
|---|---|---|
| `OnCalendar=` | `daily` / `hourly` / `weekly` | ทุกวันเที่ยงคืน / ทุกชั่วโมง / ทุกวันจันทร์เที่ยงคืน |
| | `*-*-* 14:23:00` | ทุกวันเวลา 14:23 |
| | `Mon..Fri *-*-* 09:00:00` | จันทร์–ศุกร์ 9:00 |
| | `*:0/5` | ทุก 5 นาที |
| | `*-*-01 00:00:00` | วันที่ 1 ของทุกเดือน |
| `OnBootSec=` | `15min` | 15 นาทีหลังบูต |
| `OnUnitActiveSec=` | `1h` | ทุก 1 ชั่วโมงนับจากครั้งที่รันล่าสุด (ใช้คู่กับ `OnBootSec`) |
| `RandomizedDelaySec=` | `5min` | สุ่มหน่วงเวลาไม่เกิน 5 นาที |

ตรวจว่าเขียนเวลาถูกก่อนใช้:

```bash
systemd-analyze calendar "Mon..Fri *-*-* 09:00:00"
systemd-analyze calendar --iterations=3 "*:0/5"     # แสดง 3 ครั้งถัดไป
```

ดูตัวอย่างเพิ่ม: `man systemd.timer` และ `man systemd.time` (มีรายการรูปแบบเวลาครบ)

#### Timer ของ user ธรรมดา

```bash
# ในฐานะ natasha (login ผ่าน ssh natasha@localhost)
mkdir -p ~/.config/systemd/user
# สร้าง ~/.config/systemd/user/hello.service และ hello.timer (รูปแบบเดียวกับข้างบน
# แต่ในส่วน [Install] ใช้ WantedBy=timers.target เหมือนเดิม)
systemctl --user daemon-reload
systemctl --user enable --now hello.timer
systemctl --user list-timers

# ในฐานะ root: ให้ timer ของ natasha ทำงานแม้ไม่ได้ login
loginctl enable-linger natasha
```

#### Timer ชั่วคราวแบบไม่ต้องเขียนไฟล์

```bash
systemd-run --on-active=10min /usr/bin/touch /tmp/ten-minutes   # รันครั้งเดียวในอีก 10 นาที
systemd-run --on-calendar="*:0/15" /usr/bin/logger "every 15 min"   # หายหลัง reboot
```

> **แนวข้อสอบ:** "สร้าง systemd timer ชื่อ `diskreport.timer` ที่รัน `df -h > /root/diskreport.txt` ทุกวันจันทร์ถึงศุกร์เวลา 08:30 และต้องทำงานหลัง reboot"
>
> ```bash
> cat > /etc/systemd/system/diskreport.service <<'EOF'
> [Unit]
> Description=Disk usage report
>
> [Service]
> Type=oneshot
> ExecStart=/bin/bash -c '/usr/bin/df -h > /root/diskreport.txt'
> EOF
>
> cat > /etc/systemd/system/diskreport.timer <<'EOF'
> [Unit]
> Description=Disk report on weekdays
>
> [Timer]
> OnCalendar=Mon..Fri *-*-* 08:30:00
> Persistent=true
>
> [Install]
> WantedBy=timers.target
> EOF
>
> systemctl daemon-reload
> systemctl enable --now diskreport.timer
> systemctl list-timers diskreport.timer
> ```
>
> `ExecStart` ไม่ได้รันผ่าน shell ถ้าต้องใช้ `>` หรือ `|` ต้องห่อด้วย `/bin/bash -c '...'`

---

## 5. เวลาและ NTP (chrony)

> **แนวข้อสอบ:** "ตั้งค่าเครื่องเป็น NTP client ของ `classroom.example.com`"

```bash
dnf install -y chrony
vim /etc/chrony.conf
# comment บรรทัด pool เดิม แล้วเพิ่ม:
server classroom.example.com iburst

systemctl enable --now chronyd
systemctl restart chronyd
chronyc sources -v            # ต้องเห็น ^* หน้า server = ซิงค์แล้ว
timedatectl                   # ดู "System clock synchronized: yes"
timedatectl set-timezone Asia/Bangkok
timedatectl list-timezones | grep Bangkok
```

*ใน Lab ใช้ `server 192.168.122.20 iburst`*

---

## 6. Log: journald และ rsyslog

```bash
journalctl                     # log ทั้งหมด
journalctl -u sshd             # เฉพาะ service
journalctl -p err              # เฉพาะระดับ error ขึ้นไป
journalctl -b                  # ตั้งแต่บูตครั้งนี้
journalctl -b -1               # บูตครั้งก่อน (ต้องเปิด persistent ก่อน)
journalctl --since "1 hour ago"
journalctl -f                  # real-time
tail /var/log/messages         # rsyslog
tail /var/log/secure           # log การ login
```

### ทำให้ journal เก็บถาวรข้าม reboot (ออกสอบ)

```bash
mkdir -p /var/log/journal
# หรือแก้ /etc/systemd/journald.conf  →  Storage=persistent
systemctl restart systemd-journald
journalctl --list-boots
```

---

## 🧪 Lab 04

1. ตั้งค่า repo BaseOS และ AppStream ชี้ไปที่ serverb แล้วติดตั้ง `httpd`
2. เปิด `httpd` ทั้งตอนนี้และตอนบูต
3. ตั้ง default target เป็น `multi-user.target` แล้วเปลี่ยนกลับเป็น `graphical.target`
4. ตั้ง cron ให้ `natasha` เขียนวันที่ลง `/tmp/natasha-date.txt` ทุก 5 นาที
5. ตั้ง chrony ให้ซิงค์กับ serverb
6. ตั้ง tuned เป็นค่าที่แนะนำ
7. ทำให้ journal เก็บแบบถาวร
8. เพิ่ม flatpak remote ชื่อ `flathub` (ต้องมีอินเทอร์เน็ต) แล้วติดตั้ง `org.gnome.Calculator` แบบ system จากนั้นลบออก และลบ runtime ที่ไม่ได้ใช้
9. สร้าง timer `cleantmp.timer` ที่ลบไฟล์ `*.log` ใน `/tmp` ทุก 30 นาที และเริ่มทำงานครั้งแรก 5 นาทีหลังบูต
10. Reboot แล้วตรวจทุกข้อ

<details>
<summary>เฉลย Lab 04</summary>

```bash
cat > /etc/yum.repos.d/lab.repo <<'EOF'
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
dnf clean all && dnf repolist
dnf install -y httpd
systemctl enable --now httpd

systemctl set-default multi-user.target
systemctl set-default graphical.target

crontab -u natasha -e
# */5 * * * * date >> /tmp/natasha-date.txt

sed -i 's/^pool/#pool/' /etc/chrony.conf
echo "server 192.168.122.20 iburst" >> /etc/chrony.conf
systemctl enable --now chronyd ; systemctl restart chronyd
chronyc sources

tuned-adm profile $(tuned-adm recommend)

mkdir -p /var/log/journal && systemctl restart systemd-journald

dnf install -y flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.gnome.Calculator
flatpak list --app
flatpak uninstall -y org.gnome.Calculator
flatpak uninstall --unused -y

cat > /etc/systemd/system/cleantmp.service <<'EOF'
[Unit]
Description=Remove log files in /tmp

[Service]
Type=oneshot
ExecStart=/usr/bin/find /tmp -maxdepth 1 -name "*.log" -type f -delete
EOF
cat > /etc/systemd/system/cleantmp.timer <<'EOF'
[Unit]
Description=Clean /tmp every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now cleantmp.timer

reboot
# หลังบูต:
systemctl is-active httpd chronyd tuned ; tuned-adm active ; crontab -l -u natasha
systemctl list-timers cleantmp.timer
```
</details>
