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
> `http://content.example.com/rhel9/x86_64/dvd/BaseOS` และ
> `http://content.example.com/rhel9/x86_64/dvd/AppStream`"

**วิธีที่ 1 — เขียนไฟล์เอง**

```bash
vim /etc/yum.repos.d/local.repo
```

```ini
[BaseOS]
name=BaseOS
baseurl=http://content.example.com/rhel9/x86_64/dvd/BaseOS
enabled=1
gpgcheck=0

[AppStream]
name=AppStream
baseurl=http://content.example.com/rhel9/x86_64/dvd/AppStream
enabled=1
gpgcheck=0
```

> ถ้าโจทย์ให้ GPG key มา ให้ใช้ `gpgcheck=1` และ `gpgkey=http://.../RPM-GPG-KEY-redhat-release`

**วิธีที่ 2 — ใช้คำสั่ง**

```bash
dnf config-manager --add-repo http://content.example.com/rhel9/x86_64/dvd/BaseOS
dnf config-manager --add-repo http://content.example.com/rhel9/x86_64/dvd/AppStream
# แล้วเพิ่ม gpgcheck=0 ในไฟล์ที่สร้างขึ้นใน /etc/yum.repos.d/
```

ตรวจ: `dnf clean all && dnf repolist && dnf install -y tree`

*ใน Lab ของเรา ใช้ `http://192.168.122.20/repo/BaseOS` และ `.../AppStream` จาก serverb*

### Flatpak (มีใน objectives ของ RHEL 9 รุ่นหลัง)

```bash
flatpak remote-add --if-not-exists myrepo https://example.com/repo.flatpakrepo
flatpak remotes
flatpak search gedit
flatpak install myrepo org.gnome.gedit
flatpak list
```

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

### systemd timer (ทางเลือกของ cron)

```bash
# /etc/systemd/system/backup.service
[Unit]
Description=Backup /etc

[Service]
Type=oneshot
ExecStart=/usr/bin/tar czf /root/etc-backup.tar.gz /etc
```

```bash
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily backup

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now backup.timer
systemctl list-timers
```

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
8. Reboot แล้วตรวจทุกข้อ

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

reboot
# หลังบูต:
systemctl is-active httpd chronyd tuned ; tuned-adm active ; crontab -l -u natasha
```
</details>
