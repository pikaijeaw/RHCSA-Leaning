# บทที่ 09 (บทเสริม) — Containers ด้วย Podman

> **สถานะในข้อสอบ:** แหล่งข้อมูลส่วนใหญ่ระบุว่า **หัวข้อ containers ถูกถอดออกจาก EX200 เวอร์ชัน RHEL 10 แล้ว**
> ถ้าเวลาเตรียมสอบน้อย ข้ามบทนี้ได้ แต่ถ้ามีเวลาควรอ่าน เพราะใช้ในงานจริงทุกวัน และยังเป็นพื้นฐานของ RHCE (EX294)
> ก่อนสอบให้เช็กที่หน้า objectives ของ Red Hat อีกครั้ง

## 1. หลักการ

- **Image** = แม่แบบ (อ่านอย่างเดียว) เช่น `registry.access.redhat.com/ubi10/ubi`
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
podman pull registry.access.redhat.com/ubi10/ubi
podman images
podman inspect registry.access.redhat.com/ubi10/ubi
skopeo inspect docker://registry.access.redhat.com/ubi10/ubi   # ดูโดยไม่ต้อง pull

podman run -it --name test registry.access.redhat.com/ubi10/ubi /bin/bash
podman run -d --name web -p 8080:8080 registry.access.redhat.com/ubi10/httpd-24
podman ps ; podman ps -a
podman logs web
podman exec -it web /bin/bash
podman stop web ; podman start web
podman rm -f web
podman rmi <image>
```

> ชื่อ image ของ UBI 10 อาจเปลี่ยนตามรอบ release ถ้า pull ไม่เจอ ให้ใช้ `podman search registry.access.redhat.com/ubi10` หรือใช้ `ubi9` แทน (รันบน RHEL 10 ได้)

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
FROM registry.access.redhat.com/ubi10/ubi
RUN dnf install -y httpd && dnf clean all
COPY index.html /var/www/html/
EXPOSE 80
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]
```

```bash
podman build -t myweb:1.0 ~/myimg
```

---

## 3. ให้ container เปิดอัตโนมัติตอนบูต: Quadlet (วิธีปัจจุบัน)

`podman generate systemd` ถูกประกาศเลิกใช้ (deprecated) แล้ว วิธีที่ Red Hat แนะนำคือ **Quadlet** ซึ่งให้เขียนไฟล์ `.container` สั้น ๆ แล้ว systemd จะสร้าง service ให้เอง

> **ตัวอย่าง:** ในฐานะ user `athena` รัน container `web` จาก httpd image map port 8080
> mount `~/html` ไปที่ `/var/www/html` และให้เริ่มอัตโนมัติตอนบูต แม้ athena ไม่ได้ login

ต้องเข้าเป็น athena ผ่าน **`ssh athena@localhost`** (อย่าใช้ `su -` เพราะจะไม่มี user session ของ systemd ทำให้ `systemctl --user` ใช้ไม่ได้)

```bash
# ในฐานะ root
loginctl enable-linger athena          # ให้ service ของ athena ทำงานแม้ไม่ login

ssh athena@localhost
mkdir -p ~/html ~/.config/containers/systemd
echo "Hello Quadlet" > ~/html/index.html

cat > ~/.config/containers/systemd/web.container <<'EOF'
[Unit]
Description=Web container

[Container]
ContainerName=web
Image=registry.access.redhat.com/ubi10/httpd-24
PublishPort=8080:8080
Volume=%h/html:/var/www/html:Z

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload          # Quadlet สร้าง web.service ให้ตรงนี้
systemctl --user start web.service      # ไม่ต้อง enable: [Install] ในไฟล์ .container ทำหน้าที่นี้แล้ว
systemctl --user status web.service
curl http://localhost:8080
```

- `%h` = home directory ของ user
- ไฟล์ของ root (container ระดับระบบ) ใส่ที่ `/etc/containers/systemd/`
- ถ้า service ไม่ถูกสร้าง ตรวจ syntax ด้วย `/usr/libexec/podman/quadlet -dryrun -user`
- รายละเอียดทั้งหมด: `man podman-systemd.unit`

---

## 🧪 Lab 09

1. สร้าง user `athena` ตั้ง password
2. ในฐานะ athena สร้าง Quadlet ชื่อ `web` จาก httpd image map port 8080 ของ host ไปยัง 8080 ใน container
3. mount `~/html` (มีไฟล์ `index.html`) ไปที่ `/var/www/html` ใน container
4. ให้ container เริ่มอัตโนมัติหลัง reboot
5. Reboot แล้ว `curl http://localhost:8080`

<details>
<summary>เฉลย Lab 09</summary>

ทำตามตัวอย่างในหัวข้อ 3 ทั้งหมด แล้ว:

```bash
# ในฐานะ root ถ้าจะเข้าจากเครื่องอื่น
firewall-cmd --permanent --add-port=8080/tcp && firewall-cmd --reload
reboot
# หลังบูต (ไม่ต้อง login เป็น athena)
curl http://localhost:8080
```
</details>
