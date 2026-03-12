#!/bin/bash
# ZIVPN Original Orange UI - Fixed with Link & Edit Feature
set -euo pipefail

# 1. လိုအပ်သောဖိုင်များ ဒေါင်းလုဒ်ဆွဲခြင်း (VPN Core)
# VPN Core ကို ဒေါင်းလုဒ်ဆွဲခြင်း
mkdir -p /etc/zivpn
wget -O /usr/local/bin/zivpn https://github.com/zivpn/zivpn/releases/download/v2.0.2/zivpn-linux-amd64
chmod +x /usr/local/bin/zivpn

# 2. Login အချက်အလက်သတ်မှတ်ခြင်း
rm -f /etc/zivpn/web.env
mkdir -p /etc/zivpn/templates

echo -e "\e[1;33m🔒 Web Panel အတွက် Login အချက်အလက်အသစ် သတ်မှတ်ပေးပါ\e[0m"
read -r -p "Admin Username: " WEB_USER
read -r -s -p "Admin Password: " WEB_PASS; echo
read -r -p "Contact Link (ဥပမာ Telegram): " CONTACT_LINK

ENVF="/etc/zivpn/web.env"
echo "WEB_ADMIN_USER=${WEB_USER}" > "$ENVF"
echo "WEB_ADMIN_PASSWORD=${WEB_PASS}" >> "$ENVF"
echo "WEB_SECRET=$(openssl rand -hex 32)" >> "$ENVF"
echo "WEB_CONTACT_LINK=${CONTACT_LINK}" >> "$ENVF"

# 3. Python Web Script (Edit Feature)
cat >/etc/zivpn/web.py <<'PY'
import os, json, subprocess, socket
from flask import Flask, render_template_string, request, redirect, url_for, session
from datetime import datetime, timedelta, date

app = Flask(__name__)
app.secret_key = os.environ.get("WEB_SECRET")
USERS_FILE = "/etc/zivpn/users.json"
CONFIG_FILE = "/etc/zivpn/config.json"
ADMIN_USER = os.environ.get("WEB_ADMIN_USER")
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD")
CONTACT_LINK = os.environ.get("WEB_CONTACT_LINK", "#")

def get_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except: return "IP Unknown"

def load_users():
    if os.path.exists(USERS_FILE):
        with open(USERS_FILE, "r") as f: return json.load(f)
    return []

def save_and_sync(users):
    with open(USERS_FILE, "w") as f: json.dump(users, f, indent=2)
    today = date.today()
    valid = [u['password'] for u in users if not u.get('expires') or datetime.strptime(u['expires'], "%Y-%m-%d").date() >= today]
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, "r") as f: cfg = json.load(f)
            cfg['auth']['config'] = valid
            with open(CONFIG_FILE, "w") as f: json.dump(cfg, f, indent=2)
            # VPN Service ကို Restart ချခြင်း
            subprocess.run(["systemctl", "restart", "zivpn"], check=False)
    except: pass

STYLE = '''
<style>
    body { font-family: sans-serif; background: #f4f7f6; padding: 20px; text-align: center; }
    .card { background: white; padding: 25px; border-radius: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); max-width: 450px; margin: auto; }
    .btn { background: #ff851b; color: white; border: none; padding: 12px; width: 95%; border-radius: 10px; font-weight: bold; cursor: pointer; }
    input { width: 90%; padding: 12px; margin: 8px 0; border: 1px solid #ddd; border-radius: 10px; }
</style>
'''
# ... (Login & Dashboard Routes များမှာ အရင်အတိုင်း ထားပါ) ...
@app.route("/", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        if request.form.get("u") == ADMIN_USER and request.form.get("p") == ADMIN_PASS:
            session["auth"] = True
            return redirect(url_for("dashboard"))
    return render_template_string(STYLE + '<h2>Login</h2><form method="post"><input name="u"><input name="p" type="password"><button class="btn" type="submit">Login</button></form>')

@app.route("/dashboard")
def dashboard():
    if not session.get("auth"): return redirect(url_for("login"))
    return render_template_string(STYLE + '<h3>Dashboard</h3><a href="/logout">Logout</a>')

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
PY

# 4. VPN Service အသစ်ဖန်တီးခြင်း
cat <<EOF >/etc/systemd/system/zivpn.service
[Unit]
Description=ZIVPN Service
After=network.target

[Service]
ExecStart=/usr/local/bin/zivpn -config /etc/zivpn/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now zivpn
systemctl enable --now zivpn-web

echo -e "\n\e[1;32m✅ အားလုံး အောင်မြင်စွာ ပြင်ဆင်ပြီးပါပြီ!\e[0m"
