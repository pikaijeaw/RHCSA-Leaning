# บทที่ 03 — Users, Groups และ Permissions

## 1. หลักการ: ใครเป็นเจ้าของ และใครทำอะไรได้

- ทุก user มี **UID** (root = 0, user ทั่วไปเริ่มที่ 1000)
- ทุก user มี **primary group** 1 กลุ่ม (ปกติชื่อเดียวกับ user) และมี **secondary group** ได้หลายกลุ่ม
- ทุกไฟล์มี **owner** (user) และ **group** และมีสิทธิ์ 3 ชุด: ของ owner, ของ group, ของคนอื่น (other)

### ไฟล์ที่เก็บข้อมูล user

| ไฟล์ | เก็บอะไร |
|---|---|
| `/etc/passwd` | `name:x:UID:GID:comment:home:shell` |
| `/etc/shadow` | password ที่เข้ารหัส + ข้อมูลการหมดอายุ |
| `/etc/group` | `group:x:GID:members` |
| `/etc/login.defs` | ค่าเริ่มต้นตอนสร้าง user (เช่น PASS_MAX_DAYS) |
| `/etc/skel/` | ไฟล์ตั้งต้นที่จะ copy ไปใส่ home ของ user ใหม่ |

---

## 2. จัดการ user และ group

```bash
# Group
groupadd sysadmins
groupadd -g 5000 devops            # กำหนด GID
groupmod -n ops devops             # เปลี่ยนชื่อ
groupdel ops

# User
useradd natasha                    # สร้าง user
useradd -u 2001 -G sysadmins harry # กำหนด UID และ secondary group
useradd -s /sbin/nologin sarah     # ห้าม login แบบ interactive
useradd -c "Web Admin" -d /web -m webadmin
passwd natasha                     # ตั้ง password (แบบโต้ตอบ)
echo "redhat" | passwd --stdin natasha   # ตั้ง password แบบไม่ต้องโต้ตอบ

usermod -aG sysadmins natasha      # เพิ่ม secondary group (-a สำคัญ! ไม่ใส่จะลบกลุ่มเดิม)
usermod -s /bin/bash sarah         # เปลี่ยน shell
usermod -L harry ; usermod -U harry   # lock / unlock
userdel -r harry                   # ลบพร้อม home

id natasha                         # ตรวจ UID, GID, groups
getent passwd natasha
```

> **ข้อควรระวัง:** `usermod -G group user` (ไม่มี `-a`) จะ **แทนที่** secondary group ทั้งหมด

### Password aging (chage)

```bash
chage -l natasha                 # ดูข้อมูล
chage -M 90 natasha              # password ใช้ได้สูงสุด 90 วัน
chage -m 7 natasha               # ต้องรอ 7 วันก่อนเปลี่ยนได้อีก
chage -W 7 natasha               # เตือนก่อนหมด 7 วัน
chage -d 0 natasha               # บังคับเปลี่ยน password ตอน login ครั้งถัดไป
chage -E 2026-12-31 natasha      # account หมดอายุวันที่กำหนด
```

> **แนวข้อสอบ:** "user ทุกคนที่สร้างใหม่ ต้องมี password หมดอายุภายใน 30 วัน"
> → แก้ `/etc/login.defs` : `PASS_MAX_DAYS 30` (มีผลกับ user ที่สร้าง **หลังจากนี้** เท่านั้น)

---

## 3. sudo

```bash
# วิธีที่ 1: เพิ่ม user เข้า group wheel (ได้สิทธิ์ sudo ทุกอย่าง)
usermod -aG wheel natasha

# วิธีที่ 2: สร้างไฟล์ใน /etc/sudoers.d/ (แนะนำ แก้ด้วย visudo เสมอ)
visudo -f /etc/sudoers.d/sysadmins
```

ตัวอย่างเนื้อหา:

```
# group sysadmins ใช้ sudo ได้ทุกคำสั่ง ไม่ต้องใส่ password
%sysadmins   ALL=(ALL)   NOPASSWD: ALL

# user harry รันได้แค่ useradd และ passwd
harry        ALL=(root)  /usr/sbin/useradd, /usr/bin/passwd
```

ตรวจด้วย `sudo -l -U harry`

---

## 4. Permission พื้นฐาน

```
-rwxr-x---. 1 harry sysadmins 120 Oct 1 10:00 script.sh
│└┬┘└┬┘└┬┘
│ │  │  └── other : ---  (ไม่มีสิทธิ์)
│ │  └───── group : r-x  (อ่าน + รัน)
│ └──────── owner : rwx  (ทุกอย่าง)
└────────── ประเภท: - ไฟล์, d directory, l link
```

| สิทธิ์ | ค่า | กับไฟล์ | กับ directory |
|---|---|---|---|
| r | 4 | อ่านเนื้อหา | `ls` ดูรายชื่อไฟล์ |
| w | 2 | แก้ไขเนื้อหา | สร้าง/ลบ/เปลี่ยนชื่อไฟล์ข้างใน |
| x | 1 | รันเป็นโปรแกรม | `cd` เข้าไปได้ |

```bash
chmod 750 script.sh          # rwx r-x ---
chmod u+x,g-w,o= file        # แบบสัญลักษณ์
chmod -R 770 /shared         # ทั้ง directory
chown harry file             # เปลี่ยน owner
chown harry:sysadmins file   # owner และ group
chgrp sysadmins file         # เปลี่ยนแค่ group
chown -R harry:harry /data
```

### umask — สิทธิ์เริ่มต้นตอนสร้างไฟล์

ค่าเริ่มต้น: ไฟล์ = 666, directory = 777 แล้วหักด้วย umask

| umask | ไฟล์ใหม่ | directory ใหม่ |
|---|---|---|
| 0022 (root) | 644 | 755 |
| 0002 (user) | 664 | 775 |
| 0077 | 600 | 700 |

```bash
umask              # ดูค่า
umask 027          # ตั้งชั่วคราว
echo "umask 027" >> /home/natasha/.bashrc   # ถาวรเฉพาะ user นี้
```

---

## 5. Special permissions (ออกสอบบ่อยมาก)

| ชื่อ | ค่า | ใช้กับ | ผล |
|---|---|---|---|
| **SUID** | 4000 | ไฟล์โปรแกรม | รันด้วยสิทธิ์ของ owner ไฟล์ (เช่น `/usr/bin/passwd`) |
| **SGID** | 2000 | directory | ไฟล์ที่สร้างข้างในจะได้ **group เดียวกับ directory** |
| **Sticky** | 1000 | directory | ลบได้เฉพาะไฟล์ของตัวเอง (เช่น `/tmp`) |

```bash
chmod u+s /usr/local/bin/prog   # SUID
chmod g+s /shared               # SGID
chmod o+t /shared               # Sticky
chmod 3770 /shared              # SGID + Sticky + rwxrwx---
ls -ld /shared                  # drwxrws--T  (s = SGID, T = sticky ที่ไม่มี x ของ other)
```

> **แนวข้อสอบคลาสสิก:** สร้าง directory `/common/admin` ที่
> - group owner เป็น `sysadmins`
> - สมาชิก `sysadmins` อ่าน เขียน เข้าถึงได้ คนอื่นห้ามเข้าถึง (ยกเว้น root)
> - ไฟล์ที่สร้างข้างในให้เป็น group `sysadmins` อัตโนมัติ
>
> ```bash
> mkdir -p /common/admin
> chgrp sysadmins /common/admin
> chmod 2770 /common/admin
> ```
>
> ตรวจ: `su - natasha -c "touch /common/admin/x" && ls -l /common/admin/x` ต้องเห็น group เป็น `sysadmins`

---

## 6. ACL — กำหนดสิทธิ์รายบุคคล

เมื่อ owner/group/other ไม่พอ เช่น "ให้ natasha อ่านเขียนได้ แต่ harry ห้ามแตะ"

```bash
setfacl -m u:natasha:rw /var/tmp/fstab     # ให้ natasha อ่านเขียน
setfacl -m u:harry:--- /var/tmp/fstab      # harry ห้ามทุกอย่าง
setfacl -m g:sysadmins:rx /data            # สิทธิ์ให้ group
setfacl -m d:g:sysadmins:rwx /data         # default ACL: ไฟล์ใหม่ใน /data ได้สิทธิ์นี้ด้วย
setfacl -x u:harry /var/tmp/fstab          # ลบ ACL ของ harry
setfacl -b /var/tmp/fstab                  # ลบ ACL ทั้งหมด
getfacl /var/tmp/fstab                     # ดู
```

ไฟล์ที่มี ACL จะเห็นเครื่องหมาย `+` ท้าย permission: `-rw-rw-r--+`

> **แนวข้อสอบ:** copy `/etc/fstab` ไป `/var/tmp/fstab`
> - owner เป็น root, group เป็น root
> - ทุกคนห้ามรัน
> - natasha อ่านและเขียนได้
> - harry ห้ามอ่านและห้ามเขียน
> - คนอื่นอ่านได้
>
> ```bash
> cp /etc/fstab /var/tmp/fstab
> chown root:root /var/tmp/fstab
> chmod 644 /var/tmp/fstab
> setfacl -m u:natasha:rw- /var/tmp/fstab
> setfacl -m u:harry:--- /var/tmp/fstab
> getfacl /var/tmp/fstab
> ```

---

## 🧪 Lab 03

1. สร้าง group `sysmgrs`
2. สร้าง user `natasha` และ `harry` ให้มี `sysmgrs` เป็น secondary group
3. สร้าง user `sarah` ที่ไม่สามารถ login shell ได้ และไม่อยู่ใน `sysmgrs`
4. ตั้ง password ทุกคนเป็น `flectrag`
5. user `alex` มี UID `3456`
6. group `sysmgrs` ใช้ `sudo` ได้ทุกคำสั่งโดยไม่ต้องใส่ password
7. สร้าง `/common/managers` ที่ group เป็น `sysmgrs`, สมาชิกทำได้ทุกอย่าง, คนอื่นห้ามเข้า, ไฟล์ใหม่ได้ group `sysmgrs`, และลบได้เฉพาะไฟล์ของตัวเอง
8. บังคับให้ `harry` เปลี่ยน password ตอน login ครั้งแรก

<details>
<summary>เฉลย Lab 03</summary>

```bash
groupadd sysmgrs
useradd -G sysmgrs natasha
useradd -G sysmgrs harry
useradd -s /sbin/nologin sarah
useradd -u 3456 alex
for u in natasha harry sarah alex; do echo flectrag | passwd --stdin $u; done

echo '%sysmgrs ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/sysmgrs
chmod 440 /etc/sudoers.d/sysmgrs
visudo -c                      # ตรวจ syntax

mkdir -p /common/managers
chgrp sysmgrs /common/managers
chmod 3770 /common/managers    # SGID(2) + sticky(1) + 770

chage -d 0 harry

# ตรวจ
id natasha ; id sarah ; id alex
su - natasha -c "sudo -n whoami"   # ต้องได้ root
ls -ld /common/managers            # drwxrws--T
```
</details>
