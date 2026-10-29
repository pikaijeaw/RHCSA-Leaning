# บทที่ 00 — เตรียม Lab สำหรับฝึก

ข้อสอบ RHCSA เป็นการลงมือทำ 100% ดังนั้น **ต้องมีเครื่องให้ฝึก** และต้องเป็นเครื่องที่ทำพังได้

## 1. สิ่งที่ต้องใช้

| อย่าง | แนะนำ |
|---|---|
| Hypervisor | VirtualBox, VMware Workstation/Fusion, KVM/virt-manager, UTM (Mac M1/M2 ใช้ ISO แบบ aarch64) |
| OS | **RHEL 9** (ฟรีผ่าน Red Hat Developer Subscription) หรือ **Rocky Linux 9** / **AlmaLinux 9** (คำสั่งเหมือนกันแทบ 100%) |
| RAM | เครื่องละ 2 GB ขึ้นไป |
| Disk | OS 20 GB + **ดิสก์เปล่าเพิ่มอีก 2–3 ลูก ลูกละ 5 GB** (ไว้ฝึก partition/LVM/swap) |

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
2. ตอนติดตั้ง ให้ตั้ง root password และสร้าง user ธรรมดา 1 คน (เช่น `student`) ติ๊ก "Make this user administrator"
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
