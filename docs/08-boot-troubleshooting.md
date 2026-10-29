# บทที่ 08 — Boot Process และ Troubleshooting

## 1. หลักการ: เครื่องบูตอย่างไร

```
BIOS/UEFI → GRUB2 (bootloader) → Kernel + initramfs → systemd (PID 1) → default.target → login
```

1. **Firmware** (BIOS/UEFI) ตรวจ hardware แล้วหา bootloader
2. **GRUB2** แสดงเมนูเลือก kernel และส่ง **kernel arguments** ให้ kernel
3. **Kernel** โหลด driver จาก **initramfs** แล้ว mount `/` (root filesystem)
4. **systemd** เริ่ม service ทั้งหมดตาม target (เช่น `graphical.target`) และ mount ทุกอย่างใน `/etc/fstab`

ถ้าแก้ GRUB ที่หน้าเมนูได้ (กด `e`) เราสามารถเปลี่ยน kernel argument ชั่วคราวเพื่อเข้าไปซ่อมระบบได้

---

## 2. Reset root password (ออกสอบเป็นข้อแรกบ่อยมาก)

> **โจทย์:** "ตั้ง root password ของ node2 เป็น `trootent`" (โดยที่คุณไม่รู้ password เดิม)

### วิธีที่ 1: `rd.break` (วิธีมาตรฐาน)

1. Reboot เครื่อง ที่เมนู GRUB กดลูกศรขึ้น/ลงเพื่อหยุดการนับถอยหลัง
2. เลือก kernel ตัวบน กด **`e`**
3. หาบรรทัดที่ขึ้นต้นด้วย **`linux`** ไปท้ายบรรทัด (กด `Ctrl+e`) แล้วเพิ่ม **`rd.break`**
   (ถ้ามี `console=ttyS0...` ให้ลบออก จะได้เห็น prompt บนหน้าจอ)
4. กด **`Ctrl+x`** เพื่อบูต
5. จะได้ prompt `switch_root:/#` แล้วพิมพ์:

```bash
mount -o remount,rw /sysroot     # / จริงถูก mount ที่ /sysroot แบบอ่านอย่างเดียว
chroot /sysroot                  # เข้าไปใน / จริง
passwd root                      # ตั้ง password ใหม่
# หรือ: echo trootent | passwd --stdin root
touch /.autorelabel              # ⚠ ห้ามลืม! ให้ SELinux relabel ไฟล์ /etc/shadow
exit                             # ออกจาก chroot
exit                             # บูตต่อ (หรือ reboot -f)
```

> **ถ้าลืม `touch /.autorelabel`** : `/etc/shadow` จะมี SELinux context ผิด → login ไม่ได้เลย (แม้ password ถูก)
> การบูตหลัง relabel จะช้ากว่าปกติ และเครื่องอาจ reboot เองหนึ่งรอบ ถือว่าปกติ

### วิธีที่ 2: `init=/bin/bash`

เพิ่ม `init=/bin/bash` ท้ายบรรทัด `linux` แทน `rd.break` แล้ว:

```bash
mount -o remount,rw /
passwd root
touch /.autorelabel
exec /sbin/init        # หรือ /usr/sbin/reboot -f
```

---

## 3. Rescue และ Emergency target

เพิ่มท้ายบรรทัด `linux` ใน GRUB:

| Argument | ผล | ใช้เมื่อ |
|---|---|---|
| `systemd.unit=rescue.target` | single-user, mount filesystem ครบ | service บางตัวทำให้บูตค้าง |
| `systemd.unit=emergency.target` | mount `/` แบบ read-only อย่างเดียว | **`/etc/fstab` ผิด** |

ทั้งสองโหมดต้องใส่ root password

### แก้ปัญหา fstab ผิดจนบูตไม่ขึ้น

อาการ: บูตแล้วค้างที่ "A start job is running for /dev/..." แล้วเข้า emergency mode

```bash
# ใส่ root password แล้ว:
mount -o remount,rw /
vim /etc/fstab            # แก้หรือ comment บรรทัดที่ผิด
systemctl daemon-reload
mount -a                  # ต้องไม่มี error
reboot
```

---

## 4. ตั้งค่า GRUB ถาวร

```bash
# วิธีแนะนำบน RHEL 9: grubby
grubby --default-kernel
grubby --info=ALL | grep -E 'kernel|args'
grubby --update-kernel=ALL --args="quiet"
grubby --update-kernel=ALL --remove-args="rhgb"
grubby --set-default /boot/vmlinuz-<version>

# วิธีแก้ไฟล์
vim /etc/default/grub          # เช่น GRUB_TIMEOUT=10
grub2-mkconfig -o /boot/grub2/grub.cfg
```

---

## 5. Troubleshooting checklist

| อาการ | ตรวจด้วย |
|---|---|
| Service ไม่ทำงาน | `systemctl status x`, `journalctl -u x -e` |
| Permission denied ทั้งที่ chmod ถูก | SELinux: `ausearch -m AVC -ts recent`, `ls -Z` |
| เข้าเว็บจากเครื่องอื่นไม่ได้ แต่ local ได้ | firewall: `firewall-cmd --list-all` |
| เปิด service ที่ port แปลก ๆ ไม่ได้ | `semanage port -l` |
| ดิสก์เต็ม | `df -h`, `du -sh /var/* \| sort -h` |
| บูตไม่ขึ้นหลังแก้ fstab | emergency target |
| ลืม root password | `rd.break` |

---

## 🧪 Lab 08

1. Reset root password ของ servera เป็น `redhat123` ด้วยวิธี `rd.break`
2. ใส่บรรทัดผิดลงใน fstab โดยตั้งใจ: `echo "/dev/vdz1 /broken xfs defaults 0 0" >> /etc/fstab` แล้ว reboot จากนั้นกู้ระบบให้บูตได้
3. ตั้งให้ kernel ทุกตัวไม่มี argument `rhgb` และตั้ง GRUB timeout เป็น 10 วินาที

<details>
<summary>เฉลย Lab 08</summary>

1. ตามขั้นตอนในหัวข้อ 2 ตรวจด้วยการ login เป็น root ด้วย password ใหม่
2. ใส่ root password ใน emergency mode → `mount -o remount,rw /` → ลบบรรทัด `/dev/vdz1` ใน `/etc/fstab` → `systemctl daemon-reload` → `mount -a` → `reboot`
3. ใช้คำสั่งต่อไปนี้

```bash
grubby --update-kernel=ALL --remove-args="rhgb"
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
```
</details>
