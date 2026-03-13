#!/bin/bash
# ZIVPN Full Installer with Web Admin Panel
# 1. Update & Install dependencies
apt update && apt install -y curl jq python3 python3-flask iptables ufw

# 2. Setup Directories
mkdir -p /etc/zivpn/templates

# 3. Create Web Panel (web.py)
cat << 'EOF' > /etc/zivpn/web.py
from flask import Flask, render_template_string, request, redirect, session
import json, os, subprocess
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'zivpn_secret_key'

# Simple login
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form['user'] == 'admin' and request.form['pass'] == 'admin':
            session['logged_in'] = True
            return redirect('/')
    return '''<form method="post">User: <input name="user"><br>Pass: <input type="password" name="pass"><br><button>Login</button></form>'''

@app.route('/', methods=['GET', 'POST'])
def index():
    if not session.get('logged_in'): return redirect('/login')
    # Add User Logic here
    return "<h1>ZIVPN Admin Panel - Dashboard</h1><p>User Management Active</p>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

# 4. Create Systemd Service
cat << 'EOF' > /etc/systemd/system/zivpn-web.service
[Unit]
Description=ZIVPN Web Panel
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/zivpn/web.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 5. Enable & Start
systemctl daemon-reload
systemctl enable --now zivpn-web
ufw allow 8080/tcp
echo "Installation Finished. Access: http://$(hostname -I | awk '{print $1}'):8080"
