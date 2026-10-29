# บทที่ 05 — Storage: Partition, LVM, Swap, NFS, autofs

บทนี้มีคะแนนเยอะที่สุด และ **อันตรายที่สุด** ถ้า `/etc/fstab` ผิด เครื่องจะบูตไม่ขึ้น

## 1. หลักการ: จากดิสก์ไปจนถึงโฟลเดอร์ที่ใช้งาน

```
 ดิสก์จริง        Partition          Filesystem       Mount point
 /dev/vdb   →   /dev/vdb1   →   format เป็น xfs   →   /data
```

แบบ LVM จะมีชั้นเพิ่มตรงกลาง ทำให้ **ขยาย/ย่อขนาดได้ง่าย**

```
 /dev/vdb1  ┐                                  ┌→ LV: lv_data (2G) → xfs → /data
 /dev/vdc1  ┼→ PV → VG: vg_data (รวมพื้นที่) ──┤
 /dev/vdd   ┘                                  └→ LV: lv_web  (1G) → ext4 → /web
  Physical Volume     Volume Group                 Logical Volume
```

```bash
lsblk                     # ดูดิสก์และ partition ทั้งหมด (ใช้บ่อยที่สุด)
lsblk -f                  # ดู filesystem และ UUID
blkid                     # UUID ของทุก device
df -hT                    # พื้นที่ของ filesystem ที่ mount อยู่
```

---

## 2. Partition

ตาราง partition มี 2 แบบ:
- **MBR (msdos)**: primary ได้สูงสุด 4 ตัว (หรือ 3 primary + 1 extended แล้วแบ่ง logical ต่อ), ดิสก์สูงสุด 2 TB
- **GPT**: ได้ 128 partition, รองรับดิสก์ขนาดใหญ่ (แนะนำ)

### ใช้ fdisk (แบบโต้ตอบ)

```bash
fdisk /dev/vdb
  g       # สร้างตาราง GPT (หรือ o สำหรับ MBR)
  n       # partition ใหม่ → Enter (เลข) → Enter (เริ่ม) → +1G (ขนาด)
  t       # เปลี่ยนชนิด: 8e/lvm = Linux LVM, 82/swap = Linux swap
  p       # ดูผล
  w       # บันทึก
partprobe /dev/vdb    # ให้ kernel รู้จัก partition ใหม่
```

### ใช้ parted (แบบคำสั่งเดียว เหมาะกับ script)

```bash
parted /dev/vdb mklabel gpt
parted /dev/vdb mkpart data xfs 1MiB 1025MiB
parted /dev/vdb mkpart lvmpart 1025MiB 3073MiB
parted /dev/vdb set 2 lvm on
parted /dev/vdb print
```

### Format และ Mount

```bash
mkfs.xfs /dev/vdb1           # xfs (ค่าเริ่มต้นของ RHEL, ขยายได้ ย่อไม่ได้)
mkfs.ext4 /dev/vdb1          # ext4 (ขยายและย่อได้)
mkfs.vfat /dev/vdb1          # vfat

mkdir /data
mount /dev/vdb1 /data        # mount ชั่วคราว (หายหลัง reboot)
umount /data
```

---

## 3. /etc/fstab — Mount ถาวร

รูปแบบ: `device  mountpoint  type  options  dump  fsck`

```bash
blkid /dev/vdb1
# /dev/vdb1: UUID="3c6b...-..." TYPE="xfs"
vim /etc/fstab
```

```
UUID=3c6b1f2a-...   /data    xfs    defaults   0 0
/dev/vg_data/lv_web /web     ext4   defaults   0 0
UUID=9a8b...        swap     swap   defaults   0 0
LABEL=backup        /backup  xfs    defaults   0 0
```

> **ใช้ UUID แทน `/dev/vdb1`** เพราะชื่อ device อาจเปลี่ยนหลัง reboot (ยกเว้น LV ที่ใช้ `/dev/vg/lv` ได้ปลอดภัย)

**หลังแก้ fstab ทุกครั้ง ต้องทำ:**

```bash
systemctl daemon-reload
mount -a                  # ถ้า error ต้องแก้ก่อน reboot!
findmnt --verify          # ตรวจ syntax ของ fstab
df -h
```

ตั้ง label: `xfs_admin -L backup /dev/vdb1` หรือ `e2label /dev/vdb1 backup`

---

## 4. LVM (หัวใจของบทนี้)

```bash
# 1) สร้าง PV
pvcreate /dev/vdb2 /dev/vdc
pvs ; pvdisplay

# 2) สร้าง VG
vgcreate vg_data /dev/vdb2 /dev/vdc
vgcreate -s 16M vg_exam /dev/vdb2     # กำหนด PE size = 16 MB (ออกสอบบ่อย!)
vgs ; vgdisplay vg_exam

# 3) สร้าง LV
lvcreate -n lv_data -L 500M vg_data   # กำหนดขนาด
lvcreate -n lv_exam -l 50 vg_exam     # กำหนดเป็นจำนวน extent (50 × 16M = 800M)
lvcreate -n lv_rest -l 100%FREE vg_data
lvs ; lvdisplay

# 4) Format + mount ถาวร
mkfs.xfs /dev/vg_data/lv_data
mkdir /mnt/data
echo "/dev/vg_data/lv_data /mnt/data xfs defaults 0 0" >> /etc/fstab
mount -a
```

> **`-L` (ตัวใหญ่) = ขนาด**, **`-l` (ตัวเล็ก) = จำนวน extent** สับสนบ่อยมาก

### ขยาย LV (ออกสอบแทบทุกครั้ง)

> **แนวข้อสอบ:** "ขยาย logical volume `vo` ให้มีขนาด 300 MB โดยข้อมูลไม่หาย (ยอมรับได้ระหว่าง 270–330 MB)"

```bash
lvextend -r -L 300M /dev/vg/vo        # -r = ขยาย filesystem ให้ด้วย (สำคัญ!)
lvextend -r -L +200M /dev/vg/vo       # เพิ่มจากเดิมอีก 200M
lvextend -r -l +100%FREE /dev/vg/vo   # ใช้พื้นที่ว่างทั้งหมด
df -h                                 # ตรวจว่าขนาดเปลี่ยนจริง
```

ถ้าลืม `-r`: xfs ใช้ `xfs_growfs /mountpoint`, ext4 ใช้ `resize2fs /dev/vg/vo`

ถ้า VG ไม่พอ ต้องเพิ่ม PV เข้า VG ก่อน:

```bash
pvcreate /dev/vdd
vgextend vg /dev/vdd
```

### ย่อ / ลบ

```bash
lvreduce -r -L 200M /dev/vg/lv_ext4   # ย่อได้เฉพาะ ext4 (xfs ย่อไม่ได้)
umount /mnt/data ; lvremove /dev/vg_data/lv_data
vgremove vg_data ; pvremove /dev/vdb2
```

---

## 5. Swap

```bash
# สร้าง partition ขนาด 512M ชนิด swap ก่อน (fdisk: t → swap) แล้ว:
mkswap /dev/vdb3
swapon /dev/vdb3
swapon --show ; free -h
blkid /dev/vdb3
echo "UUID=<uuid> swap swap defaults 0 0" >> /etc/fstab
swapoff -a && swapon -a     # ทดสอบ fstab
```

Swap บน LV ก็ทำได้:

```bash
lvcreate -n lv_swap -L 512M vg_data
mkswap /dev/vg_data/lv_swap
echo "/dev/vg_data/lv_swap swap swap defaults 0 0" >> /etc/fstab
swapon -a
```

> **ข้อควรระวัง:** ถ้าโจทย์บอกว่า "อย่าแตะ swap เดิม" ต้องเพิ่ม swap ใหม่โดยไม่ลบของเก่า

---

## 6. NFS client

```bash
dnf install -y nfs-utils
showmount -e serverb            # ดูว่า server แชร์อะไร
mkdir /mnt/share
mount -t nfs serverb:/exports/share /mnt/share
# ถาวร:
echo "serverb:/exports/share /mnt/share nfs defaults,_netdev 0 0" >> /etc/fstab
```

`_netdev` บอกว่าต้องรอ network ก่อนค่อย mount

---

## 7. autofs — mount อัตโนมัติเมื่อเข้าใช้ (ออกสอบบ่อยมาก)

**หลักการ:** ไม่ต้อง mount ค้างไว้ เมื่อมีคน `cd` เข้าไป autofs จะ mount ให้ เมื่อไม่ได้ใช้สักพักจะ unmount เอง

ไฟล์ที่เกี่ยวข้อง:
- **master map** `/etc/auto.master.d/*.autofs` : บอกว่า directory แม่คืออะไร และใช้ map ไฟล์ไหน
- **map file** เช่น `/etc/auto.home` : บอกว่า directory ลูกแต่ละตัว mount จากที่ไหน

> **แนวข้อสอบ:** "ตั้งค่า autofs ให้ home ของ `remoteuser1` ที่ `serverb:/exports/home/remoteuser1` ถูก mount อัตโนมัติที่ `/rhome/remoteuser1` แบบอ่านเขียนได้"

```bash
dnf install -y autofs nfs-utils

# master map
echo "/rhome  /etc/auto.rhome" > /etc/auto.master.d/rhome.autofs

# map file : key  options  location
echo "remoteuser1  -rw,sync  serverb:/exports/home/remoteuser1" > /etc/auto.rhome

systemctl enable --now autofs
systemctl restart autofs

# ทดสอบ: ต้อง cd เข้าไป ถึงจะเห็น
ls /rhome                  # ยังว่าง (ปกติ)
cd /rhome/remoteuser1
df -h .                    # เห็นว่ามาจาก serverb
```

### Wildcard map (ให้ทุก user ในครั้งเดียว)

```
*   -rw,sync   serverb:/exports/home/&
```

`*` = ชื่อใดก็ได้ที่ถูกเรียก, `&` = แทนด้วยชื่อนั้น

> ถ้าโจทย์ให้ user `remoteuser1` มี home เป็น `/rhome/remoteuser1` ต้องสร้าง user ให้ตรง:
> `useradd -M -d /rhome/remoteuser1 -u <UID ตามโจทย์> remoteuser1`

---

## 🧪 Lab 05 (ใช้ดิสก์ vdb และ vdc ที่ว่างอยู่)

1. บน `/dev/vdb` สร้าง partition 1 GB ฟอร์แมตเป็น `xfs` mount ถาวรที่ `/mnt/part1` ด้วย UUID
2. สร้าง VG ชื่อ `qagroup` บน `/dev/vdc` โดยมี PE size 16 MB
3. สร้าง LV ชื่อ `qa` ขนาด 60 extents ฟอร์แมต `ext4` mount ถาวรที่ `/mnt/qa`
4. ขยาย `qa` ให้เป็น 1.2 GB โดยข้อมูลไม่หาย
5. เพิ่ม swap ขนาด 512 MB จาก partition ใหม่บน `/dev/vdb` ให้ใช้งานตอนบูต
6. ตั้ง autofs ให้ `/rhome/remoteuser1` mount จาก serverb
7. Reboot แล้วตรวจทุกอย่าง

<details>
<summary>เฉลย Lab 05</summary>

```bash
# 1
parted -s /dev/vdb mklabel gpt mkpart p1 xfs 1MiB 1025MiB
mkfs.xfs /dev/vdb1
mkdir -p /mnt/part1
echo "UUID=$(blkid -s UUID -o value /dev/vdb1) /mnt/part1 xfs defaults 0 0" >> /etc/fstab

# 2-3
pvcreate /dev/vdc
vgcreate -s 16M qagroup /dev/vdc
lvcreate -n qa -l 60 qagroup           # 960 MB
mkfs.ext4 /dev/qagroup/qa
mkdir -p /mnt/qa
echo "/dev/qagroup/qa /mnt/qa ext4 defaults 0 0" >> /etc/fstab
systemctl daemon-reload ; mount -a

# 4
lvextend -r -L 1.2G /dev/qagroup/qa
df -h /mnt/qa

# 5
parted -s /dev/vdb mkpart swap1 linux-swap 1025MiB 1537MiB
mkswap /dev/vdb2
echo "UUID=$(blkid -s UUID -o value /dev/vdb2) swap swap defaults 0 0" >> /etc/fstab
swapon -a ; swapon --show

# 6
dnf install -y autofs nfs-utils
echo "/rhome /etc/auto.rhome" > /etc/auto.master.d/rhome.autofs
echo "remoteuser1 -rw,sync serverb:/exports/home/remoteuser1" > /etc/auto.rhome
systemctl enable --now autofs

# 7
findmnt --verify && reboot
# หลังบูต
lsblk ; df -h ; swapon --show ; ls /rhome/remoteuser1
```
</details>
