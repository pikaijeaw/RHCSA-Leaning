# RHCSA-Leaning — คู่มือเรียน RHCSA ฉบับภาษาไทย (เน้นลงมือทำ)

คู่มือนี้พาเรียน **RHCSA (Red Hat Certified System Administrator, รหัสสอบ EX200)** ตั้งแต่ศูนย์ แต่ละบทจะมี

- **หลักการ**: อธิบายว่าเรื่องนี้คืออะไร และทำงานอย่างไร
- **คำสั่งพร้อมตัวอย่าง**: ใช้ได้จริงบน RHEL 9 / Rocky / AlmaLinux 9
- **Lab**: โจทย์ให้ลงมือทำเอง พร้อมวิธีตรวจว่าทำถูกหรือไม่
- **แนวข้อสอบ**: โจทย์แบบที่มักเจอในห้องสอบ

---

## 1. RHCSA คืออะไร

| หัวข้อ | รายละเอียด |
|---|---|
| ชื่อเต็ม | Red Hat Certified System Administrator |
| รหัสสอบ | **EX200** |
| รูปแบบ | **ข้อสอบปฏิบัติ 100%** ไม่มีข้อปรนัย ต้องลงมือตั้งค่าเครื่องจริง (VM) |
| เวลา | ประมาณ 2.5–3 ชั่วโมง |
| คะแนนผ่าน | 210 / 300 (70%) |
| เวอร์ชันที่สอบ | RHEL 9 (RHEL 10 มีเนื้อหาคล้ายกันมาก ให้ตรวจ objectives ล่าสุดก่อนสอบเสมอ) |
| อายุใบรับรอง | 3 ปี |

### สิ่งที่ต้องรู้เกี่ยวกับห้องสอบ
1. **ไม่มีอินเทอร์เน็ต** ใช้ได้แค่ `man`, `--help` และ `/usr/share/doc` ดังนั้นต้องฝึกหาคำตอบจาก man page ให้คล่อง
2. **ทุกอย่างต้องอยู่หลัง reboot** ผู้ตรวจจะ reboot เครื่องก่อนตรวจ ถ้า mount, service หรือ network ไม่อยู่ถาวร = ได้ 0 ในข้อนั้น
3. **มักมี 2 เครื่อง** (เช่น `node1` / `node2`) และบางเครื่องต้องเริ่มด้วยการ **reset root password**
4. **ข้อหนึ่งพังอาจลากข้ออื่นพังตาม** เช่น เขียน `/etc/fstab` ผิดจนเครื่องบูตไม่ขึ้น ก็จะเสียทุกข้อ

---

## 2. Roadmap การเรียน (แนะนำ 6–8 สัปดาห์)

| สัปดาห์ | บท | หัวข้อ |
|---|---|---|
| 0 | [00 - เตรียม Lab](docs/00-lab-setup.md) | ติดตั้ง VM 2 เครื่องเพื่อฝึก |
| 1 | [01 - เครื่องมือพื้นฐาน](docs/01-essential-tools.md) | shell, ไฟล์, redirect, grep, find, tar, link, man |
| 1 | [02 - Shell Script](docs/02-shell-scripting.md) | ตัวแปร, if, for, argument, exit code |
| 2 | [03 - Users, Groups, Permissions](docs/03-users-permissions.md) | useradd, sudo, chmod, SGID, sticky, ACL |
| 3 | [04 - Software และ Services](docs/04-software-services.md) | dnf, repo, systemd, cron, at, timer, tuned, chrony, log |
| 4 | [05 - Storage](docs/05-storage.md) | partition, LVM, swap, fstab, NFS, autofs |
| 5 | [06 - Networking และ SSH](docs/06-networking.md) | nmcli, hostname, DNS, ssh key |
| 5 | [07 - Security: firewalld และ SELinux](docs/07-security.md) | firewall-cmd, context, boolean, port |
| 6 | [08 - Boot และ Troubleshooting](docs/08-boot-troubleshooting.md) | reset root password, target, GRUB |
| 6 | [09 - Containers (Podman)](docs/09-containers.md) | podman, rootless, systemd service |
| 7–8 | [ข้อสอบจำลอง](exam/mock-exam.md) / [เฉลย](exam/solutions.md) | ทำจับเวลา 3 ชั่วโมง |

มี [Cheat Sheet](docs/cheatsheet.md) สรุปคำสั่งสำคัญไว้ทบทวนก่อนสอบด้วย

---

## 3. หัวข้อที่ "ออกแน่ ๆ" (ควรทำได้โดยไม่ต้องคิด)

1. Reset root password ผ่าน `rd.break` / `init=/bin/bash`
2. ตั้งค่า network แบบ static ด้วย `nmcli` + hostname
3. ตั้งค่า repository ของ `dnf` จาก URL ที่โจทย์ให้
4. สร้าง user/group ตามเงื่อนไข (UID, secondary group, shell `nologin`, password หมดอายุ)
5. ทำ shared directory ด้วย **SGID** + permission ของกลุ่ม
6. ตั้ง cron job ให้ user คนหนึ่ง
7. สร้าง LVM (VG ที่กำหนด PE size, LV ขนาดกำหนด), format, mount ถาวร
8. ขยาย LV พร้อม filesystem (`lvextend -r`)
9. เพิ่ม swap ถาวร
10. autofs mount home directory จาก NFS
11. SELinux: แก้ให้ web server ทำงานบน port ที่ไม่ใช่มาตรฐาน + แก้ context
12. firewalld เปิด service/port แบบถาวร
13. ตั้ง NTP client (`chrony`)
14. ตั้ง tuned profile ที่แนะนำ
15. หาไฟล์ของ user แล้ว copy ไปเก็บ / grep ข้อความลงไฟล์ / สร้าง tar archive
16. เขียน shell script ง่าย ๆ
17. รัน container แบบ rootless และให้ start อัตโนมัติด้วย systemd (ถ้ายังอยู่ใน objectives เวอร์ชันที่สอบ)

---

## 4. เคล็ดลับการสอบ

- **อ่านโจทย์ทั้งหมดก่อน** ทำข้อที่ง่ายและไม่ขึ้นกับข้ออื่นก่อน
- หลังแก้ `/etc/fstab` ให้รัน `mount -a` และ `findmnt --verify` ทุกครั้ง
- **Reboot เองระหว่างสอบ** อย่างน้อย 1–2 ครั้ง เพื่อเช็กว่าทุกอย่างยังอยู่
- ใช้ `--permanent` กับ firewalld แล้ว `--reload` และ `systemctl enable --now` กับ service เสมอ
- อย่าปิด SELinux (`setenforce 0`) เพื่อแก้ปัญหา ผู้ตรวจเช็กว่าต้องเป็น `Enforcing`
- จำวิธีหาข้อมูลเองได้: `man -k keyword`, `man 5 fstab`, `man nmcli-examples`, `man semanage-fcontext` (มีตัวอย่างอยู่ท้าย man page)

---

## 5. แหล่งข้อมูลเพิ่มเติม

- Exam objectives อย่างเป็นทางการ: https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam
- RHEL Documentation: https://docs.redhat.com/
- Red Hat Developer Subscription (ใช้ RHEL ฟรีสำหรับฝึก): https://developers.redhat.com/
