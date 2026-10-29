# บทที่ 00 — เตรียม Lab สำหรับฝึก

ข้อสอบ RHCSA เป็นการลงมือทำ 100% ดังนั้น **ต้องมีเครื่องให้ฝึก** และต้องเป็นเครื่องที่ทำพังได้

## 1. สิ่งที่ต้องใช้

| อย่าง | แนะนำ |
|---|---|
| Hypervisor | VirtualBox, VMware Workstation/Fusion, KVM/virt-manager, UTM (Mac M1/M2 ใช้ ISO แบบ aarch64) |
| OS | **RHEL 10** (ฟรีผ่าน Red Hat Developer Subscription) หรือ **Rocky Linux 10** / **AlmaLinux 10** (คำสั่งเหมือนกันแทบ 100%) |
| CPU | ต้องรองรับ **x86-64-v3** (CPU Intel Haswell / AMD Excavator ขึ้นไป) |
| RAM | เครื่องละ 2 GB ขึ้นไป (ถ้าติดตั้ง GUI แนะนำ 4 GB) |
| Disk | OS 20 GB + **ดิสก์เปล่าเพิ่มอีก 2–3 ลูก ลูกละ 5 GB** (ไว้ฝึก partition/LVM/swap) |

### ⚠ เรื่อง CPU ของ RHEL 10

RHEL 10 (x86_64) ถูก build ให้ต้องใช้ชุดคำสั่ง **x86-64-v3** (เช่น AVX2) ถ้า VM มองไม่เห็นความสามารถเหล่านี้ เครื่องจะ **บูต ISO ไม่ขึ้นเลย** หรือ kernel panic ตอนเริ่ม

- **KVM / virt-manager:** ตั้ง CPU model เป็น `host-passthrough`
- **VirtualBox:** ปิด Hyper-V / Memory Integrity บน Windows ก่อน ไม่งั้น VirtualBox จะส่ง AVX2 ให้ VM ไม่ได้
- **VMware:** ใช้ค่าเริ่มต้นได้ ถ้าบูตไม่ขึ้นให้ตรวจว่า Hyper-V บน Windows ปิดอยู่
- ตรวจจาก Linux ที่มีอยู่ว่า CPU รองรับไหม: `/lib64/ld-linux-x86-64.so.2 --help | grep v3` ต้องเห็น `x86-64-v3 (supported, searched)`
- ถ้าเครื่องเก่าจริง ๆ AlmaLinux 10 มีรุ่นที่ build สำหรับ x86-64-v2 ให้ดาวน์โหลดแยก (ตรวจที่หน้าดาวน์โหลดของ AlmaLinux)
- Mac รุ่นใช้ชิป Apple Silicon ใช้ ISO แบบ aarch64 บน UTM ได้ ไม่ติดปัญหานี้

## 2. ผัง Lab ที่แนะนำ

```
            เครือข่าย NAT / Host-only : 192.168.122.0/24
    ┌─────────────────────────┐        ┌─────────────────────────┐
    │ servera.lab.example.com │        │ serverb.lab.example.com │
    │ 192.168.122.10          │◄──────►│ 192.168.122.20          │
    │ ดิสก์: vda(OS) vdb vdc   │        │ ทำหน้าที่ NFS server,    │
    │ เครื่องหลักที่ใช้ฝึก        │        │ repo server, chrony server│
    └─────────────────────────┘        └─────────────────────────┘
```

> ในห้องสอบจริงมักมี 2 เครื่องในลักษณะนี้ โดยมี repo และ NFS ถูกเตรียมไว้ให้แล้ว
> ใน Lab ของเรา ให้ `serverb` ทำหน้าที่นั้นแทน

## 3. ขั้นตอนติดตั้ง

1. สร้าง VM ชื่อ `servera` ติดตั้งแบบ **Minimal Install** หรือ **Server with GUI** (ห้องสอบมักเป็นแบบมี GUI)
2. ตอนติดตั้ง ให้สร้าง user ธรรมดา 1 คน (เช่น `student`) ใน RHEL 10 ตัวเลือก "Make this user administrator" ถูกติ๊กไว้ให้แล้ว และให้ **เปิด root account พร้อมตั้ง root password ด้วย** เพราะต้องใช้ฝึก reset root password และ emergency mode (ถ้าลืม ทำทีหลังได้ด้วย `sudo passwd root`)
3. หลังติดตั้งเสร็จ เพิ่มดิสก์เปล่า 2 ลูกให้ `servera`
4. Clone หรือติดตั้ง `serverb` แบบเดียวกัน และเพิ่มดิสก์เปล่า 2 ลูก (vdb, vdc ลูกละ 5 GB) ให้ serverb ด้วย (ใช้ในข้อสอบจำลองส่วน A)

**ทำ Snapshot ทันทีหลังติดตั้งเสร็จ** ตั้งชื่อว่า `clean` จะได้ย้อนกลับมาฝึกซ้ำได้เรื่อย ๆ

## 4. เตรียม serverb ให้เป็น NFS + Repo server (ไว้ใช้ในบท Storage และ Software)

ทำบน `serverb` ในฐานะ root:

```bash
# ---- NFS server สำหรับฝึก autofs ----
dnf install -y nfs-utils
mkdir -p /exports/home/{remoteuser1,remoteuser2}
mkdir -p /exports/share
echo "Hello from NFS" > /exports/share/readme.txt

cat >> /etc/exports <<'EOF'
/exports/home   192.168.122.0/24(rw,sync,no_root_squash)
/exports/share  192.168.122.0/24(ro,sync)
EOF

systemctl enable --now nfs-server
exportfs -rav
firewall-cmd --permanent --add-service={nfs,mountd,rpc-bind}
firewall-cmd --reload

# ---- Repo server (HTTP) จาก ISO ----
dnf install -y httpd
mkdir -p /var/www/html/repo
# ใส่ ISO เข้า CD-ROM ของ VM ก่อน
mount /dev/sr0 /mnt
cp -a /mnt/BaseOS /mnt/AppStream /var/www/html/repo/
umount /mnt
restorecon -Rv /var/www/html
systemctl enable --now httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --reload

# ---- chrony server ให้เครื่องอื่นมาซิงค์เวลา ----
echo "allow 192.168.122.0/24" >> /etc/chrony.conf
echo "local stratum 8" >> /etc/chrony.conf
systemctl restart chronyd
firewall-cmd --permanent --add-service=ntp
firewall-cmd --reload
```

> **เรื่อง Flatpak:** ในห้องสอบจะมี flatpak remote ภายในเตรียมไว้ให้ แต่ใน Lab ของเรา ใช้ Flathub (`https://dl.flathub.org/repo/flathub.flatpakrepo`) แทน
> ดังนั้นเครือข่ายของ VM ต้องเป็นแบบ **NAT ที่ออกอินเทอร์เน็ตได้** อย่างน้อยตอนฝึกหัวข้อนี้

ตรวจจาก `servera`:

```bash
showmount -e 192.168.122.20
curl http://192.168.122.20/repo/BaseOS/repodata/repomd.xml | head -3
```

## 5. ใส่ชื่อเครื่องใน /etc/hosts ทั้งสองเครื่อง

```bash
cat >> /etc/hosts <<'EOF'
192.168.122.10 servera.lab.example.com servera
192.168.122.20 serverb.lab.example.com serverb
EOF
```

## 6. นิสัยที่ควรฝึกตั้งแต่วันแรก

- ทำงานเป็น root ด้วย `sudo -i` หรือ `su -`
- เปิด man page บ่อย ๆ แทนการ Google เพราะในห้องสอบ Google ไม่ได้
- ทุกครั้งที่ทำ Lab เสร็จ ให้ `reboot` แล้วตรวจผลอีกรอบ
