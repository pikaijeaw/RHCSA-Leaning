# บทที่ 02 — Shell Script พื้นฐาน

ใน objectives ของ RHCSA มีหัวข้อ "Create simple shell scripts" ข้อสอบมักให้เขียน script สั้น ๆ ที่รับ argument, ใช้ `if` หรือ `for` และทำงานตามเงื่อนไข

## 1. โครงสร้าง script

```bash
#!/bin/bash
# บรรทัดแรก (shebang) บอกว่าจะใช้ bash รัน
echo "Hello, $USER"
```

```bash
vim /usr/local/bin/hello.sh
chmod +x /usr/local/bin/hello.sh   # ต้องให้สิทธิ์ execute
/usr/local/bin/hello.sh            # รัน
hello.sh                           # รันได้เลยเพราะ /usr/local/bin อยู่ใน $PATH
```

## 2. ตัวแปรและ argument

```bash
#!/bin/bash
NAME="RHCSA"              # ห้ามมีช่องว่างรอบ =
echo "Learning $NAME"
TODAY=$(date +%F)         # เก็บผลของคำสั่งลงตัวแปร
echo "Today is $TODAY"

echo "Script name: $0"
echo "First arg  : $1"
echo "Second arg : $2"
echo "All args   : $@"
echo "Num args   : $#"
```

```bash
./vars.sh apple banana
```

## 3. Exit code

ทุกคำสั่งคืนค่า exit code: `0` = สำเร็จ, ค่าอื่น = ล้มเหลว ดูได้จาก `$?`

```bash
ls /etc ; echo $?     # 0
ls /nope ; echo $?    # 2
```

ใน script ใช้ `exit 1` เพื่อจบพร้อมบอกว่าล้มเหลว

## 4. if / test

```bash
#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

if id "$1" &>/dev/null; then
    echo "User $1 exists"
else
    echo "User $1 not found"
fi
```

ตัวเปรียบเทียบที่ใช้บ่อย:

| ประเภท | เงื่อนไข | ความหมาย |
|---|---|---|
| ตัวเลข | `-eq -ne -lt -le -gt -ge` | เท่ากับ, ไม่เท่ากับ, น้อยกว่า, ... |
| ข้อความ | `=` `!=` `-z` `-n` | เท่ากัน, ไม่เท่ากัน, ว่าง, ไม่ว่าง |
| ไฟล์ | `-f` `-d` `-e` `-r` `-w` `-x` | เป็นไฟล์, เป็น dir, มีอยู่, อ่านได้, เขียนได้, รันได้ |

## 5. for / while

```bash
#!/bin/bash
for USER in alice bob carol; do
    useradd "$USER" && echo "created $USER"
done

for i in {1..5}; do
    echo "Round $i"
done

# อ่านไฟล์ทีละบรรทัด
while read -r LINE; do
    echo "-> $LINE"
done < /etc/hostname
```

## 6. case

```bash
#!/bin/bash
case "$1" in
    start)  echo "Starting..." ;;
    stop)   echo "Stopping..." ;;
    *)      echo "Usage: $0 {start|stop}"; exit 1 ;;
esac
```

---

## ตัวอย่างแนวข้อสอบ

> **โจทย์:** สร้าง script `/usr/local/bin/myscript` ที่
> - ถ้าไม่ใส่ argument ให้พิมพ์ `Usage: myscript <dir>` และ exit code เป็น 1
> - ถ้าใส่ directory มา ให้หาไฟล์ใน directory นั้นที่มีขนาดมากกว่า 30 KB แต่น้อยกว่า 50 KB และมี SUID แล้วพิมพ์ชื่อไฟล์ออกมา

```bash
#!/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: myscript <dir>"
    exit 1
fi

find "$1" -type f -size +30k -size -50k -perm -4000 2>/dev/null
```

```bash
chmod +x /usr/local/bin/myscript
myscript ; echo $?      # Usage... และ 1
myscript /usr/bin
```

> **โจทย์:** สร้าง script `/root/useradd.sh` ที่อ่านรายชื่อ user จากไฟล์ที่ระบุใน argument แล้วสร้าง user ทุกคนโดยให้ shell เป็น `/sbin/nologin` ถ้า user มีอยู่แล้วให้ข้าม

```bash
#!/bin/bash
[ -f "$1" ] || { echo "file not found"; exit 1; }

while read -r U; do
    [ -z "$U" ] && continue
    if id "$U" &>/dev/null; then
        echo "skip $U"
    else
        useradd -s /sbin/nologin "$U" && echo "added $U"
    fi
done < "$1"
```

---

## 🧪 Lab 02

1. เขียน script `/usr/local/bin/sysinfo` ที่พิมพ์ hostname, kernel version (`uname -r`), จำนวน user ใน `/etc/passwd` และพื้นที่ว่างของ `/`
2. เขียน script `/usr/local/bin/checkfile` ที่รับชื่อไฟล์ 1 ตัว ถ้าเป็นไฟล์ให้พิมพ์ `regular file` ถ้าเป็น directory ให้พิมพ์ `directory` ถ้าไม่มีให้พิมพ์ `not found` และ exit 2
3. เขียน script ที่วนลูปสร้างไฟล์ `/tmp/test1.txt` ถึง `/tmp/test10.txt`

<details>
<summary>เฉลย Lab 02</summary>

```bash
# 1
cat > /usr/local/bin/sysinfo <<'EOF'
#!/bin/bash
echo "Hostname : $(hostname)"
echo "Kernel   : $(uname -r)"
echo "Users    : $(wc -l < /etc/passwd)"
echo "Root free: $(df -h / | awk 'NR==2 {print $4}')"
EOF
chmod +x /usr/local/bin/sysinfo

# 2
cat > /usr/local/bin/checkfile <<'EOF'
#!/bin/bash
if [ -f "$1" ]; then
    echo "regular file"
elif [ -d "$1" ]; then
    echo "directory"
else
    echo "not found"
    exit 2
fi
EOF
chmod +x /usr/local/bin/checkfile

# 3
for i in {1..10}; do touch /tmp/test$i.txt; done
```
</details>
