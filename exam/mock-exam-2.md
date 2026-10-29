# ข้อสอบจำลอง RHCSA (EX200, RHEL 10) — ชุดที่ 2

**เวลา:** 3 ชั่วโมง  **คะแนนเต็ม:** 300  **ผ่าน:** 210

ชุดนี้ยากกว่าชุดที่ 1 เล็กน้อย บางข้อมีปัญหาซ่อนอยู่ที่ต้องหาเอง และมีหลายข้อที่ใช้ทักษะซึ่งชุดแรกไม่ได้ถาม (ACL แบบ default, IPv6, autofs แบบ wildcard, NFS ใน fstab, `at`, การ kill process, Flatpak แบบ user)

### สภาพแวดล้อม
| เครื่อง | บทบาท |
|---|---|
| `servera` (192.168.122.10) | เครื่องหลัก (node1) |
| `serverb` (192.168.122.20) | repo, NFS, NTP server และเครื่องที่ 2 (node2) |

- Repo: `http://192.168.122.20/repo/BaseOS` และ `http://192.168.122.20/repo/AppStream`
- NFS: `192.168.122.20:/exports/home` และ `192.168.122.20:/exports/share`
- ทุกการตั้งค่าต้อง **อยู่รอดหลัง reboot** และ SELinux ต้องเป็น **Enforcing**
- ใช้ได้แค่ `man`, `--help` และ `/usr/share/doc`

### ก่อนเริ่ม (ไม่นับเวลา)
1. ย้อนทั้งสองเครื่องกลับไปที่ snapshot `clean` (ดิสก์ `vdb` และ `vdc` ต้องว่าง)
2. ทำบน **serverb** ในฐานะ root:
   ```bash
   chown 1501 /exports/home/remoteuser1
   chown 1502 /exports/home/remoteuser2
   useradd amy && echo redhat | passwd --stdin amy      # ใช้ในข้อ B14
   ```
3. ทำบน **servera** ในฐานะ root:
   ```bash
   bash exam/setup-exam2.sh
   ```
   สคริปต์นี้จะสร้างปัญหาไว้ให้แก้ **อย่าเปิดอ่านสคริปต์ก่อนทำข้อสอบ**

---

## ส่วน A — ทำบน `serverb` (node2)

**A1. (15 คะแนน)** ตั้ง root password ของ `serverb` เป็น `redhat2` โดยถือว่าคุณไม่รู้ password เดิม (ให้ใช้วิธี `init=/bin/bash` ซึ่งชุดที่ 1 ไม่ได้ใช้)

**A2. (10 คะแนน)** ตั้งค่า repository BaseOS และ AppStream ตาม URL ข้างบน

**A3. (20 คะแนน)** สร้าง storage ตามเงื่อนไข
- VG ชื่อ `datavg` บน `/dev/vdb` โดยมี PE size **8 MiB**
- LV ชื่อ `datalv` ขนาด **50 extents**
- format เป็น `ext4` และตั้ง label เป็น `DATA`
- mount ถาวรที่ `/data` **โดยอ้างอิงด้วย label** (ห้ามใช้ UUID หรือชื่อ device)

**A4. (15 คะแนน)** ขยาย `datalv` ให้มีขนาด **600 MiB** (ยอมรับได้ 570–630 MiB) โดยข้อมูลใน `/data` ไม่หาย
> ก่อนขยาย ให้สร้างไฟล์ `echo keep > /data/keep.txt` ไว้ เพื่อตรวจว่าข้อมูลยังอยู่

**A5. (15 คะแนน)** สร้าง swap จาก LV ชื่อ `swaplv` ขนาด **256 MiB** ใน VG `datavg` และให้เปิดใช้งานทุกครั้งที่บูต

**A6. (10 คะแนน)**
- ตั้งให้ `serverb` บูตเข้าโหมดข้อความ (ไม่มี GUI) เป็นค่าเริ่มต้น
- ทำให้ systemd journal เก็บถาวรข้าม reboot

**A7. (10 คะแนน)** ลบ kernel argument `rhgb` และ `quiet` ออกจาก **kernel ทุกตัว** แบบถาวร เพื่อให้เห็นข้อความตอนบูต

---

## ส่วน B — ทำบน `servera` (node1)

**B1. (15 คะแนน)** ตั้งค่า network แบบถาวร
- Hostname: `servera.lab.example.com`
- IPv4: `192.168.122.10/24`, Gateway: `192.168.122.1`, DNS: `192.168.122.1`
- IPv6: `fd00:122::10/64` (ตั้งแบบ manual)

**B2. (5 คะแนน)** ตั้งค่า repository เหมือนข้อ A2

**B3. (20 คะแนน)** Web server บนเครื่องนี้ถูกตั้งค่าไว้แล้วให้ใช้ DocumentRoot เป็น `/srv/web` แต่ยังใช้งานไม่ได้ จงแก้ไขให้
- เปิด `http://servera/` จากเครื่องอื่นแล้วเห็นหน้าเว็บใน `/srv/web/index.html`
- httpd เริ่มอัตโนมัติตอนบูต
- ห้ามย้ายไฟล์ออกจาก `/srv/web` และห้ามเปลี่ยน DocumentRoot

**B4. (15 คะแนน)** สร้าง user และ group
- group `devops` มี GID `4000`
- user `amy` มี UID `2001` และมี `devops` เป็น secondary group
- user `bob` มี `devops` เป็น secondary group
- user `carl` ไม่มี interactive shell
- ทุกคนมี password `redhat`
- password ของ `amy` ต้องเปลี่ยนทุก 60 วัน และระบบเตือนล่วงหน้า 5 วัน
- account ของ `bob` หมดอายุวันที่ `2027-12-31`

**B5. (10 คะแนน)** สิทธิ์ sudo
- `amy` ใช้ sudo ได้ทุกคำสั่ง **แต่ต้องใส่ password**
- `bob` ใช้ sudo ได้เฉพาะ `/usr/bin/systemctl` และ `/usr/bin/journalctl` เท่านั้น

**B6. (10 คะแนน)** สร้าง directory `/srv/devops`
- group owner เป็น `devops`
- สมาชิก `devops` อ่าน เขียน เข้าถึงได้ คนอื่นห้าม (ยกเว้น root)
- ไฟล์ที่สร้างข้างในได้ group `devops` อัตโนมัติ
- สมาชิกลบได้เฉพาะไฟล์ของตัวเอง

**B7. (10 คะแนน)** สร้าง directory `/srv/reports` ที่เป็นของ `root:root` สิทธิ์ `755`
- `amy` อ่าน เขียน เข้าถึงได้ ทั้งตัว directory และ **ไฟล์ที่จะสร้างขึ้นใหม่ในอนาคต**
- `carl` อ่านได้อย่างเดียว ทั้งตัว directory และไฟล์ที่จะสร้างขึ้นใหม่ในอนาคต

**B8. (5 คะแนน)** ไฟล์ใหม่ที่ `amy` สร้างต้องมีสิทธิ์ `640` และ directory ใหม่ต้องมีสิทธิ์ `750` (มีผลเฉพาะ amy และถาวร)

**B9. (10 คะแนน)** mount `192.168.122.20:/exports/share` ที่ `/mnt/share` แบบ **อ่านอย่างเดียว** และ mount อัตโนมัติตอนบูต (ใช้ `/etc/fstab` ห้ามใช้ autofs)

**B10. (15 คะแนน)** ตั้งค่า autofs
- user `remoteuser1` (UID `1501`) และ `remoteuser2` (UID `1502`) มี home directory อยู่ที่ `/netusers/<ชื่อ user>`
- `/netusers/<ชื่อ user>` ต้อง mount อัตโนมัติจาก `192.168.122.20:/exports/home/<ชื่อ user>` แบบอ่านเขียนได้
- ต้องใช้ **map บรรทัดเดียว** ที่รองรับ user ทุกคน (ไม่เขียนแยกรายคน)

**B11. (5 คะแนน)** ในนามของ `amy` ตั้งงานแบบ **ครั้งเดียว** ให้รัน `touch /tmp/amy-at` เวลา 23:30

**B12. (15 คะแนน)** สร้าง systemd timer ชื่อ `uptimelog.timer`
- ต่อท้ายผลของคำสั่ง `uptime` ลงไฟล์ `/var/log/uptime.log`
- รันครั้งแรก **2 นาทีหลังบูต** แล้วรันซ้ำ **ทุก 10 นาที** นับจากครั้งล่าสุด
- ต้องทำงานหลัง reboot

**B13. (10 คะแนน)** Flatpak
- ให้ `amy` เพิ่ม remote `flathub` (`https://dl.flathub.org/repo/flathub.flatpakrepo`) **เฉพาะของตัวเอง**
- ติดตั้ง `org.gnome.Calculator` ให้ใช้ได้ **เฉพาะ amy** (user อื่นต้องไม่เห็นแอปนี้)

**B14. (10 คะแนน)** SSH
- root ต้อง ssh เข้า `servera` ไม่ได้
- `amy` บน servera ต้อง ssh ไปเป็น `amy@serverb` ได้โดยไม่ต้องใส่ password

**B15. (10 คะแนน)** Firewall (ถาวร)
- อนุญาต service `https`
- ปฏิเสธทุก connection จากเครื่อง `192.168.122.99`

**B16. (10 คะแนน)** หาไฟล์ทุกไฟล์ใน `/usr/share` ที่มีขนาดใหญ่กว่า **3 MiB** แล้วบันทึก path แบบเต็มลงไฟล์ `/root/bigfiles.txt` (บรรทัดละไฟล์ ห้ามมีข้อความ error ในไฟล์)

**B17. (10 คะแนน)**
- สร้าง archive `/root/sysconfig.tar.xz` จาก `/etc/sysconfig` บีบอัดด้วย **xz**
- แตก archive นั้นไว้ที่ `/root/restore` (ต้องได้ `/root/restore/etc/sysconfig/...`)

**B18. (15 คะแนน)** สร้าง script `/usr/local/bin/mkusers`
- ถ้าไม่มี argument ให้พิมพ์ `Usage: mkusers <file>` และ exit 1
- ถ้าไฟล์ที่ระบุไม่มีอยู่ ให้พิมพ์ `File not found` และ exit 2
- ถ้าไฟล์มีอยู่ ให้สร้าง user ตามชื่อในไฟล์ (บรรทัดละชื่อ) โดยใช้ shell `/sbin/nologin` ข้ามบรรทัดว่างและข้าม user ที่มีอยู่แล้ว และจบด้วย exit 0

**B19. (5 คะแนน)**
- มี process หนึ่งกิน CPU สูงผิดปกติ จงหาและหยุดมัน (โดยไม่ reboot)
- ตั้ง tuned profile เป็น `throughput-performance`

---

### เมื่อทำเสร็จ
1. Reboot ทั้งสองเครื่อง
2. รันสคริปต์ตรวจ:
   ```bash
   bash exam/check-exam2-serverb.sh    # บน serverb
   bash exam/check-exam2-servera.sh    # บน servera
   ```
3. ดู [เฉลยชุดที่ 2](solutions-2.md)
