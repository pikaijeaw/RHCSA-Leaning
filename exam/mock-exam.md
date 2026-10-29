# ข้อสอบจำลอง RHCSA (EX200) — ชุดที่ 1

**เวลา:** 3 ชั่วโมง  **คะแนนเต็ม:** 300  **ผ่าน:** 210

### สภาพแวดล้อม
| เครื่อง | บทบาท |
|---|---|
| `servera` (192.168.122.10) | เครื่องหลัก (node1) |
| `serverb` (192.168.122.20) | repo, NFS, NTP server และเครื่องที่ 2 (node2) |

- Repo: `http://192.168.122.20/repo/BaseOS` และ `http://192.168.122.20/repo/AppStream`
- NFS: `192.168.122.20:/exports/home`
- ทุกการตั้งค่าต้อง **อยู่รอดหลัง reboot**
- SELinux ต้องอยู่ในโหมด **Enforcing**
- ห้ามดูเฉลยก่อนทำเสร็จ ใช้ได้แค่ `man` และ `--help`

---

## ส่วน A — ทำบน `serverb` (node2)

**A1. (15 คะแนน)** คุณไม่รู้ root password ของ `serverb` จง reset root password เป็น `trootent`

**A2. (15 คะแนน)** ตั้งค่า repository บน `serverb` ให้ใช้ BaseOS และ AppStream ตาม URL ข้างบน

**A3. (20 คะแนน)** ขยาย logical volume `vo` (ใน VG `myvol`) ให้มีขนาด **230 MiB** (ยอมรับได้ 217–243 MiB) โดยข้อมูลและ filesystem ไม่เสียหาย
> เตรียมก่อนทำ: `pvcreate /dev/vdb; vgcreate myvol /dev/vdb; lvcreate -n vo -L 180M myvol; mkfs.xfs /dev/myvol/vo; mkdir /reports; echo "/dev/myvol/vo /reports xfs defaults 0 0" >> /etc/fstab; mount -a`

**A4. (20 คะแนน)** เพิ่ม swap partition ขนาด **512 MiB** ให้เปิดใช้งานอัตโนมัติตอนบูต (ห้ามลบ swap ที่มีอยู่เดิม)

**A5. (20 คะแนน)** สร้าง LV ใหม่ตามเงื่อนไข
- ชื่อ LV `qa` อยู่ใน VG `qagroup`
- LV มีขนาด **60 extents** และ extent ของ VG มีขนาด **16 MiB**
- format เป็น `vfat`
- mount ถาวรที่ `/mnt/qa`

**A6. (10 คะแนน)** ตั้ง tuned profile ของ `serverb` เป็นค่าที่ระบบแนะนำ

---

## ส่วน B — ทำบน `servera` (node1)

**B1. (15 คะแนน)** ตั้งค่า network
- Hostname: `servera.lab.example.com`
- IP: `192.168.122.10/24`, Gateway: `192.168.122.1`, DNS: `192.168.122.1`

**B2. (10 คะแนน)** ตั้งค่า repository เหมือนข้อ A2

**B3. (20 คะแนน)** Web server ถูกตั้งให้ทำงานบน port **82** แต่ยังใช้งานไม่ได้ จงแก้ไขให้
- ไฟล์ HTML ทุกไฟล์ใน `/var/www/html` เข้าถึงได้ผ่าน port 82 จากเครื่องอื่น
- httpd เริ่มอัตโนมัติตอนบูต
> เตรียมก่อนทำ: `dnf install -y httpd; sed -i 's/^Listen 80/Listen 82/' /etc/httpd/conf/httpd.conf; echo exam > /root/file1; mv /root/file1 /var/www/html/`

**B4. (20 คะแนน)** สร้าง user และ group
- group `sysmgrs`
- user `natasha` มี `sysmgrs` เป็น secondary group
- user `harry` มี `sysmgrs` เป็น secondary group
- user `sarah` ไม่มี interactive shell และไม่อยู่ใน `sysmgrs`
- ทุกคนมี password `flectrag`

**B5. (15 คะแนน)** สร้าง directory `/home/managers`
- group owner เป็น `sysmgrs`
- สมาชิก `sysmgrs` อ่าน เขียน เข้าถึงได้ คนอื่นห้าม (ยกเว้น root)
- ไฟล์ที่สร้างข้างใน `/home/managers` ได้ group `sysmgrs` อัตโนมัติ

**B6. (10 คะแนน)** user `natasha` ต้องรันคำสั่ง `/usr/bin/echo hello` ทุกวันเวลา 14:23 และรัน `logger "EX200 in progress"` ทุก 2 นาที

**B7. (10 คะแนน)** ตั้งให้ servera เป็น NTP client ของ `serverb`

**B8. (20 คะแนน)** ตั้งค่า autofs
- `remoteuser1` มี UID `1501` และ home directory เป็น `/rhome/remoteuser1`
- `/rhome/remoteuser1` ต้องถูก mount อัตโนมัติจาก `192.168.122.20:/exports/home/remoteuser1`
- home directory ต้องอ่านเขียนได้

**B9. (15 คะแนน)** copy `/etc/fstab` ไปที่ `/var/tmp/fstab`
- owner และ group เป็น `root`
- ห้ามใครรันได้
- `natasha` อ่านและเขียนได้
- `harry` อ่านและเขียนไม่ได้
- คนอื่นทุกคนอ่านได้

**B10. (10 คะแนน)** สร้าง user `alex` ที่มี UID `3456` password `flectrag`

**B11. (10 คะแนน)** หาไฟล์ทุกไฟล์ที่เป็นของ user `harry` แล้ว copy ไปไว้ใน `/root/findfiles` (คง permission เดิม)
> เตรียมก่อนทำ: `touch /tmp/h1 /var/tmp/h2; chown harry /tmp/h1 /var/tmp/h2`

**B12. (10 คะแนน)** หาทุกบรรทัดในไฟล์ `/usr/share/dict/words` ที่มีคำว่า `ich` แล้วบันทึกลง `/root/lines` (ถ้าไม่มีไฟล์ให้ `dnf install -y words`)

**B13. (10 คะแนน)** สร้าง archive `/root/backup.tar.bz2` ที่เก็บ `/usr/local` บีบอัดด้วย bzip2

**B14. (15 คะแนน)** สร้าง script `/usr/local/bin/myusers`
- ถ้าไม่มี argument ให้พิมพ์ `Usage: myusers <shell>` และ exit 1
- ถ้ามี argument ให้พิมพ์ชื่อ user ทุกคนใน `/etc/passwd` ที่ใช้ shell นั้น เช่น `myusers /bin/bash`

**B15. (10 คะแนน)** ตั้งให้ password ของ user ที่สร้างใหม่หลังจากนี้หมดอายุภายใน 20 วัน และให้ group `sysmgrs` ใช้ `sudo` ได้โดยไม่ต้องใส่ password

---

### เมื่อทำเสร็จ
1. Reboot ทั้งสองเครื่อง
2. ตรวจด้วยตัวเองหรือรัน `exam/check-servera.sh` บน servera
3. ดู [เฉลย](solutions.md)
