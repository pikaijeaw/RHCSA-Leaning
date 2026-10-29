# บทที่ 07 — Security: firewalld และ SELinux

## ส่วนที่ 1: firewalld

### หลักการ

firewalld กรอง traffic ขาเข้าโดยแบ่งเป็น **zone** แต่ละ zone มีรายการ **service** และ **port** ที่อนุญาต การ์ดแลนแต่ละใบอยู่ใน zone ใด zone หนึ่ง (ปกติคือ `public`)

มีการตั้งค่า 2 ชุด:
- **runtime** : มีผลทันที แต่หายหลัง reload/reboot
- **permanent** : บันทึกถาวร แต่ต้อง `--reload` ก่อนถึงจะมีผล

> **สูตรห้องสอบ:** ใช้ `--permanent` เสมอ แล้วตามด้วย `firewall-cmd --reload`

```bash
systemctl enable --now firewalld
firewall-cmd --state
firewall-cmd --get-default-zone
firewall-cmd --get-active-zones
firewall-cmd --list-all                      # ดูกฎของ zone ปัจจุบัน
firewall-cmd --get-services                  # ชื่อ service ที่รู้จัก

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service={http,https}
firewall-cmd --permanent --add-port=82/tcp
firewall-cmd --permanent --remove-service=cockpit
firewall-cmd --permanent --zone=internal --add-source=10.0.0.0/24
firewall-cmd --reload
firewall-cmd --list-all
```

### Rich rule (ใช้เมื่อต้องการเงื่อนไขละเอียด)

```bash
# อนุญาต ssh เฉพาะจาก 192.168.122.0/24
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.122.0/24 service name=ssh accept'
# บล็อกเครื่องเดียว
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.122.99 reject'
firewall-cmd --reload
```

`man firewalld.richlanguage` มีตัวอย่างอยู่ท้าย page

---

## ส่วนที่ 2: SELinux (หัวข้อที่คนสอบตกบ่อยที่สุด)

### หลักการ

permission ปกติ (rwx) ตอบคำถาม "**user คนนี้** ทำอะไรได้"
SELinux ตอบคำถาม "**process นี้** แตะ **ไฟล์/port นี้** ได้ไหม"

ทุก process และทุกไฟล์มี **label (context)** หน้าตาแบบนี้:

```
system_u:object_r:httpd_sys_content_t:s0
  user   :  role  :      type          : level
```

สำหรับ RHCSA สนใจแค่ส่วน **type** เช่น process `httpd` มี type `httpd_t` จะอ่านได้เฉพาะไฟล์ที่มี type `httpd_sys_content_t` ถ้าไฟล์ type ผิด → ถูกปฏิเสธ (ถึงแม้ chmod 777 ก็ตาม)

### โหมดของ SELinux

| โหมด | ความหมาย |
|---|---|
| **Enforcing** | บังคับใช้ ปฏิเสธจริง (ต้องเป็นโหมดนี้ในห้องสอบ) |
| Permissive | ไม่บล็อก แค่เขียน log |
| Disabled | ปิดทั้งหมด (ห้ามทำ) |

```bash
getenforce
setenforce 1                  # Enforcing ชั่วคราว (0 = Permissive)
vim /etc/selinux/config       # SELINUX=enforcing  (ถาวร)
sestatus
```

> **แนวข้อสอบ:** "เครื่องนี้ต้องอยู่ในโหมด enforcing หลัง reboot" → ตรวจ `/etc/selinux/config` ด้วย
> ถ้าเดิมเป็น `disabled` แล้วเปลี่ยนเป็น `enforcing` การบูตครั้งแรกจะใช้เวลานานเพราะต้อง relabel ทั้งเครื่อง

### ดู context

```bash
ls -Z /var/www/html           # ของไฟล์
ps -eZ | grep httpd           # ของ process
ss -tlnpZ                     # ของ port
```

### 1) แก้ context ของไฟล์

```bash
# วิธีที่ถูก: กำหนดกฎถาวร แล้ว apply
semanage fcontext -a -t httpd_sys_content_t "/web(/.*)?"
restorecon -Rv /web

# ดูกฎ
semanage fcontext -l | grep /web
```

> `chcon -t httpd_sys_content_t /web` ก็เปลี่ยนได้ **แต่ไม่ถาวร** ถ้ามีการ relabel หรือ `restorecon` จะกลับเป็นค่าเดิม ในห้องสอบให้ใช้ `semanage fcontext` + `restorecon`

**ทำไม mv แล้วเว็บพัง?**
`cp` → ไฟล์ใหม่ได้ context ของปลายทาง (ถูก)
`mv` → ไฟล์ **พา context เดิมไปด้วย** (เช่น `user_home_t`) → httpd อ่านไม่ได้
แก้: `restorecon -Rv /var/www/html`

### 2) อนุญาต port ที่ไม่ใช่มาตรฐาน

```bash
semanage port -l | grep http_port_t
# http_port_t  tcp  80, 81, 443, 488, 8008, 8009, 8443, 9000

semanage port -a -t http_port_t -p tcp 82
semanage port -a -t ssh_port_t  -p tcp 2222
```

### 3) Boolean — สวิตช์เปิด/ปิดความสามารถ

```bash
getsebool -a | grep httpd
getsebool httpd_enable_homedirs
setsebool -P httpd_enable_homedirs on     # -P = ถาวร (ห้ามลืม)
semanage boolean -l | grep httpd          # มีคำอธิบาย
```

### 4) วิเคราะห์ปัญหา

```bash
grep AVC /var/log/audit/audit.log | tail
ausearch -m AVC -ts recent
journalctl -t setroubleshoot
sealert -a /var/log/audit/audit.log       # อธิบายพร้อมวิธีแก้ (package setroubleshoot-server)
```

ติดตั้งเครื่องมือ: `dnf install -y policycoreutils-python-utils setroubleshoot-server`

---

## 🔥 แนวข้อสอบคลาสสิก: เว็บ port 82 ใช้งานไม่ได้

> "web server บนเครื่องนี้ตั้งค่าให้ทำงานที่ port 82 และเอกสารอยู่ที่ `/var/www/html` แต่ตอนนี้ใช้งานไม่ได้ จงแก้ไขให้
> - เข้าถึงไฟล์ทั้งหมดใน `/var/www/html` ได้จากเครื่องอื่นที่ port 82
> - httpd ต้องเปิดอัตโนมัติตอนบูต
> - ห้ามปิด SELinux"

```bash
# 1. ดูอาการ
systemctl status httpd            # อาจเห็น "Permission denied: could not bind to port 82"
grep -i ^Listen /etc/httpd/conf/httpd.conf    # Listen 82

# 2. อนุญาต port 82 ใน SELinux
semanage port -a -t http_port_t -p tcp 82

# 3. แก้ context ของไฟล์ (ไฟล์อาจถูก mv มาจากที่อื่น)
ls -Z /var/www/html
restorecon -Rv /var/www/html

# 4. เปิด firewall
firewall-cmd --permanent --add-port=82/tcp
firewall-cmd --reload

# 5. เปิด service
systemctl enable --now httpd
systemctl restart httpd

# 6. ทดสอบ
curl http://localhost:82/
curl http://servera:82/file1      # จากเครื่องอื่น
```

---

## 🧪 Lab 07

เตรียม: บน servera ติดตั้ง httpd แล้วจำลองปัญหา

```bash
dnf install -y httpd policycoreutils-python-utils
sed -i 's/^Listen 80/Listen 82/' /etc/httpd/conf/httpd.conf
echo "Hello from home" > /root/index.html
mv /root/index.html /var/www/html/index.html     # context ผิด (admin_home_t)
```

โจทย์:
1. ทำให้ `curl http://servera:82/` จาก serverb แสดง `Hello from home`
2. httpd เปิดอัตโนมัติตอนบูต
3. สร้าง `/webdata/test.html` แล้วตั้งให้ SELinux ยอมให้ httpd อ่าน (ถาวร)
4. เปิด boolean ที่ให้ httpd เชื่อมต่อ network ภายนอกได้ (`httpd_can_network_connect`) แบบถาวร
5. ตั้ง firewall ให้ ssh เข้าได้เฉพาะจาก `192.168.122.0/24`

<details>
<summary>เฉลย Lab 07</summary>

```bash
semanage port -a -t http_port_t -p tcp 82
restorecon -Rv /var/www/html
firewall-cmd --permanent --add-port=82/tcp
systemctl enable --now httpd ; systemctl restart httpd

mkdir /webdata ; echo test > /webdata/test.html
semanage fcontext -a -t httpd_sys_content_t "/webdata(/.*)?"
restorecon -Rv /webdata

setsebool -P httpd_can_network_connect on

firewall-cmd --permanent --remove-service=ssh
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.122.0/24 service name=ssh accept'
firewall-cmd --reload

# ตรวจจาก serverb
curl http://servera:82/
```
</details>
