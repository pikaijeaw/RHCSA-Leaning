#!/bin/bash
# เตรียมสถานการณ์สำหรับข้อสอบจำลองชุดที่ 2 บน servera (รันเป็น root ก่อนเริ่มทำข้อสอบ)
# ⚠ สปอยล์: อย่าเปิดอ่านไฟล์นี้ก่อนทำข้อสอบเสร็จ
# usage: bash setup-exam2.sh

set -e
[ "$(id -u)" -eq 0 ] || { echo "ต้องรันเป็น root"; exit 1; }

# ---- B3: web server ที่ DocumentRoot = /srv/web แต่ SELinux context ผิด ----
dnf install -y httpd policycoreutils-python-utils >/dev/null
sed -i 's#/var/www/html#/srv/web#g' /etc/httpd/conf/httpd.conf
mkdir -p /srv/web
echo "<h1>exam2 web OK</h1>" > /root/index.html
mv /root/index.html /srv/web/index.html          # พา context admin_home_t ติดไปด้วย
systemctl disable --now httpd 2>/dev/null || true
firewall-cmd --permanent --remove-service=http >/dev/null 2>&1 || true
firewall-cmd --reload >/dev/null

# ---- B19: process ที่กิน CPU ----
cat > /usr/local/bin/cpuhog <<'EOF'
#!/bin/bash
while :; do :; done
EOF
chmod +x /usr/local/bin/cpuhog
nohup /usr/local/bin/cpuhog >/dev/null 2>&1 &

echo "เตรียมข้อสอบชุดที่ 2 เสร็จแล้ว เริ่มจับเวลาได้"
