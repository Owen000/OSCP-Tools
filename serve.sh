#!/usr/bin/env bash

set -e

SMB_PORT=445
HTTP_PORT=8001
SHARE_DIR="$(pwd)"
STATE_DIR="/tmp/oscp_share"
SMB_CONF="$STATE_DIR/smb.conf"
ACCESS_LOG="$SHARE_DIR/access.log"

mkdir -p "$STATE_DIR"
touch "$ACCESS_LOG"

IP_ADDR=$(hostname -I | awk '{print $1}')

cat > "$SMB_CONF" <<EOF
[global]
  server role = standalone server
  map to guest = Bad User
  guest account = nobody
  log file = $ACCESS_LOG
  max log size = 0
  smb ports = $SMB_PORT
  disable netbios = yes
  log level = 1

[share]
  path = $SHARE_DIR
  browsable = yes
  read only = no
  guest ok = yes
  force user = nobody
EOF

echo "[*] Starting SMB server..."
smbd -D -s "$SMB_CONF"
SMB_PID=$(pgrep -f "$SMB_CONF")

echo "[*] Starting HTTP server..."
python3 - <<PY >/dev/null 2>&1 &
import http.server
import socketserver
import datetime
import os

PORT = $HTTP_PORT
DIRECTORY = "$SHARE_DIR"
LOGFILE = "$ACCESS_LOG"

class Handler(http.server.SimpleHTTPRequestHandler):
  def log_download(self):
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    ip = self.client_address[0]
    path = self.path
    with open(LOGFILE, "a") as f:
      f.write(f"{ts} {ip} {path}\n")

  def do_GET(self):
    self.log_download()
    return super().do_GET()

  def log_message(self, format, *args):
    return

os.chdir(DIRECTORY)

with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
  httpd.serve_forever()
PY

HTTP_PID=$!

echo "$SMB_PID" > "$STATE_DIR/smb.pid"
echo "$HTTP_PID" > "$STATE_DIR/http.pid"

echo
echo "========== SERVERS RUNNING =========="
echo "SMB  : \\\\${IP_ADDR}\\share"
echo "Port : $SMB_PORT"
echo
echo "HTTP : http://${IP_ADDR}:${HTTP_PORT}/"
echo "Port : $HTTP_PORT"
echo
echo "Directory shared: $SHARE_DIR"
echo "Access log: $ACCESS_LOG"
echo "====================================="
echo
echo "To stop everything:"
echo "  kill \$(cat $STATE_DIR/http.pid)"
echo "  pkill -f $SMB_CONF"
echo
