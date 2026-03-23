#!/bin/bash
# ZIVPN UDP Server + Web UI - Auto Copy Popup & Easy Image Upload Feature
set -euo pipefail

# ===== Pretty =====
B="\e[1;34m"; G="\e[1;32m"; Y="\e[1;33m"; R="\e[1;31m"; C="\e[1;36m"; Z="\e[0m"
LINE="${B}────────────────────────────────────────────────────────${Z}"
say(){ 
    echo -e "\n$LINE"
    echo -e "${G}ZIVPN UDP Server + Web UI (Neon Theme & Auto Copy Popup)${Z}"
    echo -e "$LINE\n"
}
say 

# ===== Root check =====
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${R}ဤ script ကို root အဖြစ် run ရပါမယ် (sudo -i)${Z}"; exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# ===== apt guards =====
wait_for_apt() {
  echo -e "${Y}⏳ apt ကို စောင့်ပါ...${Z}"
  for _ in $(seq 1 60); do
    if pgrep -x apt-get >/dev/null || pgrep -x apt >/dev/null || pgrep -f 'apt.systemd.daily' >/dev/null || pgrep -x unattended-upgrade >/dev/null; then
      sleep 5
    else
      return 0
    fi
  done
  systemctl stop --now unattended-upgrades.service 2>/dev/null || true
  systemctl stop --now apt-daily.service apt-daily.timer 2>/dev/null || true
  systemctl stop --now apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true
}

apt_guard_start(){
  wait_for_apt
  CNF_CONF="/etc/apt/apt.conf.d/50command-not-found"
  if [ -f "$CNF_CONF" ]; then mv "$CNF_CONF" "${CNF_CONF}.disabled"; CNF_DISABLED=1; else CNF_DISABLED=0; fi
}

apt_guard_end(){
  dpkg --configure -a >/dev/null 2>&1 || true
  apt-get -f install -y >/dev/null 2>&1 || true
  if [ "${CNF_DISABLED:-0}" = "1" ] && [ -f "${CNF_CONF}.disabled" ]; then mv "${CNF_CONF}.disabled" "$CNF_CONF"; fi
}

# ===== Packages =====
echo -e "${Y}📦 Packages တင်နေပါတယ်...${Z}"
apt_guard_start
apt-get update -y -o APT::Update::Post-Invoke-Success::= -o APT::Update::Post-Invoke::= >/dev/null
apt-get install -y curl ufw jq python3 python3-flask python3-apt iproute2 conntrack ca-certificates >/dev/null || {
  apt-get install -y -o DPkg::Lock::Timeout=60 python3-apt >/dev/null || true
  apt-get install -y curl ufw jq python3 python3-flask iproute2 conntrack ca-certificates >/dev/null
}
apt_guard_end

systemctl stop zivpn.service 2>/dev/null || true
systemctl stop zivpn-web.service 2>/dev/null || true

# ===== Paths and setup directories =====
BIN="/usr/local/bin/zivpn"
CFG="/etc/zivpn/config.json"
USERS="/etc/zivpn/users.json"
ENVF="/etc/zivpn/web.env"
TEMPLATES_DIR="/etc/zivpn/templates" 
mkdir -p /etc/zivpn "$TEMPLATES_DIR" 

# --- ZIVPN Binary, Config, Certs ---
echo -e "${Y}⬇️ ZIVPN binary ကို ဒေါင်းနေပါတယ်...${Z}"
PRIMARY_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
FALLBACK_URL="https://github.com/zahidbd2/udp-zivpn/releases/latest/download/udp-zivpn-linux-amd64"
TMP_BIN="$(mktemp)"
if ! curl -fsSL -o "$TMP_BIN" "$PRIMARY_URL"; then
  curl -fSL -o "$TMP_BIN" "$FALLBACK_URL"
fi
install -m 0755 "$TMP_BIN" "$BIN"
rm -f "$TMP_BIN"

if [ ! -f "$CFG" ]; then
  curl -fsSL -o "$CFG" "https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json" || echo '{}' > "$CFG"
fi

if [ ! -f /etc/zivpn/zivpn.crt ] || [ ! -f /etc/zivpn/zivpn.key ]; then
  openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=MM/ST=Yangon/L=Yangon/O=M-69P/OU=Net/CN=zivpn" \
    -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt" >/dev/null 2>&1
fi

# --- Web Admin Login, VPN Passwords ---
echo -e "${G}🔒 Web Admin Login UI ထည့်မလား..?${Z}"
read -r -p "Web Admin Username (Enter=disable): " WEB_USER
if [ -n "${WEB_USER:-}" ]; then
  read -r -s -p "Web Admin Password: " WEB_PASS; echo
  read -r -p "Contact Link (ဥပမာ: https://m.me/zaw or Enter=disable): " CONTACT_LINK
  
  if command -v openssl >/dev/null 2>&1; then WEB_SECRET="$(openssl rand -hex 32)"
  else WEB_SECRET="$(python3 -c 'import secrets;print(secrets.token_hex(32))')"; fi
  {
    echo "WEB_ADMIN_USER=${WEB_USER}"
    echo "WEB_ADMIN_PASSWORD=${WEB_PASS}"
    echo "WEB_SECRET=${WEB_SECRET}"
    echo "WEB_CONTACT_LINK=${CONTACT_LINK:-}" 
  } > "$ENVF"
  chmod 600 "$ENVF"
  echo -e "${G}✅ Web login UI ဖွင့်ထားပါတယ်${Z}"
else
  rm -f "$ENVF" 2>/dev/null || true
  echo -e "${Y}ℹ️ Web login UI မဖွင့်ထားပါ${Z}"
fi

echo -e "${G}🔏 VPN Password List (ကော်မာဖြင့်ခွဲ) eg: zi,zaw,lay${Z}"
read -r -p "Passwords (Enter=zi): " input_pw
if [ -z "${input_pw:-}" ]; then PW_LIST='["zi"]'; else
  PW_LIST=$(echo "$input_pw" | awk -F',' '{
    printf("["); for(i=1;i<=NF;i++){gsub(/^ *| *$/,"",$i); printf("%s\"%s\"", (i>1?",":""), $i)}; printf("]")
  }')
fi

if jq . >/dev/null 2>&1 <<<'{}'; then
  TMP=$(mktemp)
  jq --argjson pw "$PW_LIST" '
    .auth.mode = "passwords" |
    .auth.config = $pw |
    .listen = (."listen" // ":5667") |
    .cert = (."cert" // "/etc/zivpn/zivpn.crt") |
    .key  = (."key" // "/etc/zivpn/zivpn.key")
  ' "$CFG" > "$TMP" && mv "$TMP" "$CFG"
fi
[ -f "$USERS" ] || echo "[]" > "$USERS"
chmod 644 "$CFG" "$USERS"

# --- Systemd Service ---
cat >/etc/systemd/system/zivpn.service <<'EOF'
[Unit]
Description=ZIVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# 💡 HTML: users_table.html (Unchanged from previous Neon)
cat >"$TEMPLATES_DIR/users_table.html" <<'TABLE_HTML'
<div class="table-container">
    <table>
      <thead><tr><th><i class="icon">👤</i> User</th><th><i class="icon">🔑</i> Password</th><th><i class="icon">⏰</i> Expires</th><th><i class="icon">🚦</i> Status</th><th><i class="icon">❌</i> Action</th></tr></thead>
      <tbody>
          {% for u in users %}
          <tr class="{% if u.expires and u.expires_date < today_date %}expired{% elif u.expiring_soon %}expiring-soon{% endif %}">
            <td data-label="User">{% if u.expires and u.expires_date < today_date %}<s>{{u.user}}</s>{% else %}{{u.user}}{% endif %}</td>
            <td data-label="Password">{% if u.expires and u.expires_date < today_date %}<s>{{u.password}}</s>{% else %}{{u.password}}{% endif %}</td>
            <td data-label="Expires">
                {% if u.expires %}
                    {% if u.expires_date < today_date %}<s>{{u.expires}} (Expired)</s>
                    {% else %}
                        <span class="{% if u.expiring_soon %}text-expiring{% endif %}">{{u.expires}}</span>
                        <br><span class="days-remaining">(ကျန်ရှိ: {% if u.days_remaining == 0 %}<span class="text-expiring">ဒီနေ့ နောက်ဆုံး</span>{% else %}{{ u.days_remaining }} ရက်{% endif %})</span>
                    {% endif %}
                {% else %}<span class="muted">—</span>{% endif %}
            </td>
            <td data-label="Status">
                {% if u.expires and u.expires_date < today_date %}<span class="pill pill-expired"><i class="icon">🛑</i> Expired</span>
                {% elif u.expiring_soon %}<span class="pill pill-expiring"><i class="icon">⚠️</i> Expiring Soon</span>
                {% else %}<span class="pill ok"><i class="icon">🟢</i> Active</span>{% endif %}
            </td>
            <td data-label="Action">
              <button type="button" class="btn-edit" onclick="showEditModal('{{ u.user }}', '{{ u.password }}', '{{ u.expires }}')"><i class="icon">✏️</i> Edit</button>
              <form class="delform" method="post" action="/delete" onsubmit="return confirm('{{u.user}} ကို ဖျက်မလား?')">
                <input type="hidden" name="user" value="{{u.user}}"><button type="submit" class="btn-delete"><i class="icon">🗑️</i> Delete</button>
              </form>
            </td>
          </tr>
          {% endfor %}
      </tbody>
    </table>
</div>

<div id="editModal" class="modal">
  <div class="modal-content">
    <span class="close-btn" onclick="document.getElementById('editModal').style.display='none'">&times;</span>
    <h2 class="section-title"><i class="icon">✏️</i> Edit Account</h2>
    <form method="post" action="/edit">
        <input type="hidden" id="edit-user" name="user">
        <div class="input-group">
            <label class="input-label"><i class="icon">👤</i> User Name</label>
            <div class="input-field-wrapper is-readonly"><input type="text" id="current-user-display" readonly></div>
        </div>
        <div class="input-group">
            <label class="input-label"><i class="icon">🔒</i> Password</label>
            <div class="input-field-wrapper"><input type="text" id="new-password" name="password" required></div>
        </div>
        <div class="input-group">
            <label class="input-label"><i class="icon">🗓️</i> Expiry Date</label>
            <div class="input-field-wrapper"><input type="text" id="new-expires" name="expires" required></div>
        </div>
        <button class="save-btn modal-save-btn" type="submit">ပြင်ဆင်ချက် သိမ်းမည်</button>
    </form>
  </div>
</div>

<style>
.modal-content { background-color: var(--card-bg); margin: 15% auto; padding: 25px; border: 1px solid var(--border-color); width: 90%; max-width: 320px; border-radius: 12px; position: relative; box-shadow: 0 10px 40px rgba(0, 229, 255, 0.15); }
.close-btn { color: var(--secondary); position: absolute; top: 8px; right: 15px; font-size: 32px; font-weight: 300; transition: color 0.2s; line-height: 1; cursor: pointer;}
.close-btn:hover { color: var(--danger); }
.section-title { margin-top: 0; padding-bottom: 10px; border-bottom: 1px solid var(--border-color); color: var(--primary); text-shadow: 0 0 10px rgba(0, 229, 255, 0.3);}
.modal .input-group { margin-bottom: 20px; }
.modal .input-label { display: block; text-align: left; font-weight: 600; color: #fff; font-size: 0.9em; margin-bottom: 5px; }
.modal .input-field-wrapper { display: flex; align-items: center; border: 1px solid var(--border-color); border-radius: 8px; background-color: var(--bg-color); }
.modal .input-field-wrapper.is-readonly { background-color: var(--light); opacity: 0.8; }
.modal .input-field-wrapper input { width: 100%; padding: 12px 10px; border: none; font-size: 16px; outline: none; background: transparent; color: #fff; }
.modal-save-btn { width: 100%; padding: 12px; background-color: var(--primary); color: #0b0f19; border: none; border-radius: 8px; font-size: 1.0em; cursor: pointer; font-weight: bold; box-shadow: 0 0 10px rgba(0, 229, 255, 0.4);}
.btn-edit { background-color: rgba(0, 229, 255, 0.1); color: var(--primary); border: 1px solid rgba(0, 229, 255, 0.3); padding: 6px 10px; border-radius: 8px; cursor: pointer; font-size: 0.9em; margin-right: 5px; }
@media (max-width: 768px) { td[data-label="Action"] { display: flex; justify-content: flex-end; align-items: center; } }
</style>
<script>
    function showEditModal(user, password, expires) {
        document.getElementById('edit-user').value = user; document.getElementById('current-user-display').value = user;
        document.getElementById('new-password').value = password; document.getElementById('new-expires').value = expires;
        document.getElementById('editModal').style.display = 'block';
    }
</script>
TABLE_HTML

# 💡 HTML: users_table_wrapper.html
cat >"$TEMPLATES_DIR/users_table_wrapper.html" <<'WRAPPER_HTML'
<!doctype html>
<html lang="my"><head><meta charset="utf-8">
<title>ZIVPN User Panel - Users</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root { --primary: #00e5ff; --primary-dark: #00b8d4; --secondary: #90a4ae; --success: #00e676; --danger: #ff1744; --light: #263238; --dark: #eceff1; --bg-color: #0b0f19; --card-bg: #111827; --border-color: #1f2937; --warning: #ffea00; --warning-bg: rgba(255, 234, 0, 0.15); }
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: var(--bg-color); line-height: 1.6; color: var(--dark); margin: 0; padding: 0; padding-bottom: 70px; }
.icon { font-style: normal; margin-right: 5px; }
.main-header { display: flex; justify-content: space-between; align-items: center; background-color: var(--card-bg); padding: 10px 15px; border-bottom: 1px solid var(--border-color); margin-bottom: 15px; position: sticky; top: 0; z-index: 1000; }
.header-logo a { font-size: 1.6em; font-weight: bold; color: var(--primary); text-decoration: none; text-shadow: 0 0 8px rgba(0, 229, 255, 0.4);}
.bottom-nav { display: flex; justify-content: space-around; align-items: center; position: fixed; bottom: 0; width: 100%; background-color: rgba(17, 24, 39, 0.95); backdrop-filter: blur(10px); border-top: 1px solid var(--border-color); z-index: 1000; padding: 5px 0; }
.bottom-nav a { display: flex; flex-direction: column; align-items: center; text-decoration: none; color: var(--secondary); font-size: 0.75em; padding: 8px; border-radius: 6px; }
.bottom-nav a.active { color: var(--primary); text-shadow: 0 0 5px rgba(0, 229, 255, 0.5);}
.bottom-nav a.active i.icon { color: var(--primary); }
.table-container { padding: 0 10px; margin: 0 auto; max-width: 100%; } 
table { width: 100%; border-collapse: separate; border-spacing: 0; margin-top: 15px; background-color: var(--card-bg); border-radius: 8px; border: 1px solid var(--border-color);}
th, td { padding: 10px; text-align: left; border-bottom: 1px solid var(--border-color); font-size: 0.9em; color: var(--dark);}
th { background-color: #1a2235; color: var(--primary); font-weight: 600; text-transform: uppercase; font-size: 0.8em; } 
tr:nth-child(even) { background-color: #141c2b; }
@media (max-width: 768px) {
    .table-container { padding: 0 5px; } table, thead, tbody, th, td, tr { display: block; border: none;}
    thead { display: none; } tr { background-color: var(--card-bg) !important; border: 1px solid var(--border-color); margin-bottom: 15px; border-radius: 8px; }
    td { position: relative; padding-left: 45%; text-align: right; border-bottom: 1px dashed var(--border-color); }
    td:before { content: attr(data-label); position: absolute; left: 0; width: 40%; padding-left: 10px; font-weight: bold; text-align: left; color: var(--primary); font-size: 0.9em; }
    .delform { display: block; text-align: right; } .btn-delete { margin-top: 5px;}
}
.pill { padding: 6px 10px; border-radius: 15px; font-size: 0.85em; font-weight: bold; min-width: 90px; justify-content: center;}
.ok { background-color: rgba(0, 230, 118, 0.15); color: var(--success); border: 1px solid rgba(0, 230, 118, 0.3); } 
.pill-expired { background-color: rgba(255, 23, 68, 0.15); color: var(--danger); border: 1px solid rgba(255, 23, 68, 0.3); }
.pill-expiring { background-color: var(--warning-bg); color: var(--warning); border: 1px solid rgba(255, 234, 0, 0.3); } 
.text-expiring { color: var(--warning); font-weight: bold; } 
.days-remaining { font-size: 0.85em; color: var(--secondary); font-weight: 500; display: inline-block; margin-top: 2px; }
.btn-delete { background-color: rgba(255, 23, 68, 0.1); color: var(--danger); border: 1px solid rgba(255, 23, 68, 0.3); padding: 8px 12px; border-radius: 8px; cursor: pointer; font-size: 0.9em; }
.modal { display: none; position: fixed; z-index: 3000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(11, 15, 25, 0.8); }
</style>
</head><body>
    <header class="main-header"><div class="header-logo"><a href="/">ZIVPN<span style="color:#fff;"> Panel</span></a></div></header>
    {% include 'users_table.html' %}
    <nav class="bottom-nav">
        <a href="/"><i class="icon">➕</i><span>အကောင့်ထည့်ရန်</span></a>
        <a href="/users" class="active"><i class="icon">📜</i><span>အသုံးပြုသူ စာရင်း</span></a>
        <a href="/logout"><i class="icon">➡️</i><span>ထွက်ရန်</span></a>
    </nav>
</body></html>
WRAPPER_HTML

# 💡 Python Web Panel (web.py)
echo -e "${Y}🖥️ Web Panel (web.py) ကို စစ်ဆေးနေပါတယ်...${Z}"
cat >/etc/zivpn/web.py <<'PY'
from flask import Flask, jsonify, render_template, render_template_string, request, redirect, url_for, session, make_response
import json, re, subprocess, os, tempfile, hmac, base64
from datetime import datetime, timedelta, date

USERS_FILE = "/etc/zivpn/users.json"
CONFIG_FILE = "/etc/zivpn/config.json"
LOGO_PATH = "/etc/zivpn/logo.png"

def get_server_ip():
    try:
        result = subprocess.run(['hostname', '-I'], capture_output=True, text=True, check=True)
        return result.stdout.strip().split()[0]
    except Exception: return "127.0.0.1" 
SERVER_IP_FALLBACK = get_server_ip()
CONTACT_LINK = os.environ.get("WEB_CONTACT_LINK", "").strip()

# HTML Template
HTML = """<!doctype html>
<html lang="my"><head><meta charset="utf-8">
<title>ZIVPN User Panel</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root { --primary: #00e5ff; --primary-dark: #00b8d4; --secondary: #90a4ae; --success: #00e676; --danger: #ff1744; --light: #263238; --dark: #eceff1; --bg-color: #0b0f19; --card-bg: #111827; --border-color: #1f2937; }
body { font-family: 'Segoe UI', Tahoma, sans-serif; background-color: var(--bg-color); color: var(--dark); margin: 0; padding-bottom: 70px; }
.icon { font-style: normal; margin-right: 5px; }
.main-header { display: flex; justify-content: space-between; align-items: center; background-color: var(--card-bg); padding: 10px 15px; border-bottom: 1px solid var(--border-color); position: sticky; top: 0; z-index: 1000; }
.header-logo a { font-size: 1.6em; font-weight: bold; color: var(--primary); text-decoration: none; text-shadow: 0 0 8px rgba(0, 229, 255, 0.4);} 
.bottom-nav { display: flex; justify-content: space-around; position: fixed; bottom: 0; width: 100%; background: rgba(17, 24, 39, 0.95); backdrop-filter: blur(10px); border-top: 1px solid var(--border-color); z-index: 1000; padding: 5px 0; }
.bottom-nav a { display: flex; flex-direction: column; align-items: center; text-decoration: none; color: var(--secondary); font-size: 0.75em; padding: 8px; }
.bottom-nav a.active { color: var(--primary); }
.login-container, .boxa1 { background: var(--card-bg); padding: 30px 20px; border-radius: 12px; border: 1px solid var(--border-color); width: 90%; max-width: 400px; margin: 30px auto; text-align: center; box-shadow: 0 8px 30px rgba(0, 0, 0, 0.6); }
.boxa1 { max-width: 600px; margin-top: 15px; text-align: left; }
.info-card { background: rgba(0, 229, 255, 0.05); color: var(--primary); padding: 15px; border-radius: 8px; text-align: center; font-weight: bold; margin-bottom: 15px; border: 1px solid rgba(0, 229, 255, 0.2); }
.profile-image-container { display: inline-block; margin-bottom: 15px; border-radius: 50%; overflow: hidden; border: 3px solid var(--primary); box-shadow: 0 0 20px rgba(0, 229, 255, 0.5); position: relative; cursor: pointer; width: 90px; height: 90px; background: #000;}
.profile-image { width: 100%; height: 100%; object-fit: cover; }
.img-overlay { position: absolute; bottom: 0; width: 100%; background: rgba(0,0,0,0.6); color: #fff; font-size: 11px; padding: 4px 0; text-align: center; }
h1 { font-size: 24px; color: #fff; margin-bottom: 5px; }
.login-ip-display { font-size: 16px; color: var(--primary); font-weight: bold; margin-bottom: 25px; }
.input-group { margin-bottom: 15px; text-align: left; }
.input-field-wrapper { display: flex; align-items: center; border: 1px solid var(--border-color); border-radius: 8px; margin-Top: 5px; background: var(--bg-color); }
.input-field-wrapper input { width: 100%; padding: 12px 10px; border: none; background: transparent; color: #fff; outline:none; }
.save-btn { width: 100%; padding: 12px; background: var(--primary); color: #000; border: none; border-radius: 8px; font-size: 16px; font-weight: bold; cursor: pointer; margin-top: 20px; box-shadow: 0 0 10px rgba(0, 229, 255, 0.4); }
.err{ color: var(--danger); background: rgba(255, 23, 68, 0.1); border: 1px solid rgba(255, 23, 68, 0.3); padding: 10px; border-radius: 8px; margin-bottom: 15px; text-align: center; }

/* 💡 POPUP STYLES */
.copy-popup { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: var(--card-bg); border: 1px solid var(--primary); padding: 25px; border-radius: 12px; z-index: 3000; width: 85%; max-width: 320px; box-shadow: 0 0 40px rgba(0, 229, 255, 0.4); text-align: left; }
.copy-popup h3 { margin-top: 0; color: var(--success); border-bottom: 1px solid var(--border-color); padding-bottom: 10px; }
.copy-data { background: var(--bg-color); padding: 15px; border-radius: 8px; font-family: monospace; color: #fff; line-height: 1.8; margin-bottom: 15px; font-size: 1.1em;}
.btn-copy { background: var(--primary); color: #000; border: none; padding: 12px; width: 100%; border-radius: 8px; font-weight: bold; font-size: 1em; margin-bottom: 10px; cursor: pointer; }
.btn-close { background: transparent; color: var(--secondary); border: 1px solid var(--secondary); padding: 10px; width: 100%; border-radius: 8px; cursor: pointer; font-weight: bold;}
.overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); z-index: 2999; backdrop-filter: blur(3px);}
</style>
</head><body>

{% if new_account %}
<div class="overlay" id="popup-overlay"></div>
<div class="copy-popup" id="success-popup">
    <h3><i class="icon">✅</i> အကောင့်သစ် ရပါပြီ</h3>
    <div class="copy-data" id="copy-text-area">IP : {{ new_account.ip }}<br>User : {{ new_account.user }}<br>Pass : {{ new_account.password }}<br>Expired : {{ new_account.expires }}</div>
    <button class="btn-copy" onclick="copyAccountInfo()">📋 Copy ကူးမည်</button>
    <button class="btn-close" onclick="closePopup()">ပိတ်မည်</button>
</div>
<script>
    function copyAccountInfo() {
        const htmlText = document.getElementById('copy-text-area').innerHTML;
        const plainText = htmlText.replace(/<br\s*[\/]?>/gi, "\n");
        navigator.clipboard.writeText(plainText).then(() => {
            const btn = document.querySelector('.btn-copy');
            btn.innerHTML = "✅ Copy ကူးပြီးပါပြီ";
            btn.style.background = "var(--success)";
            setTimeout(() => { btn.innerHTML = "📋 Copy ကူးမည်"; btn.style.background = "var(--primary)"; }, 2000);
        }).catch(err => alert("Copy ဖုန်း setting ကြောင့် မရပါ။"));
    }
    function closePopup() {
        document.getElementById('success-popup').style.display = 'none';
        document.getElementById('popup-overlay').style.display = 'none';
    }
</script>
{% endif %}

{% if not authed %}
    <div class="login-container">
        <div class="profile-image-container"><img src="/logo.png" class="profile-image"></div>
        <h1>ZIVPN Panel</h1><br>
        {% if IP %}<p class="login-ip-display">Server IP: {{ IP }}</p>{% endif %}
        {% if err %}<div class="err">{{err}}</div>{% endif %} 
        <form action="/login" method="POST">
            <div class="input-group"><div class="input-field-wrapper"><i class="icon">🔑</i><input type="text" name="u" placeholder="Username" required></div></div>
            <div class="input-group"><div class="input-field-wrapper"><i class="icon">🔒</i><input type="password" name="p" placeholder="Password" required></div></div>
            <button type="submit" class="save-btn">Login</button>
        </form>
    </div>
{% else %}
   <header class="main-header"><div class="header-logo"><a href="/">ZIVPN<span style="color:#fff;"> Panel</span></a></div></header>
   <div class="boxa1" style="text-align: center;">
        
        <form action="/upload_logo" method="post" enctype="multipart/form-data" id="logoForm" style="display:none;">
            <input type="file" name="logo" id="logoInput" accept="image/*" onchange="document.getElementById('logoForm').submit()">
        </form>
        <div class="profile-image-container" onclick="document.getElementById('logoInput').click()" title="ပုံပြောင်းရန် နှိပ်ပါ">
            <img src="/logo.png" class="profile-image">
            <div class="img-overlay">ပုံပြောင်းရန်နှိပ်ပါ</div>
        </div>

        <div class="info-card"><i class="icon">💡</i> လက်ရှိ Member: <span style="color:#fff;">{{ total_users }}</span> ယောက်</div>
        
        <form method="post" action="/add" style="text-align: left;">
            <h2 style="color:var(--primary); font-size:18px;"><i class="icon">➕</i> Add new user</h2>
            {% if err %}<div class="err">{{err}}</div>{% endif %}
            <div class="input-group"><div class="input-field-wrapper"><i class="icon">👤</i><input type="text" name="user" placeholder="Username" required></div></div>
            <div class="input-group"><div class="input-field-wrapper"><i class="icon">🔑</i><input type="text" name="password" placeholder="Password" required></div></div>
            <div class="input-group"><div class="input-field-wrapper"><i class="icon">🗓️</i><input type="text" name="expires" required placeholder="ရက်ပေါင်း (ဥပမာ: 30) သို့ 2025-12-31"></div></div>
            <div class="input-group"><div class="input-field-wrapper"><i class="icon">📡</i><input type="text" name="ip" value="{{ IP }}" readonly style="color:var(--primary); font-weight:bold;"></div></div>
            <button class="save-btn" type="submit">Create Account</button>
        </form>
    </div>
    <nav class="bottom-nav">
        <a href="/" class="active"><i class="icon">➕</i><span>အကောင့်ထည့်ရန်</span></a>
        <a href="/users"><i class="icon">📜</i><span>အသုံးပြုသူ စာရင်း</span></a>
        <a href="/logout"><i class="icon">➡️</i><span>ထွက်ရန်</span></a>
    </nav>
{% endif %}
</body></html>"""

app = Flask(__name__, template_folder="/etc/zivpn/templates")
app.secret_key = os.environ.get("WEB_SECRET","dev-secret-change-me")
ADMIN_USER = os.environ.get("WEB_ADMIN_USER","").strip()
ADMIN_PASS = os.environ.get("WEB_ADMIN_PASSWORD","").strip()

def read_json(path, default):
  try:
    with open(path,"r") as f: return json.load(f)
  except Exception: return default
def write_json_atomic(path, data):
  d=json.dumps(data, ensure_ascii=False, indent=2)
  dirn=os.path.dirname(path); fd,tmp=tempfile.mkstemp(prefix=".tmp-", dir=dirn)
  try:
    with os.fdopen(fd,"w") as f: f.write(d)
    os.replace(tmp,path)
  finally:
    try: os.remove(tmp)
    except: pass
def load_users():
  v=read_json(USERS_FILE,[])
  out=[]
  for u in v: out.append({"user":u.get("user",""), "password":u.get("password",""), "expires":u.get("expires","")})
  return out
def save_users(users): write_json_atomic(USERS_FILE, users)

def get_total_active_users():
    users = load_users()
    today_date = date.today() 
    active_count = 0
    for user in users:
        expires_str = user.get("expires")
        is_expired = False
        if expires_str:
            try:
                if datetime.strptime(expires_str, "%Y-%m-%d").date() < today_date: is_expired = True
            except ValueError: is_expired = False
        if not is_expired: active_count += 1
    return active_count

def is_expiring_soon(expires_str):
    if not expires_str: return False
    try:
        expires_date = datetime.strptime(expires_str, "%Y-%m-%d").date()
        today = date.today() 
        return 0 <= (expires_date - today).days <= 1
    except ValueError: return False
    
def calculate_days_remaining(expires_str):
    if not expires_str: return None
    try:
        expires_date = datetime.strptime(expires_str, "%Y-%m-%d").date()
        today = date.today()
        remaining = (expires_date - today).days
        return remaining if remaining >= 0 else None
    except ValueError: return None
    
def check_user_expiration():
    users = load_users()
    today_date = date.today() 
    users_to_keep = []
    deleted_count = 0
    for user in users:
        is_expired = False
        if user.get("expires"):
            try:
                if datetime.strptime(user.get("expires"), "%Y-%m-%d").date() < today_date: is_expired = True
            except ValueError: pass 
        if is_expired: deleted_count += 1
        else: users_to_keep.append(user)
    if deleted_count > 0:
        save_users(users_to_keep)
        sync_config_passwords() 
        return True 
    return False 

def sync_config_passwords():
  cfg=read_json(CONFIG_FILE,{})
  users=load_users()
  today_date = date.today() 
  valid_passwords = set()
  for u in users:
      is_valid = True
      if u.get("expires"):
          try:
              if datetime.strptime(u.get("expires"), "%Y-%m-%d").date() < today_date: is_valid = False
          except ValueError: pass 
      if is_valid and u.get("password"): valid_passwords.add(str(u["password"]))
  
  if not isinstance(cfg.get("auth"),dict): cfg["auth"]={}
  cfg["auth"]["mode"]="passwords"
  cfg["auth"]["config"]=sorted(list(valid_passwords))
  cfg["listen"]=cfg.get("listen") or ":5667"
  cfg["cert"]=cfg.get("cert") or "/etc/zivpn/zivpn.crt"
  cfg["key"]=cfg.get("key") or "/etc/zivpn/zivpn.key"
  write_json_atomic(CONFIG_FILE,cfg)
  subprocess.run("systemctl restart zivpn.service", shell=True)

def login_enabled(): return bool(ADMIN_USER and ADMIN_PASS)
def is_authed(): return session.get("auth") == True
def require_login(): return False if login_enabled() and not is_authed() else True

# 💡 LOGO SERVING ROUTE
@app.route("/logo.png")
def serve_logo():
    if os.path.exists(LOGO_PATH):
        from flask import send_file
        return send_file(LOGO_PATH, mimetype='image/jpeg')
    else:
        # Default SVG fallback
        img_data = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
        response = make_response(img_data)
        response.headers.set('Content-Type', 'image/png')
        return response

# 💡 LOGO UPLOAD ROUTE
@app.route("/upload_logo", methods=["POST"])
def upload_logo():
    if not require_login(): return redirect(url_for('login'))
    if 'logo' in request.files:
        file = request.files['logo']
        if file.filename != '':
            file.save(LOGO_PATH)
    return redirect(url_for('index'))

@app.route("/", methods=["GET"])
def index(): 
    if not require_login():
      return render_template_string(HTML, authed=False, err=session.pop("login_err", None), IP=SERVER_IP_FALLBACK) 
    check_user_expiration()
    total_users = get_total_active_users()
    new_acc = session.pop("new_account", None)
    return render_template_string(HTML, authed=True, total_users=total_users, new_account=new_acc, err=session.pop("err", None), IP=SERVER_IP_FALLBACK)

@app.route("/users", methods=["GET"])
def users_table_view():
    if not require_login(): return redirect(url_for('login'))
    check_user_expiration() 
    users = load_users()
    view=[]
    today_date = date.today()
    for u in users:
      expires_date_obj = None
      if u.get("expires"):
          try: expires_date_obj = datetime.strptime(u.get("expires"), "%Y-%m-%d").date()
          except ValueError: pass
      view.append(type("U",(),{"user":u.get("user",""), "password":u.get("password",""), "expires":u.get("expires",""), "expires_date": expires_date_obj, "days_remaining": calculate_days_remaining(u.get("expires","")), "expiring_soon": is_expiring_soon(u.get("expires","")) }))
    view.sort(key=lambda x:(x.user or "").lower())
    return render_template("users_table_wrapper.html", users=view, today_date=today_date, err=session.pop("err", None)) 

@app.route("/login", methods=["POST"])
def login():
  if not login_enabled(): return redirect(url_for('index'))
  u=(request.form.get("u") or "").strip()
  p=(request.form.get("p") or "").strip()
  if hmac.compare_digest(u, ADMIN_USER) and hmac.compare_digest(p, ADMIN_PASS):
    session["auth"]=True
  else:
    session["auth"]=False; session["login_err"]="❌ မှားယွင်းနေပါသည်" 
  return redirect(url_for('index'))

@app.route("/add", methods=["POST"])
def add_user():
  if not require_login(): return redirect(url_for('login'))
  user=(request.form.get("user") or "").strip()
  password=(request.form.get("password") or "").strip()
  expires=(request.form.get("expires") or "").strip()
  ip = (request.form.get("ip") or "").strip() or SERVER_IP_FALLBACK

  if re.search(r'[\u1000-\u109F]', user) or re.search(r'[\u1000-\u109F]', password):
      session["err"] = "❌ မြန်မာစာလုံးများ ပါဝင်၍ မရပါ"; return redirect(url_for('index'))

  if expires.isdigit(): expires=(datetime.now() + timedelta(days=int(expires))).strftime("%Y-%m-%d")

  if not user or not password:
    session["err"] = "အချက်အလက် မပြည့်စုံပါ"; return redirect(url_for('index')) 
  if expires:
    try: datetime.strptime(expires,"%Y-%m-%d")
    except ValueError: session["err"] = "ရက်စွဲ မမှန်ပါ"; return redirect(url_for('index'))
  
  users=load_users(); replaced=False
  for u in users:
    if u.get("user","").lower()==user.lower():
      u["password"]=password; u["expires"]=expires; replaced=True; break
  if not replaced: users.append({"user":user,"password":password,"expires":expires})
  
  save_users(users)
  sync_config_passwords()

  # 💡 Pass exact info to the Session for Popup
  session["new_account"] = { "user": user, "password": password, "expires": expires, "ip": ip }
  return redirect(url_for('index'))

@app.route("/edit", methods=["POST"])
def edit_user_password():
  if not require_login(): return redirect(url_for('login'))
  user=(request.form.get("user") or "").strip()
  new_password=(request.form.get("password") or "").strip()
  new_expires=(request.form.get("expires") or "").strip()
  
  if re.search(r'[\u1000-\u109F]', new_password):
      session["err"] = "❌ မြန်မာစာလုံး မရပါ"; return redirect(url_for('users_table_view')) 
      
  if new_expires.isdigit(): new_expires=(datetime.now() + timedelta(days=int(new_expires))).strftime("%Y-%m-%d")
  try: datetime.strptime(new_expires,"%Y-%m-%d")
  except ValueError: session["err"] = "❌ ရက်စွဲပုံစံ မှားနေပါသည်"; return redirect(url_for('users_table_view'))

  users=load_users()
  for u in users:
    if u.get("user","").lower()==user.lower():
      u["password"]=new_password; u["expires"]=new_expires; break
  save_users(users)
  sync_config_passwords() 
  return redirect(url_for('users_table_view'))

@app.route("/delete", methods=["POST"])
def delete_user_html():
  if not require_login(): return redirect(url_for('login'))
  user = (request.form.get("user") or "").strip()
  users = load_users()
  save_users([u for u in users if u.get("user").lower() != user.lower()])
  sync_config_passwords()
  return redirect(url_for('users_table_view'))

@app.route("/logout", methods=["GET"])
def logout(): session.clear(); return redirect(url_for('login'))

if __name__ == "__main__": app.run(host="0.0.0.0", port=8080)
PY

# ===== Web systemd =====
cat >/etc/systemd/system/zivpn-web.service <<'EOF'
[Unit]
Description=ZIVPN Web Panel
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=-/etc/zivpn/web.env
WorkingDirectory=/etc/zivpn 
ExecStart=/usr/bin/python3 /etc/zivpn/web.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ===== Networking =====
sysctl -w net.ipv4.ip_forward=1 >/dev/null
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
IFACE=$(ip -4 route ls | awk '{print $5; exit}')
[ -n "${IFACE:-}" ] || IFACE=eth0
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
ufw allow 5667/udp >/dev/null 2>&1 || true
ufw allow 6000:19999/udp >/dev/null 2>&1 || true
ufw allow 8080/tcp >/dev/null 2>&1 || true

# ===== Start Services =====
systemctl daemon-reload
systemctl enable --now zivpn.service
systemctl enable --now zivpn-web.service

IP=$(hostname -I | awk '{print $1}')
echo -e "\n$LINE\n${G}✅ ပြီးပါပြီ${Z}"
echo -e "${C}Web Panel Link :${Z} ${Y}http://$IP:8080${Z}"
echo -e "$LINE\n"
