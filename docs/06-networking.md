# บทที่ 06 — Networking และ SSH

## 1. หลักการ

เครื่องจะคุยกับเครื่องอื่นได้ต้องมี 4 อย่าง:

| สิ่งที่ต้องมี | ตัวอย่าง | ดูด้วย |
|---|---|---|
| IP address + prefix | `192.168.122.10/24` | `ip addr` |
| Gateway (ทางออก) | `192.168.122.1` | `ip route` |
| DNS (แปลชื่อเป็น IP) | `192.168.122.1` | `cat /etc/resolv.conf` |
| Hostname | `servera.lab.example.com` | `hostnamectl` |

ใน RHEL 9 network ถูกจัดการโดย **NetworkManager** การตั้งค่าแต่ละชุดเรียกว่า **connection** (profile) ซึ่งผูกกับ **device** (การ์ดแลน เช่น `enp1s0`, `eth0`)
ไฟล์ตั้งค่าเก็บที่ `/etc/NetworkManager/system-connections/*.nmconnection`

---

## 2. คำสั่งดูสถานะ

```bash
ip addr show            # หรือ ip a
ip route                # routing table
ip link                 # สถานะการ์ด
ping -c 3 192.168.122.1
ss -tlnp                # port ที่เปิดรอ (TCP listening)
nmcli device status
nmcli connection show
```

---

## 3. ตั้งค่า Static IP ด้วย nmcli (ออกสอบแน่นอน)

> **แนวข้อสอบ:** ตั้งค่า node1 ดังนี้
> - Hostname: `node1.domain250.example.com`
> - IP: `172.25.250.100/24`
> - Gateway: `172.25.250.254`
> - DNS: `172.25.250.254`

```bash
nmcli connection show
# NAME          UUID   TYPE      DEVICE
# Wired conn 1  ...    ethernet  enp1s0

nmcli connection modify "Wired conn 1" \
    ipv4.method manual \
    ipv4.addresses 172.25.250.100/24 \
    ipv4.gateway 172.25.250.254 \
    ipv4.dns 172.25.250.254 \
    connection.autoconnect yes

nmcli connection up "Wired conn 1"

hostnamectl set-hostname node1.domain250.example.com
```

> **ทำผ่าน console เสมอ** ถ้าเปลี่ยน IP ผ่าน SSH, connection จะหลุด

ตรวจ:

```bash
ip a ; ip route ; cat /etc/resolv.conf ; hostname
```

### สร้าง connection ใหม่

```bash
nmcli connection add con-name static-eth1 type ethernet ifname eth1 \
    ipv4.method manual ipv4.addresses 10.0.0.5/24 ipv4.gateway 10.0.0.1 \
    ipv4.dns "8.8.8.8 1.1.1.1"
nmcli connection up static-eth1
```

### เพิ่ม IP ที่สอง / IPv6

```bash
nmcli connection modify static-eth1 +ipv4.addresses 10.0.0.6/24
nmcli connection modify static-eth1 ipv6.method manual ipv6.addresses fd00::5/64
```

### ตัวเลือกอื่น

- `nmtui` : เมนูแบบข้อความ ใช้ง่าย ถ้าจำคำสั่งไม่ได้ใช้อันนี้ได้ในห้องสอบ
- `man nmcli-examples` : มีตัวอย่างครบ

---

## 4. Hostname และการ resolve ชื่อ

```bash
hostnamectl set-hostname servera.lab.example.com
hostnamectl                 # ตรวจ (เก็บที่ /etc/hostname)
```

`/etc/hosts` ใช้แปลชื่อแบบ local (ถูกตรวจก่อน DNS ตามลำดับใน `/etc/nsswitch.conf`)

```
192.168.122.20  serverb.lab.example.com serverb
```

```bash
getent hosts serverb        # ตรวจการแปลชื่อ
dig serverb.lab.example.com # ถามจาก DNS (package bind-utils)
```

---

## 5. SSH

### เชื่อมต่อและ copy ไฟล์

```bash
ssh student@serverb
ssh -i ~/.ssh/id_ed25519 root@serverb
scp file.txt student@serverb:/tmp/
scp -r student@serverb:/etc/ssh ./ssh-backup
rsync -av /data/ serverb:/backup/data/
sftp student@serverb
```

### Key-based authentication

```bash
ssh-keygen -t ed25519            # สร้าง key (Enter ผ่านทั้งหมด)
ssh-copy-id student@serverb      # ส่ง public key ไปยัง server
ssh student@serverb              # ต้องเข้าได้โดยไม่ถาม password
```

Public key จะไปอยู่ใน `~/.ssh/authorized_keys` ของปลายทาง สิทธิ์ต้องเป็น `~/.ssh` = 700, `authorized_keys` = 600

### ตั้งค่า sshd (`/etc/ssh/sshd_config` หรือไฟล์ใน `/etc/ssh/sshd_config.d/`)

```
PermitRootLogin no              # ห้าม root login ผ่าน ssh
PasswordAuthentication no       # ให้ใช้ key อย่างเดียว
Port 2222                       # เปลี่ยน port (ต้องแก้ SELinux + firewall ด้วย ดูบท 07)
```

```bash
sshd -t                         # ตรวจ syntax
systemctl restart sshd
```

---

## 🧪 Lab 06

1. บน servera ตั้ง IP แบบ static `192.168.122.10/24` gateway และ DNS `192.168.122.1`
2. ตั้ง hostname เป็น `servera.lab.example.com`
3. เพิ่ม IP ที่สอง `192.168.122.11/24` ใน connection เดียวกัน
4. ให้ user `student` บน servera ssh ไป serverb ได้โดยไม่ต้องใส่ password
5. Reboot แล้วตรวจว่า IP ทั้งสองยังอยู่

<details>
<summary>เฉลย Lab 06</summary>

```bash
CON=$(nmcli -g NAME connection show --active | head -1)
nmcli connection modify "$CON" ipv4.method manual \
    ipv4.addresses 192.168.122.10/24 ipv4.gateway 192.168.122.1 \
    ipv4.dns 192.168.122.1 connection.autoconnect yes
nmcli connection modify "$CON" +ipv4.addresses 192.168.122.11/24
nmcli connection up "$CON"
hostnamectl set-hostname servera.lab.example.com

su - student
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
ssh-copy-id student@serverb
ssh student@serverb hostname
exit

reboot
ip -4 a
```
</details>
