# บทที่ 01 — เครื่องมือพื้นฐาน (Essential Tools)

## 1. หลักการ: Linux มองทุกอย่างเป็น "ไฟล์"

- ทุกอย่างเริ่มที่ `/` (root directory) ไม่มี `C:\` แบบ Windows
- ดิสก์, terminal, process ก็มองเป็นไฟล์ได้ (`/dev/sda`, `/proc/1`)
- ตัวพิมพ์เล็ก/ใหญ่ **ต่างกัน**: `File.txt` กับ `file.txt` คือคนละไฟล์

### โครงสร้างไดเรกทอรีที่ต้องรู้

| Path | เก็บอะไร |
|---|---|
| `/etc` | ไฟล์ตั้งค่าระบบ (config) **สำคัญที่สุดสำหรับสอบ** |
| `/home` | home ของ user ทั่วไป |
| `/root` | home ของ root |
| `/var` | ข้อมูลที่เปลี่ยนบ่อย เช่น log (`/var/log`), เว็บ (`/var/www`) |
| `/tmp` | ไฟล์ชั่วคราว (ทุกคนเขียนได้, มี sticky bit) |
| `/usr/bin`, `/usr/sbin` | โปรแกรม |
| `/dev` | อุปกรณ์ เช่น ดิสก์ |
| `/proc`, `/sys` | ข้อมูลของ kernel (ไฟล์เสมือน) |
| `/boot` | kernel และ GRUB |

**Absolute path** เริ่มด้วย `/` เช่น `/etc/passwd`
**Relative path** เริ่มจากตำแหน่งปัจจุบัน เช่น `../file` (`.` = ที่นี่, `..` = ขึ้นไปหนึ่งชั้น, `~` = home)

---

## 2. คำสั่งจัดการไฟล์พื้นฐาน

```bash
pwd                         # อยู่ที่ไหน
ls -l                       # ดูรายละเอียด
ls -la                      # รวมไฟล์ซ่อน (ขึ้นต้นด้วย .)
ls -ld /tmp                 # ดูข้อมูลของ directory เอง ไม่ใช่ของข้างใน
ls -lZ                      # ดู SELinux context ด้วย
cd /etc ; cd ~ ; cd -       # ไปที่ /etc, กลับ home, กลับที่เดิม

mkdir -p /data/a/b/c        # -p สร้าง parent ให้ด้วย
touch file1                 # สร้างไฟล์ว่าง / อัปเดตเวลา
cp file1 /tmp/              # copy
cp -r dir1 /tmp/            # copy ทั้ง directory
cp -a src dst               # copy แบบเก็บ permission, owner, เวลา (archive)
mv old new                  # ย้าย / เปลี่ยนชื่อ
rm -rf dir1                 # ลบทั้ง directory (ระวัง!)

cat /etc/os-release         # ดูไฟล์
less /var/log/messages      # อ่านไฟล์ยาว (กด / เพื่อค้นหา, q เพื่อออก)
head -n 5 file ; tail -n 5 file
tail -f /var/log/messages   # ดู log แบบ real-time
wc -l /etc/passwd           # นับบรรทัด
```

### Wildcard / Globbing

```bash
ls *.conf           # ทุกไฟล์ที่ลงท้าย .conf
ls file?            # file ตามด้วยตัวอักษร 1 ตัว
ls file[1-3]        # file1 file2 file3
echo {a,b,c}.txt    # a.txt b.txt c.txt  (brace expansion)
mkdir dir{1..5}     # dir1 ... dir5
```

---

## 3. Redirection และ Pipe (ออกสอบบ่อยในรูปแบบ "บันทึกผลลงไฟล์")

ทุกโปรแกรมมี 3 ช่องทาง:

| หมายเลข | ชื่อ | ความหมาย |
|---|---|---|
| 0 | stdin | ข้อมูลเข้า |
| 1 | stdout | ผลลัพธ์ปกติ |
| 2 | stderr | ข้อความ error |

```bash
ls /etc > out.txt           # stdout เขียนทับไฟล์
ls /etc >> out.txt          # stdout ต่อท้ายไฟล์
ls /nope 2> err.txt         # stderr ลงไฟล์
ls /etc /nope &> all.txt    # ทั้ง stdout และ stderr
find / -name passwd 2>/dev/null   # ทิ้ง error ไปถังขยะ
ls -l /etc | less           # pipe: ส่ง output ไปเป็น input ของคำสั่งถัดไป
ls -l /etc | tee list.txt   # แสดงบนจอ และเขียนลงไฟล์พร้อมกัน
```

---

## 4. grep — ค้นข้อความในไฟล์

```bash
grep root /etc/passwd             # บรรทัดที่มีคำว่า root
grep -i error /var/log/messages   # ไม่สนตัวพิมพ์เล็ก/ใหญ่
grep -v '^#' /etc/ssh/sshd_config # บรรทัดที่ไม่ขึ้นต้นด้วย #
grep -v '^#' file | grep -v '^$'  # ตัด comment และบรรทัดว่าง
grep -r "Listen" /etc/httpd/      # ค้นทั้ง directory
grep -n ssh /etc/services         # แสดงเลขบรรทัด
grep -E 'root|student' /etc/passwd  # regex แบบขยาย (หรือ)
grep '^ex' /usr/share/dict/words  # ขึ้นต้นด้วย ex
grep 'ing$' file                  # ลงท้ายด้วย ing
```

Regular expression ที่ใช้บ่อย: `^` ต้นบรรทัด, `$` ท้ายบรรทัด, `.` ตัวอักษรใดก็ได้, `*` ซ้ำ 0 ครั้งขึ้นไป, `[abc]` ตัวใดตัวหนึ่ง

> **แนวข้อสอบ:** "ค้นหาทุกบรรทัดในไฟล์ `/usr/share/dict/words` ที่มีคำว่า `ich` แล้วบันทึกลงไฟล์ `/root/lines` โดยเรียงลำดับเหมือนต้นฉบับ"
>
> ```bash
> grep ich /usr/share/dict/words > /root/lines
> ```

---

## 5. find — ค้นหาไฟล์ (ออกสอบแทบทุกครั้ง)

```bash
find /etc -name "*.conf"              # ตามชื่อ
find / -iname "readme*"               # ไม่สนตัวพิมพ์
find / -user harry                    # ไฟล์ของ user harry
find / -group wheel
find / -type f -size +10M             # ไฟล์ขนาดเกิน 10 MB
find / -type f -size -1k              # ไฟล์เล็กกว่า 1 KB
find /var -mtime -2                   # ถูกแก้ไขภายใน 2 วัน
find / -perm -4000                    # มี SUID bit
find / -perm 644                      # permission ตรง 644 เป๊ะ
find /home -type d -empty             # directory ว่าง

# ทำอะไรบางอย่างกับไฟล์ที่เจอ
find / -user harry -exec cp -a {} /root/harryfiles/ \; 2>/dev/null
find /tmp -name "*.log" -delete
```

> **แนวข้อสอบ:** "หาไฟล์ทั้งหมดของ user `jacques` แล้ว copy ไปไว้ที่ `/root/findfiles` โดยคง permission เดิม"
>
> ```bash
> mkdir -p /root/findfiles
> find / -user jacques -type f -exec cp -a {} /root/findfiles/ \; 2>/dev/null
> ```
> (`-type f` เพื่อเลือกเฉพาะไฟล์, `2>/dev/null` ซ่อน error ของ /proc)

---

## 6. tar — สร้างและแตกไฟล์ archive

| ตัวเลือก | ความหมาย |
|---|---|
| `c` | create สร้าง |
| `x` | extract แตก |
| `t` | list ดูข้างใน |
| `f` | ชื่อไฟล์ (ต้องตามด้วยชื่อ) |
| `v` | แสดงรายละเอียด |
| `z` | gzip (`.tar.gz`) |
| `j` | bzip2 (`.tar.bz2`) |
| `J` | xz (`.tar.xz`) |

```bash
tar -czvf /root/etc.tar.gz /etc        # บีบด้วย gzip
tar -cjvf /root/local.tar.bz2 /usr/local   # บีบด้วย bzip2
tar -tf /root/etc.tar.gz | head        # ดูข้างใน
tar -xzvf /root/etc.tar.gz -C /tmp     # แตกไปที่ /tmp
```

> **แนวข้อสอบ:** "สร้างไฟล์ backup ชื่อ `/root/backup.tar.bz2` ที่เก็บเนื้อหาของ `/usr/local` บีบอัดด้วย bzip2"
>
> ```bash
> tar -cjf /root/backup.tar.bz2 /usr/local
> file /root/backup.tar.bz2     # ตรวจว่าเป็น bzip2 จริง
> ```

---

## 7. Hard link และ Soft link

**หลักการ:** ไฟล์ทุกไฟล์มี **inode** (ที่เก็บข้อมูลจริง) ส่วนชื่อไฟล์คือป้ายที่ชี้ไปหา inode

| | Hard link | Soft (Symbolic) link |
|---|---|---|
| ชี้ไปที่ | inode เดียวกัน | ชื่อไฟล์ (path) |
| ลบไฟล์ต้นฉบับ | ยังเปิดได้ | ลิงก์เสีย (broken) |
| ข้าม filesystem | ไม่ได้ | ได้ |
| ใช้กับ directory | ไม่ได้ | ได้ |

```bash
echo "data" > original.txt
ln original.txt hard.txt          # hard link
ln -s /root/original.txt soft.txt # soft link (ใช้ absolute path ปลอดภัยกว่า)
ls -li                            # ดูเลข inode: hard link มีเลขเดียวกัน
```

---

## 8. การหาความช่วยเหลือ (สำคัญมากในห้องสอบ)

```bash
man ls                 # คู่มือ
man -k partition       # ค้น man page ที่เกี่ยวกับคำนี้ (ถ้าไม่เจอให้รัน mandb ก่อน)
man 5 passwd           # section 5 = รูปแบบไฟล์
ls --help
/usr/share/doc/        # เอกสารของ package
```

Section ของ man page ที่ใช้บ่อย: `1` คำสั่งทั่วไป, `5` รูปแบบไฟล์ config, `8` คำสั่งของผู้ดูแลระบบ

---

## 9. Text editor: vim (ต้องใช้ให้เป็น)

```
vim file        เปิดไฟล์
i               เข้าโหมดพิมพ์ (Insert)
Esc             กลับโหมดคำสั่ง
:w              บันทึก
:q              ออก
:wq หรือ :x     บันทึกแล้วออก
:q!             ออกโดยไม่บันทึก
dd              ลบทั้งบรรทัด
yy / p          copy บรรทัด / วาง
u               undo
/คำ             ค้นหา (n = ถัดไป)
:set nu         แสดงเลขบรรทัด
G / gg          ไปท้ายไฟล์ / ต้นไฟล์
```

---

## 🧪 Lab 01

1. สร้าง directory `/lab01/{docs,backup,links}` ด้วยคำสั่งเดียว
2. ค้นทุกบรรทัดใน `/etc/passwd` ที่ลงท้ายด้วย `/bin/bash` แล้วบันทึกลง `/lab01/docs/bash_users.txt`
3. หาไฟล์ทั้งหมดใน `/etc` ที่มีขนาดเกิน 100 KB บันทึก path ลง `/lab01/docs/big.txt` (ไม่ให้มี error ในไฟล์)
4. สร้าง archive `/lab01/backup/etc.tar.gz` จาก `/etc` แบบ gzip
5. สร้าง soft link `/lab01/links/hosts` ชี้ไปที่ `/etc/hosts`
6. สร้างไฟล์ `/lab01/docs/a.txt` และ hard link `/lab01/docs/b.txt` แล้วพิสูจน์ว่าเป็น inode เดียวกัน

<details>
<summary>เฉลย Lab 01</summary>

```bash
mkdir -p /lab01/{docs,backup,links}
grep '/bin/bash$' /etc/passwd > /lab01/docs/bash_users.txt
find /etc -type f -size +100k > /lab01/docs/big.txt 2>/dev/null
tar -czf /lab01/backup/etc.tar.gz /etc
ln -s /etc/hosts /lab01/links/hosts
touch /lab01/docs/a.txt
ln /lab01/docs/a.txt /lab01/docs/b.txt
ls -li /lab01/docs/a.txt /lab01/docs/b.txt   # เลข inode ต้องตรงกัน
```
</details>
