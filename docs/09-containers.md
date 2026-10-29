# บทที่ 09 — Containers ด้วย Podman

> หมายเหตุ: หัวข้อ containers อยู่ใน objectives ของ EX200 บางเวอร์ชันและถูกถอดออกในบางเวอร์ชัน
> **ให้ตรวจ objectives ล่าสุดของรอบที่จะสอบ** แต่ควรเรียนไว้ เพราะใช้ในงานจริงและอยู่ใน RHCE ด้วย

## 1. หลักการ

- **Image** = แม่แบบ (อ่านอย่างเดียว) เช่น `registry.access.redhat.com/ubi9/httpd-24`
- **Container** = image ที่ถูกนำมารัน มีพื้นที่เขียนของตัวเอง
- **Registry** = ที่เก็บ image (เช่น `registry.redhat.io`, `quay.io`, `docker.io`)
- **Podman** = เครื่องมือรัน container ของ RHEL **ไม่มี daemon** และรันแบบ **rootless** (ด้วย user ธรรมดา) ได้
- ข้อมูลใน container **หายเมื่อลบ container** ถ้าต้องการเก็บถาวรต้องใช้ **volume** (bind mount จาก host)

```bash
dnf install -y container-tools
```

---

## 2. คำสั่งพื้นฐาน

```bash
podman login registry.redhat.io            # login registry
podman search httpd
podman pull registry.access.redhat.com/ubi9/ubi
podman images
podman inspect registry.access.redhat.com/ubi9/ubi   # ดูรายละเอียด image
skopeo inspect docker://registry.access.redhat.com/ubi9/ubi  # ดูโดยไม่ต้อง pull

podman run -it --name test ubi9/ubi /bin/bash   # รันแบบโต้ตอบ
podman run -d --name web -p 8080:8080 registry.access.redhat.com/ubi9/httpd-24
podman ps ; podman ps -a
podman logs web
podman exec -it web /bin/bash
podman stop web ; podman start web
podman rm -f web
podman rmi <image>
```

Registry ที่ค้นหาโดยค่าเริ่มต้นตั้งไว้ที่ `/etc/containers/registries.conf` (ระดับเครื่อง) หรือ `~/.config/containers/registries.conf` (ระดับ user)

### Environment variable และ Volume

```bash
mkdir -p ~/dbdata
podman run -d --name db \
    -e MYSQL_USER=user1 -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=items \
    -v ~/dbdata:/var/lib/mysql/data:Z \
    -p 3306:3306 \
    registry.redhat.io/rhel9/mariadb-105
```

`:Z` = ให้ podman ตั้ง SELinux context ของ directory บน host ให้ container ใช้ได้ (ถ้าลืมจะเจอ Permission denied)

### Build image จาก Containerfile

```dockerfile
# ~/myimg/Containerfile
FROM registry.access.redhat.com/ubi9/ubi
RUN dnf install -y httpd && dnf clean all
COPY index.html /var/www/html/
EXPOSE 80
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]
```

```bash
podman build -t myweb:1.0 ~/myimg
```

---

## 3. ให้ container เปิดอัตโนมัติตอนบูตด้วย systemd (แนวข้อสอบ)

> **โจทย์:** "ในฐานะ user `athena` ให้รัน container ชื่อ `logserver` จาก image `rsyslog`
> โดย mount `/home/athena/container_logs` ไปที่ `/var/log/journal` ใน container
> และให้ container เริ่มอัตโนมัติเมื่อเครื่องบูต (แม้ athena ไม่ได้ login)"

**ต้อง login เป็น athena ผ่าน `ssh athena@localhost`** (อย่าใช้ `su -` เพราะจะไม่มี user session ของ systemd)

```bash
ssh athena@localhost

mkdir -p ~/container_logs
podman run -d --name logserver \
    -v ~/container_logs:/var/log/journal:Z \
    <registry>/rsyslog

# สร้าง systemd unit (วิธีที่ยังใช้ได้ใน RHEL 9)
mkdir -p ~/.config/systemd/user
cd ~/.config/systemd/user
podman generate systemd --name logserver --files --new
# ได้ไฟล์ container-logserver.service

podman stop logserver ; podman rm logserver   # --new จะสร้าง container ใหม่จาก unit
systemctl --user daemon-reload
systemctl --user enable --now container-logserver.service
systemctl --user status container-logserver.service
exit
```

ในฐานะ root ทำให้ service ของ athena รันได้แม้ไม่ได้ login:

```bash
loginctl enable-linger athena
loginctl show-user athena | grep Linger    # Linger=yes
```

### วิธีใหม่: Quadlet (RHEL 9.2+)

```ini
# ~/.config/containers/systemd/logserver.container
[Container]
ContainerName=logserver
Image=<registry>/rsyslog
Volume=%h/container_logs:/var/log/journal:Z

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user start logserver.service
```

---

## 🧪 Lab 09

1. สร้าง user `athena` ตั้ง password
2. ในฐานะ athena รัน container `web` จาก `registry.access.redhat.com/ubi9/httpd-24` map port 8080 ของ host ไปยัง 8080 ใน container
3. mount `~/html` (มีไฟล์ `index.html`) ไปที่ `/var/www/html` ใน container
4. ให้ container เริ่มอัตโนมัติหลัง reboot ผ่าน systemd user service
5. Reboot แล้ว `curl http://localhost:8080`

<details>
<summary>เฉลย Lab 09</summary>

```bash
useradd athena ; echo redhat | passwd --stdin athena
loginctl enable-linger athena
ssh athena@localhost

mkdir -p ~/html && echo "Hello container" > ~/html/index.html
podman run -d --name web -p 8080:8080 -v ~/html:/var/www/html:Z \
    registry.access.redhat.com/ubi9/httpd-24
curl http://localhost:8080

mkdir -p ~/.config/systemd/user && cd ~/.config/systemd/user
podman generate systemd --name web --files --new
podman rm -f web
systemctl --user daemon-reload
systemctl --user enable --now container-web.service
exit

# เปิด firewall ถ้าจะเข้าจากเครื่องอื่น
firewall-cmd --permanent --add-port=8080/tcp && firewall-cmd --reload
reboot
curl http://localhost:8080
```
</details>
