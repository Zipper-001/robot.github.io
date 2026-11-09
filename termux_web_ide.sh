#!/data/data/com.termux/files/usr/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}   ติดตั้ง Termux Web Code Editor + SSH Server       ${NC}"
echo -e "${CYAN}====================================================${NC}"

# 1. ติดตั้งแพ็กเกจที่จำเป็น (Python สำหรับ Web Server และ OpenSSH สำหรับ SSH)
echo -e "${YELLOW}[1/4] กำลังตรวจสอบและติดตั้งแพ็กเกจ (python, openssh, iproute2)...${NC}"
pkg update -y
pkg install -y python openssh iproute2

# 2. เริ่มการทำงานของ SSH Server (พอร์ตมาตรฐานของ Termux คือ 8022)
echo -e "${YELLOW}[2/4] กำลังเปิดใช้งาน SSH Server...${NC}"
if ! pgrep -x "sshd" > /dev/null; then
    sshd
    echo -e "${GREEN}[+] เปิดใช้งาน sshd สำเร็จ (Port: 8022)${NC}"
else
    echo -e "${GREEN}[+] sshd กำลังทำงานอยู่แล้ว (Port: 8022)${NC}"
fi

# 3. สร้างโฟลเดอร์และโค้ด Web Server + HTML Code Editor
APP_DIR="$HOME/termux-web-editor"
mkdir -p "$APP_DIR"

echo -e "${YELLOW}[3/4] กำลังสร้างไฟล์ระบบ Web Code Editor...${NC}"

cat << 'EOF' > "$APP_DIR/server.py"
import os
import json
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

BASE_DIR = os.path.expanduser("~")
PORT = 8080

HTML_PAGE = """<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Termux Web IDE & Terminal</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/theme/dracula.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/shell/shell.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/python/python.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/javascript/javascript.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/xml/xml.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/htmlmixed/htmlmixed.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/css/css.min.js"></script>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: monospace; background: #1e1e2e; color: #cdd6f4; height: 100vh; display: flex; flex-direction: column; overflow: hidden; }
  header { background: #181825; padding: 10px 15px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #313244; flex-wrap: wrap; gap: 8px; }
  .title { font-weight: bold; color: #89b4fa; font-size: 16px; }
  .actions button { background: #313244; color: #cdd6f4; border: 1px solid #45475a; padding: 6px 12px; border-radius: 4px; cursor: pointer; margin-left: 5px; font-size: 13px; }
  .actions button.save { background: #a6e3a1; color: #11111b; font-weight: bold; border: none; }
  .actions button:hover { opacity: 0.9; }
  .main { display: flex; flex: 1; overflow: hidden; }
  .sidebar { width: 250px; background: #181825; border-right: 1px solid #313244; display: flex; flex-direction: column; overflow-y: auto; }
  .current-dir { padding: 8px; background: #11111b; font-size: 12px; color: #a6adc8; word-break: break-all; border-bottom: 1px solid #313244; }
  .file-item { padding: 8px 12px; cursor: pointer; border-bottom: 1px solid #232433; font-size: 13px; display: flex; align-items: center; gap: 6px; }
  .file-item:hover { background: #313244; }
  .workspace { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
  .editor-header { background: #181825; padding: 6px 12px; font-size: 13px; color: #f9e2af; border-bottom: 1px solid #313244; }
  .editor-wrap { flex: 1; overflow: hidden; position: relative; }
  .CodeMirror { height: 100% !important; font-size: 14px; }
  .terminal { height: 180px; background: #11111b; border-top: 2px solid #313244; display: flex; flex-direction: column; }
  .term-output { flex: 1; padding: 8px; overflow-y: auto; font-size: 12px; white-space: pre-wrap; color: #a6e3a1; }
  .term-input-row { display: flex; border-top: 1px solid #313244; }
  .term-input-row span { padding: 6px 8px; color: #89b4fa; background: #181825; }
  .term-input-row input { flex: 1; background: #181825; color: #fff; border: none; padding: 6px; font-family: monospace; outline: none; }
  @media (max-width: 600px) { .sidebar { width: 160px; } }
</style>
</head>
<body>
<header>
  <div class="title">Termux Web Editor & SSH</div>
  <div class="actions">
    <button onclick="createNewFile()">+ สร้างไฟล์ใหม่</button>
    <button onclick="createNewFolder()">+ โฟลเดอร์ใหม่</button>
    <button class="save" onclick="saveFile()">บันทึก (Ctrl+S)</button>
  </div>
</header>
<div class="main">
  <div class="sidebar">
    <div class="current-dir" id="dirPath">~</div>
    <div id="fileList"></div>
  </div>
  <div class="workspace">
    <div class="editor-header" id="currentFile">ยังไม่ได้เลือกไฟล์</div>
    <div class="editor-wrap">
      <textarea id="codeEditor"></textarea>
    </div>
    <div class="terminal">
      <div class="term-output" id="termOut">พร้อมใช้งานคำสั่ง Shell เบื้องต้น... (พิมพ์ด้านล่างแล้วกด Enter)\n</div>
      <div class="term-input-row">
        <span>$</span>
        <input type="text" id="cmdInput" placeholder="พิมพ์คำสั่ง เช่น ls -la, python test.py, bash script.sh ..." onkeydown="if(event.key==='Enter') runCmd()">
      </div>
    </div>
  </div>
</div>

<script>
let currentDir = "";
let activeFile = "";

const editor = CodeMirror.fromTextArea(document.getElementById("codeEditor"), {
  lineNumbers: true,
  theme: "dracula",
  mode: "shell",
  indentUnit: 4,
  lineWrapping: true
});

document.addEventListener("keydown", function(e) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    saveFile();
  }
});

function detectMode(filename) {
  if (filename.endsWith(".py")) return "python";
  if (filename.endsWith(".js") || filename.endsWith(".json")) return "javascript";
  if (filename.endsWith(".html") || filename.endsWith(".htm")) return "htmlmixed";
  if (filename.endsWith(".css")) return "css";
  return "shell";
}

async function loadDir(dir = "") {
  const res = await fetch(`/api/list?dir=${encodeURIComponent(dir)}`);
  const data = await res.json();
  if (data.error) return alert(data.error);
  currentDir = data.dir;
  document.getElementById("dirPath").textContent = currentDir;
  const listEl = document.getElementById("fileList");
  listEl.innerHTML = "";

  if (data.parent !== null) {
    const up = document.createElement("div");
    up.className = "file-item";
    up.innerHTML = "📁 <b>.. (ย้อนกลับ)</b>";
    up.onclick = () => loadDir(data.parent);
    listEl.appendChild(up);
  }

  data.items.forEach(item => {
    const el = document.createElement("div");
    el.className = "file-item";
    el.innerHTML = (item.is_dir ? "📁 " : "📄 ") + item.name;
    el.onclick = () => item.is_dir ? loadDir(item.path) : openFile(item.path);
    listEl.appendChild(el);
  });
}

async function openFile(filepath) {
  const res = await fetch(`/api/read?path=${encodeURIComponent(filepath)}`);
  const data = await res.json();
  if (data.error) return alert(data.error);
  activeFile = data.path;
  document.getElementById("currentFile").textContent = activeFile;
  editor.setOption("mode", detectMode(activeFile));
  editor.setValue(data.content);
}

async function saveFile() {
  if (!activeFile) return alert("กรุณาเลือกไฟล์หรือสร้างไฟล์ใหม่ก่อนบันทึก");
  const res = await fetch("/api/save", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path: activeFile, content: editor.getValue() })
  });
  const data = await res.json();
  if (data.error) alert("เกิดข้อผิดพลาด: " + data.error);
  else {
    const hdr = document.getElementById("currentFile");
    hdr.textContent = activeFile + " (บันทึกสำเร็จ!)";
    setTimeout(() => hdr.textContent = activeFile, 2000);
    loadDir(currentDir);
  }
}

async function createNewFile() {
  const name = prompt("ชื่อไฟล์ใหม่ (เช่น script.sh, index.html, app.py):");
  if (!name) return;
  const fullPath = currentDir + "/" + name;
  activeFile = fullPath;
  document.getElementById("currentFile").textContent = activeFile + " (ไฟล์ใหม่)";
  editor.setOption("mode", detectMode(activeFile));
  editor.setValue("");
  await saveFile();
}

async function createNewFolder() {
  const name = prompt("ชื่อโฟลเดอร์ใหม่:");
  if (!name) return;
  const res = await fetch("/api/mkdir", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path: currentDir + "/" + name })
  });
  const data = await res.json();
  if (data.error) alert(data.error);
  else loadDir(currentDir);
}

async function runCmd() {
  const input = document.getElementById("cmdInput");
  const cmd = input.value.trim();
  if (!cmd) return;
  input.value = "";
  const out = document.getElementById("termOut");
  out.textContent += `\n$ ${cmd}\n`;
  out.scrollTop = out.scrollHeight;

  const res = await fetch("/api/cmd", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ cmd: cmd, cwd: currentDir })
  });
  const data = await res.json();
  out.textContent += (data.output || "(ไม่มีข้อความตอบกลับ)") + "\n";
  out.scrollTop = out.scrollHeight;
  loadDir(currentDir);
}

loadDir();
</script>
</body>
</html>
"""

class WebIDEHandler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/":
            body = HTML_PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif parsed.path == "/api/list":
            target_dir = qs.get("dir", [""])[0] or BASE_DIR
            target_dir = os.path.abspath(target_dir)
            try:
                entries = []
                for name in sorted(os.listdir(target_dir), key=lambda x: (not os.path.isdir(os.path.join(target_dir, x)), x.lower())):
                    full = os.path.join(target_dir, name)
                    entries.append({
                        "name": name,
                        "path": full,
                        "is_dir": os.path.isdir(full)
                    })
                parent = os.path.dirname(target_dir) if target_dir != "/" else None
                self.send_json({"dir": target_dir, "parent": parent, "items": entries})
            except Exception as e:
                self.send_json({"error": str(e)}, 400)

        elif parsed.path == "/api/read":
            filepath = qs.get("path", [""])[0]
            try:
                with open(filepath, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                self.send_json({"path": filepath, "content": content})
            except Exception as e:
                self.send_json({"error": str(e)}, 400)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        data = json.loads(self.rfile.read(length).decode("utf-8"))

        if self.path == "/api/save":
            try:
                with open(data["path"], "w", encoding="utf-8") as f:
                    f.write(data["content"])
                self.send_json({"status": "ok"})
            except Exception as e:
                self.send_json({"error": str(e)}, 400)

        elif self.path == "/api/mkdir":
            try:
                os.makedirs(data["path"], exist_ok=True)
                self.send_json({"status": "ok"})
            except Exception as e:
                self.send_json({"error": str(e)}, 400)

        elif self.path == "/api/cmd":
            try:
                cwd = data.get("cwd") or BASE_DIR
                proc = subprocess.run(
                    data["cmd"], shell=True, cwd=cwd,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    text=True, timeout=30
                )
                self.send_json({"output": proc.stdout})
            except Exception as e:
                self.send_json({"output": f"Error: {str(e)}"})

    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), WebIDEHandler)
    print(f"Server started on port {PORT}")
    server.serve_forever()
EOF

# 4. แสดงข้อมูลการเชื่อมต่อและรันเซิร์ฟเวอร์
USER_NAME=$(whoami)
IP_ADDR=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
[ -z "$IP_ADDR" ] && IP_ADDR="127.0.0.1"

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}[+] ระบบพร้อมใช้งานแล้ว!${NC}"
echo -e "${YELLOW}1) เข้าแก้ไขโค้ดผ่านเว็บเบราว์เซอร์ (Web Editor):${NC}"
echo -e "   - เปิดในมือถือเครื่องนี้: ${GREEN}http://127.0.0.1:8080${NC}"
echo -e "   - เปิดจากคอม/เครื่องอื่นใน Wi-Fi: ${GREEN}http://${IP_ADDR}:8080${NC}"
echo ""
echo -e "${YELLOW}2) เชื่อมต่อผ่าน SSH (พอร์ต 8022):${NC}"
echo -e "   - คำสั่งเชื่อมจากคอม: ${GREEN}ssh ${USER_NAME}@${IP_ADDR} -p 8022${NC}"
echo -e "   - (หากยังไม่เคยตั้งรหัสผ่าน SSH ให้พิมพ์คำสั่ง ${CYAN}passwd${NC} ใน Termux)"
echo -e "${CYAN}====================================================${NC}"
echo -e "กด ${YELLOW}Ctrl + C${NC} เมื่อต้องการปิด Web Server"

python3 "$APP_DIR/server.py"
