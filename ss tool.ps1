import sys, os, subprocess, importlib

DEPS = ["psutil", "pywin32", "pyautogui"]

def install_deps():
    for pkg in DEPS:
        try:
            importlib.import_module(pkg if pkg != "pywin32" else "win32api")
        except ImportError:
            print(f"[SETUP] Installing {pkg}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", pkg, "-q"])

install_deps()

import tkinter as tk
from tkinter import ttk, filedialog, scrolledtext
import threading, ctypes, ctypes.wintypes as wintypes
import datetime, json, re, time, hashlib, base64

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

try:
    import win32gui, win32con, win32api, win32process
    HAS_WIN32 = True
except ImportError:
    HAS_WIN32 = False

try:
    import pyautogui
    pyautogui.FAILSAFE = False
    pyautogui.PAUSE = 0.1
    HAS_PYAUTOGUI = True
except ImportError:
    HAS_PYAUTOGUI = False

BG     = "#0a0c12"
BG2    = "#0f1219"
BG3    = "#141820"
BG4    = "#1a1f2e"
ACCENT = "#00d4ff"
RED    = "#ff3d5a"
GREEN  = "#00e87a"
ORANGE = "#ffaa00"
TEXT   = "#d0d8e8"
DIM    = "#4a5568"
BORDER = "#1e2535"
MONO   = ("Consolas", 9)
UI     = ("Segoe UI", 10)
BOLD   = ("Segoe UI Semibold", 11)
HEAD   = ("Segoe UI Semibold", 13)

CHEAT_NAMES = [
    "wurst","impact","future","liquidbounce","aristois","meteor",
    "killaura","sigma","entropy","novoline","rusherhack","vape",
    "astolfo","inertia","ghost","rise","tenacity","aura","esp",
    "aimbot","bhop","scaffold","velocity","criticals","nofall",
    "autoeat","autofish","tracers","xray","freecam","fly","speed",
    "jesus","mixin","bytebuddy","javassist","classinjector",
    "agentmain","premain","instrumentation",
]

BAD_JVM = ["-javaagent","-agentlib","-agentpath","-Xbootclasspath","bytebuddy","javassist"]

MEM_SIGS = [
    b"KillAura",b"killaura",b"AutoCrystal",b"autocrystal",b"Scaffold",
    b"scaffold",b"Velocity",b"NoFall",b"Freecam",b"ESP",b"Xray",b"xray",
    b"BHop",b"Flight",b"flight",b"CrystalAura",b"BaritoneAPI",b"baritone.api",
    b"agentmain",b"premain",b"ClassFileTransformer",b"bytebuddy","net.bytebuddy".encode(),
    b"javassist",b"aimbot",b"wallhack",b"autoclick",b"triggerbot",b"sendPacket",
    b"injectPacket",b"noknockback",b"antiknockback",
]

SCAN_EXTS = {".jar",".zip",".class",".json",".cfg",".properties"}


def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("MC Cheat Scanner")
        self.geometry("1100x700")
        self.minsize(960, 580)
        self.configure(bg=BG)
        self._mc_folder  = tk.StringVar()
        self._out_folder = tk.StringVar()
        self._findings   = []
        self._mc_procs   = []
        self._stop       = threading.Event()
        self._progress   = tk.DoubleVar()
        self._build()

    def _build(self):
        self._build_header()
        self._build_nav()
        self._container = tk.Frame(self, bg=BG)
        self._container.pack(fill="both", expand=True)
        self._pages = {}
        for PageClass in (SetupPage, ScanPage, MemoryPage, SysInfoPage):
            page = PageClass(self._container, self)
            self._pages[PageClass.NAME] = page
            page.place(relx=0, rely=0, relwidth=1, relheight=1)
        self._build_statusbar()
        self.show_page("Setup")

    def _build_header(self):
        h = tk.Frame(self, bg=BG2, height=52)
        h.pack(fill="x")
        h.pack_propagate(False)
        tk.Label(h, text="⚡", font=("Segoe UI", 18), bg=BG2, fg=ACCENT).pack(side="left", padx=(18,6), pady=12)
        tk.Label(h, text="MC CHEAT SCANNER", font=("Segoe UI Semibold", 14), bg=BG2, fg=TEXT).pack(side="left")
        tk.Label(h, text=" v4.0", font=UI, bg=BG2, fg=DIM).pack(side="left")
        admin_txt = "✔ ADMIN" if is_admin() else "⚠ NOT ADMIN"
        admin_col = GREEN if is_admin() else RED
        tk.Label(h, text=admin_txt, font=("Consolas", 9), bg=BG2, fg=admin_col).pack(side="right", padx=18)
        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")

    def _build_nav(self):
        nav = tk.Frame(self, bg=BG2)
        nav.pack(fill="x")
        self._nav_btns = {}
        pages = [("Setup","⚙"), ("Scanner","🔍"), ("Memory","🧠"), ("Sys Info","🖥")]
        for name, icon in pages:
            btn = tk.Button(nav, text=f" {icon}  {name}", font=("Segoe UI Semibold", 10),
                            bg=BG2, fg=DIM, relief="flat", bd=0, padx=20, pady=10,
                            cursor="hand2", activebackground=BG3, activeforeground=TEXT,
                            command=lambda n=name: self.show_page(n))
            btn.pack(side="left")
            self._nav_btns[name] = btn
        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")

    def _build_statusbar(self):
        bar = tk.Frame(self, bg=BG2, height=24)
        bar.pack(fill="x", side="bottom")
        bar.pack_propagate(False)
        self._status_var = tk.StringVar(value="Ready — configure paths in Setup then run a scan")
        tk.Label(bar, textvariable=self._status_var, font=("Consolas", 8),
                 bg=BG2, fg=DIM).pack(side="left", padx=12)
        self._time_var = tk.StringVar()
        tk.Label(bar, textvariable=self._time_var, font=("Consolas", 8),
                 bg=BG2, fg=DIM).pack(side="right", padx=12)

    def show_page(self, name):
        self._pages[name].tkraise()
        for n, btn in self._nav_btns.items():
            btn.configure(fg=ACCENT if n == name else DIM,
                          bg=BG3 if n == name else BG2)

    def set_status(self, msg):
        self._status_var.set(msg)

    def set_time(self, msg):
        self._time_var.set(msg)


class BasePage(tk.Frame):
    NAME = "Base"

    def __init__(self, parent, app):
        super().__init__(parent, bg=BG)
        self.app = app

    def _section_label(self, parent, text):
        f = tk.Frame(parent, bg=BG)
        f.pack(fill="x", padx=20, pady=(16,4))
        tk.Label(f, text=text, font=("Segoe UI Semibold", 10), bg=BG, fg=ACCENT).pack(side="left")
        tk.Frame(f, bg=BORDER, height=1).pack(side="left", fill="x", expand=True, padx=(10,0))

    def _card(self, parent, padx=20, pady=8):
        f = tk.Frame(parent, bg=BG3, bd=0, highlightthickness=1, highlightbackground=BORDER)
        f.pack(fill="x", padx=padx, pady=pady)
        return f

    def _log_widget(self, parent):
        log = scrolledtext.ScrolledText(parent, bg=BG2, fg=TEXT, font=MONO,
                                        relief="flat", bd=0, insertbackground=ACCENT,
                                        state="disabled", wrap="word", padx=10, pady=8)
        log.tag_config("critical", foreground=RED,    font=("Consolas", 9, "bold"))
        log.tag_config("warning",  foreground=ORANGE)
        log.tag_config("ok",       foreground=GREEN)
        log.tag_config("info",     foreground=ACCENT)
        log.tag_config("head",     foreground=ACCENT, font=("Consolas", 9, "bold"))
        log.tag_config("dim",      foreground=DIM)
        log.tag_config("normal",   foreground=TEXT)
        return log

    def _write(self, log, text, tag="normal"):
        log.configure(state="normal")
        log.insert("end", text + "\n", tag)
        log.configure(state="disabled")
        log.see("end")


class SetupPage(BasePage):
    NAME = "Setup"

    def __init__(self, parent, app):
        super().__init__(parent, app)
        self._build()

    def _build(self):
        tk.Label(self, text="SETUP", font=("Segoe UI Semibold", 12),
                 bg=BG, fg=ACCENT).pack(anchor="w", padx=24, pady=(20,2))
        tk.Label(self, text="Configure your scan paths before running any module.",
                 font=UI, bg=BG, fg=DIM).pack(anchor="w", padx=24, pady=(0,12))

        self._section_label(self, "① Minecraft Mods Folder")
        c1 = self._card(self)
        row1 = tk.Frame(c1, bg=BG3)
        row1.pack(fill="x", padx=14, pady=12)
        tk.Label(row1, text="Path:", font=UI, bg=BG3, fg=DIM, width=6, anchor="w").pack(side="left")
        tk.Entry(row1, textvariable=self.app._mc_folder, font=MONO, bg=BG4, fg=TEXT,
                 insertbackground=ACCENT, relief="flat", bd=0,
                 highlightthickness=1, highlightcolor=ACCENT, highlightbackground=BORDER
                 ).pack(side="left", fill="x", expand=True, ipady=6, padx=(0,8))
        tk.Button(row1, text="Browse", font=UI, bg=BG4, fg=ACCENT,
                  relief="flat", bd=0, padx=12, pady=4, cursor="hand2",
                  command=lambda: self._browse(self.app._mc_folder)).pack(side="left")

        self._section_label(self, "② Output / Report Folder")
        c2 = self._card(self)
        row2 = tk.Frame(c2, bg=BG3)
        row2.pack(fill="x", padx=14, pady=12)
        tk.Label(row2, text="Path:", font=UI, bg=BG3, fg=DIM, width=6, anchor="w").pack(side="left")
        tk.Entry(row2, textvariable=self.app._out_folder, font=MONO, bg=BG4, fg=TEXT,
                 insertbackground=ACCENT, relief="flat", bd=0,
                 highlightthickness=1, highlightcolor=ACCENT, highlightbackground=BORDER
                 ).pack(side="left", fill="x", expand=True, ipady=6, padx=(0,8))
        tk.Button(row2, text="Browse", font=UI, bg=BG4, fg=ACCENT,
                  relief="flat", bd=0, padx=12, pady=4, cursor="hand2",
                  command=lambda: self._browse(self.app._out_folder)).pack(side="left")

        self._section_label(self, "③ Quick Launch")
        c3 = self._card(self)
        btns = tk.Frame(c3, bg=BG3)
        btns.pack(fill="x", padx=14, pady=14)
        for label, page, color in [
            ("▶  Run File Scanner", "Scanner", GREEN),
            ("▶  Run Memory Scan",  "Memory",  ACCENT),
            ("▶  View Sys Info",    "Sys Info", ORANGE),
        ]:
            tk.Button(btns, text=label, font=BOLD, bg=color, fg=BG,
                      relief="flat", bd=0, padx=18, pady=8, cursor="hand2",
                      activebackground=color,
                      command=lambda p=page: self.app.show_page(p)).pack(side="left", padx=(0,10))

        self._section_label(self, "Requirements")
        c4 = self._card(self)
        deps_f = tk.Frame(c4, bg=BG3)
        deps_f.pack(fill="x", padx=14, pady=10)
        for label, ok in [
            ("psutil",    HAS_PSUTIL),
            ("pywin32",   HAS_WIN32),
            ("pyautogui", HAS_PYAUTOGUI),
            ("Windows",   sys.platform == "win32"),
            ("Admin",     is_admin()),
        ]:
            chip = tk.Frame(deps_f, bg=BG4, padx=10, pady=4)
            chip.pack(side="left", padx=(0,6))
            tk.Label(chip, text=("✔ " if ok else "✘ ") + label,
                     font=("Consolas", 9), bg=BG4,
                     fg=GREEN if ok else RED).pack()

    def _browse(self, var):
        d = filedialog.askdirectory()
        if d:
            var.set(d)


class ScanPage(BasePage):
    NAME = "Scanner"

    def __init__(self, parent, app):
        super().__init__(parent, app)
        self._stop  = threading.Event()
        self._findings = []
        self._build()

    def _build(self):
        top = tk.Frame(self, bg=BG2)
        top.pack(fill="x")
        tk.Label(top, text="FILE SCANNER", font=("Segoe UI Semibold", 11),
                 bg=BG2, fg=ACCENT).pack(side="left", padx=20, pady=12)
        self._stop_btn = tk.Button(top, text="■  STOP", font=BOLD, bg=RED, fg="white",
                                    relief="flat", bd=0, padx=16, pady=6, cursor="hand2",
                                    state="disabled", command=self._do_stop)
        self._stop_btn.pack(side="right", padx=8, pady=10)
        self._start_btn = tk.Button(top, text="▶  START", font=BOLD, bg=GREEN, fg=BG,
                                     relief="flat", bd=0, padx=16, pady=6, cursor="hand2",
                                     command=self._start)
        self._start_btn.pack(side="right", pady=10)
        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")

        pb = tk.Frame(self, bg=BG, pady=0)
        pb.pack(fill="x")
        self._pb = ttk.Progressbar(pb, variable=self.app._progress, maximum=100)
        s = ttk.Style(); s.theme_use("clam")
        s.configure("Horizontal.TProgressbar", troughcolor=BG2, background=ACCENT,
                     lightcolor=ACCENT, darkcolor=ACCENT, bordercolor=BG, thickness=4)
        self._pb.pack(fill="x")

        body = tk.Frame(self, bg=BG)
        body.pack(fill="both", expand=True)

        left = tk.Frame(body, bg=BG2, width=300)
        left.pack(side="left", fill="y")
        left.pack_propagate(False)
        tk.Frame(body, bg=BORDER, width=1).pack(side="left", fill="y")

        tk.Label(left, text="FINDINGS", font=("Consolas", 9, "bold"),
                 bg=BG2, fg=DIM).pack(anchor="w", padx=12, pady=(10,4))

        counts = tk.Frame(left, bg=BG2)
        counts.pack(fill="x", padx=8, pady=(0,8))
        self._c_crit = tk.StringVar(value="0")
        self._c_warn = tk.StringVar(value="0")
        self._c_info = tk.StringVar(value="0")
        for var, lbl, col in [(self._c_crit,"CRIT",RED),(self._c_warn,"WARN",ORANGE),(self._c_info,"INFO",ACCENT)]:
            f = tk.Frame(counts, bg=BG3, padx=10, pady=6)
            f.pack(side="left", expand=True, fill="x", padx=2)
            tk.Label(f, textvariable=var, font=("Consolas", 16, "bold"), bg=BG3, fg=col).pack()
            tk.Label(f, text=lbl, font=("Consolas", 8), bg=BG3, fg=DIM).pack()

        lbf = tk.Frame(left, bg=BG2)
        lbf.pack(fill="both", expand=True, padx=6, pady=4)
        sb = tk.Scrollbar(lbf, bg=BG2, troughcolor=BG, relief="flat", bd=0)
        sb.pack(side="right", fill="y")
        self._lb = tk.Listbox(lbf, bg=BG2, fg=TEXT, selectbackground=BG4,
                               selectforeground=ACCENT, font=MONO, relief="flat",
                               bd=0, yscrollcommand=sb.set, activestyle="none",
                               cursor="hand2")
        self._lb.pack(side="left", fill="both", expand=True)
        sb.config(command=self._lb.yview)
        self._lb.bind("<<ListboxSelect>>", self._on_select)

        right = tk.Frame(body, bg=BG)
        right.pack(side="left", fill="both", expand=True)
        tk.Label(right, text="SCAN LOG", font=("Consolas", 9, "bold"),
                 bg=BG, fg=DIM).pack(anchor="w", padx=14, pady=(10,4))
        self._log = self._log_widget(right)
        self._log.pack(fill="both", expand=True, padx=8, pady=(0,8))

    def _start(self):
        mc = self.app._mc_folder.get().strip()
        out = self.app._out_folder.get().strip()
        if not mc or not os.path.isdir(mc):
            self._write(self._log, "❌  Set Minecraft folder in Setup first.", "critical"); return
        if not out or not os.path.isdir(out):
            self._write(self._log, "❌  Set output folder in Setup first.", "critical"); return
        self._findings.clear()
        self._lb.delete(0, "end")
        self._c_crit.set("0"); self._c_warn.set("0"); self._c_info.set("0")
        self._log.configure(state="normal"); self._log.delete("1.0","end"); self._log.configure(state="disabled")
        self.app._progress.set(0)
        self._stop.clear()
        self._start_btn.configure(state="disabled")
        self._stop_btn.configure(state="normal")
        self.app.set_status("File scan running...")
        threading.Thread(target=self._run, daemon=True).start()

    def _do_stop(self):
        self._stop.set()

    def _run(self):
        t0 = time.time()
        mc = self.app._mc_folder.get().strip()
        out = self.app._out_folder.get().strip()
        self._write(self._log, f"Started  {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", "head")
        self._write(self._log, f"Folder   {mc}", "dim")

        steps = [
            ("Process Check",  self._scan_procs),
            ("JVM Args",       self._scan_jvm),
            ("File Handles",   self._scan_handles),
            ("Directory Scan", lambda: self._scan_dirs(mc)),
            ("Startup Check",  self._scan_startup),
            ("Write Report",   lambda: self._write_report(out)),
        ]
        for i, (label, fn) in enumerate(steps):
            if self._stop.is_set(): break
            self.app._progress.set((i / len(steps)) * 100)
            self._write(self._log, f"\n── {label} ──", "head")
            try: fn()
            except Exception as e: self._write(self._log, f"Error: {e}", "warning")

        elapsed = time.time() - t0
        self.app._progress.set(100)
        self.app.set_time(f"Scan: {elapsed:.1f}s")
        self._write(self._log, f"\n✔ Finished in {elapsed:.1f}s", "ok")
        crits = sum(1 for f in self._findings if f["severity"] == "critical")
        self.app.set_status(f"Done — {len(self._findings)} findings, {crits} critical")
        self.after(0, lambda: (self._start_btn.configure(state="normal"),
                               self._stop_btn.configure(state="disabled")))

    def _add(self, sev, cat, detail, extra=""):
        self._findings.append({"severity":sev,"category":cat,"detail":detail,"extra":extra})
        icons = {"critical":"🔴","warning":"🟠","info":"🔵"}
        colors = {"critical":RED,"warning":ORANGE,"info":ACCENT}
        short = f"{icons.get(sev,'⚪')} {cat}: {detail[:44]}{'…' if len(detail)>44 else ''}"
        self._lb.insert("end", short)
        self._lb.itemconfig(self._lb.size()-1, fg=colors.get(sev, TEXT))
        self._c_crit.set(str(sum(1 for f in self._findings if f["severity"]=="critical")))
        self._c_warn.set(str(sum(1 for f in self._findings if f["severity"]=="warning")))
        self._c_info.set(str(sum(1 for f in self._findings if f["severity"]=="info")))

    def _on_select(self, _):
        sel = self._lb.curselection()
        if not sel or sel[0] >= len(self._findings): return
        f = self._findings[sel[0]]
        self._write(self._log, f"\n▸ {f['category']} [{f['severity'].upper()}]", "head")
        self._write(self._log, f"  {f['detail']}", "normal")
        if f["extra"]: self._write(self._log, f"  {f['extra']}", "dim")

    def _scan_procs(self):
        self.app._mc_procs = []
        if not HAS_PSUTIL: self._write(self._log, "psutil not available", "dim"); return
        for p in psutil.process_iter(["pid","name","cmdline"]):
            try:
                name = (p.info["name"] or "").lower()
                cmd  = " ".join(p.info["cmdline"] or []).lower()
                if ("java" in name or "minecraft" in name) and \
                   any(k in cmd for k in ["minecraft","lwjgl","net.minecraft","forge","fabric"]):
                    self.app._mc_procs.append(p)
                    self._write(self._log, f"✔ Minecraft PID {p.pid} — {p.info['name']}", "ok")
                    self._add("info","Process",f"Minecraft PID {p.pid}")
            except (psutil.NoSuchProcess, psutil.AccessDenied): pass
        if not self.app._mc_procs:
            self._write(self._log, "No running Minecraft found — file scan continues", "dim")

    def _scan_jvm(self):
        if not self.app._mc_procs: self._write(self._log,"No processes","dim"); return
        for p in self.app._mc_procs:
            try:
                cmd = " ".join(p.cmdline())
                for flag in BAD_JVM:
                    if flag.lower() in cmd.lower():
                        sev = "critical" if flag.startswith("-") else "warning"
                        self._write(self._log, f"{'🔴' if sev=='critical' else '🟠'} Flag: {flag}", sev)
                        self._add(sev,"JVM Flag",f"'{flag}' in PID {p.pid}",cmd[:200])
                agents = re.findall(r'-javaagent[=:]([^\s"]+)', cmd, re.IGNORECASE)
                for a in agents:
                    self._write(self._log, f"🔴 Agent JAR: {a}", "critical")
                    self._add("critical","Java Agent",os.path.basename(a),a)
                    for ch in CHEAT_NAMES:
                        if ch in a.lower():
                            self._write(self._log, f"🚨 KNOWN CHEAT: {ch.upper()}", "critical")
                            self._add("critical","Known Cheat",f"Matches: {ch}",a)
                if not agents: self._write(self._log, f"✔ No agent flags PID {p.pid}", "ok")
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                self._write(self._log, f"Access denied PID {p.pid}", "warning")

    def _scan_handles(self):
        if not self.app._mc_procs: self._write(self._log,"No processes","dim"); return
        for p in self.app._mc_procs:
            try:
                files = p.open_files()
                for f in files:
                    pl = f.path.lower()
                    for ch in CHEAT_NAMES:
                        if ch in pl:
                            self._write(self._log, f"🔴 Cheat file open: {f.path}", "critical")
                            self._add("critical","Cheat Handle",f"Matches '{ch}'",f.path)
                    if f.path.endswith(".jar") and "minecraft" not in pl:
                        self._write(self._log, f"🟠 Unknown JAR: {f.path}", "warning")
                        self._add("warning","Unknown JAR","Unexpected JAR",f.path)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                self._write(self._log, f"Access denied PID {p.pid}", "warning")

    def _scan_dirs(self, root):
        self._write(self._log, f"Scanning: {root}", "info")
        for dirpath, dirnames, filenames in os.walk(root):
            if self._stop.is_set(): return
            dirnames[:] = [d for d in dirnames if d.lower() not in
                            {"versions","assets","libraries","natives","cache"}]
            for fname in filenames:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in SCAN_EXTS: continue
                fpath = os.path.join(dirpath, fname)
                for ch in CHEAT_NAMES:
                    if ch in fname.lower():
                        self._write(self._log, f"🔴 Cheat file: {fname}", "critical")
                        self._add("critical","Cheat File",f"Matches '{ch}'",fpath)
                if ext in {".json",".cfg",".properties"}:
                    try:
                        content = open(fpath, errors="replace").read(65536).lower()
                        for ch in CHEAT_NAMES:
                            if ch in content:
                                self._write(self._log, f"🟠 Cheat in config: {fname}", "warning")
                                self._add("warning","Config Match",f"'{ch}' in file",fpath)
                                break
                    except Exception: pass

    def _scan_startup(self):
        if sys.platform != "win32": self._write(self._log,"Windows-only","dim"); return
        for d in [os.path.join(os.environ.get("APPDATA",""), r"Microsoft\Windows\Start Menu\Programs\Startup"),
                  os.path.join(os.environ.get("PROGRAMDATA",""), r"Microsoft\Windows\Start Menu\Programs\Startup")]:
            if os.path.isdir(d):
                for item in os.listdir(d):
                    for ch in CHEAT_NAMES:
                        if ch in item.lower():
                            self._write(self._log, f"🔴 Cheat in startup: {item}", "critical")
                            self._add("critical","Startup",f"Matches '{ch}'",os.path.join(d,item))
        try:
            import winreg
            for hive, path in [(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run"),
                                (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Run")]:
                try:
                    key = winreg.OpenKey(hive, path); i = 0
                    while True:
                        try:
                            name, val, _ = winreg.EnumValue(key, i)
                            for ch in CHEAT_NAMES:
                                if ch in val.lower() or ch in name.lower():
                                    self._write(self._log, f"🔴 Registry Run: {name}", "critical")
                                    self._add("critical","Registry Run",f"'{name}' matches '{ch}'",val)
                            i += 1
                        except OSError: break
                    winreg.CloseKey(key)
                except OSError: pass
        except ImportError: pass
        self._write(self._log, "✔ Startup check done", "ok")

    def _write_report(self, out):
        ts   = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        crits = [f for f in self._findings if f["severity"]=="critical"]
        warns = [f for f in self._findings if f["severity"]=="warning"]
        infos = [f for f in self._findings if f["severity"]=="info"]
        lines = [
            "="*60, "  MC CHEAT SCANNER REPORT",
            f"  {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"  {os.environ.get('COMPUTERNAME','?')} / {os.environ.get('USERNAME','?')}",
            f"  Scanned: {self.app._mc_folder.get()}","="*60,"",
            f"  Total: {len(self._findings)}  Critical: {len(crits)}  Warning: {len(warns)}  Info: {len(infos)}","",
        ]
        for label, items, icon in [("CRITICAL",crits,"🔴"),("WARNING",warns,"🟠"),("INFO",infos,"🔵")]:
            if items:
                lines += ["", f"  {icon}  {label}", "  "+"-"*40]
                for f in items:
                    lines += [f"  {f['category']} — {f['detail']}", f"  {f['extra']}" if f["extra"] else "",""]
        txt = os.path.join(out, f"scan_{ts}.txt")
        jf  = os.path.join(out, f"scan_{ts}.json")
        open(txt,"w",encoding="utf-8").write("\n".join(lines))
        json.dump({"time":datetime.datetime.now().isoformat(),"findings":self._findings},
                   open(jf,"w"),indent=2)
        self._write(self._log, f"✔ Report: {txt}", "ok")
        self._write(self._log, f"✔ JSON:   {jf}", "ok")


class MemoryPage(BasePage):
    NAME = "Memory"

    def __init__(self, parent, app):
        super().__init__(parent, app)
        self._stop_mem = threading.Event()
        self._build()

    def _build(self):
        top = tk.Frame(self, bg=BG2)
        top.pack(fill="x")
        tk.Label(top, text="MEMORY SCANNER", font=("Segoe UI Semibold", 11),
                 bg=BG2, fg=ACCENT).pack(side="left", padx=20, pady=12)
        tk.Label(top, text="Scans javaw.exe RAM for cheat signatures",
                 font=UI, bg=BG2, fg=DIM).pack(side="left", padx=8)
        self._stop_btn = tk.Button(top, text="■  STOP", font=BOLD, bg=RED, fg="white",
                                    relief="flat", bd=0, padx=16, pady=6, cursor="hand2",
                                    state="disabled", command=lambda: self._stop_mem.set())
        self._stop_btn.pack(side="right", padx=8, pady=10)
        self._start_btn = tk.Button(top, text="▶  SCAN MEMORY", font=BOLD, bg=ACCENT, fg=BG,
                                     relief="flat", bd=0, padx=16, pady=6, cursor="hand2",
                                     command=self._start)
        self._start_btn.pack(side="right", pady=10)
        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")
        self._log = self._log_widget(self)
        self._log.pack(fill="both", expand=True, padx=10, pady=10)

    def _start(self):
        if sys.platform != "win32":
            self._write(self._log, "Memory scanning is Windows-only.", "warning"); return
        if not HAS_PSUTIL:
            self._write(self._log, "psutil required. Run from admin CMD.", "critical"); return
        self._stop_mem.clear()
        self._start_btn.configure(state="disabled")
        self._stop_btn.configure(state="normal")
        self._log.configure(state="normal"); self._log.delete("1.0","end"); self._log.configure(state="disabled")
        self.app.set_status("Memory scan running...")
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        self._write(self._log, f"Memory scan started {datetime.datetime.now().strftime('%H:%M:%S')}", "head")
        procs = []
        for p in psutil.process_iter(["pid","name"]):
            try:
                if "javaw" in (p.info["name"] or "").lower():
                    procs.append(p)
            except (psutil.NoSuchProcess, psutil.AccessDenied): pass

        if not procs:
            self._write(self._log, "No javaw.exe found — is Minecraft running?", "warning")
            self.after(0, lambda: (self._start_btn.configure(state="normal"),
                                   self._stop_btn.configure(state="disabled")))
            self.app.set_status("Memory scan: no Minecraft found")
            return

        MEM_COMMIT = 0x1000
        PAGE_READ  = {0x02,0x04,0x20,0x40}
        k32 = ctypes.windll.kernel32

        class MBI(ctypes.Structure):
            _fields_ = [
                ("BaseAddress",ctypes.c_void_p),("AllocationBase",ctypes.c_void_p),
                ("AllocationProtect",wintypes.DWORD),("RegionSize",ctypes.c_size_t),
                ("State",wintypes.DWORD),("Protect",wintypes.DWORD),("Type",wintypes.DWORD),
            ]

        total_hits = 0
        for proc in procs:
            self._write(self._log, f"\nScanning PID {proc.pid} ({proc.name()})…", "info")
            handle = k32.OpenProcess(0x0400 | 0x0010, False, proc.pid)
            if not handle:
                self._write(self._log, f"Cannot open PID {proc.pid} — need admin", "warning")
                continue
            hits, addr, scanned = set(), 0, 0
            while scanned < 512*1024*1024 and not self._stop_mem.is_set():
                mbi = MBI()
                if not k32.VirtualQueryEx(handle, ctypes.c_void_p(addr), ctypes.byref(mbi), ctypes.sizeof(mbi)):
                    break
                if mbi.State == MEM_COMMIT and mbi.Protect in PAGE_READ and mbi.RegionSize > 0:
                    buf = (ctypes.c_char * mbi.RegionSize)()
                    n   = ctypes.c_size_t(0)
                    if k32.ReadProcessMemory(handle, ctypes.c_void_p(addr), buf, mbi.RegionSize, ctypes.byref(n)):
                        chunk = bytes(buf[:n.value])
                        for sig in MEM_SIGS:
                            if sig in chunk and sig not in hits:
                                hits.add(sig)
                                dec = sig.decode("utf-8", errors="replace")
                                self._write(self._log, f"🔴 HIT: {dec}", "critical")
                                total_hits += 1
                    scanned += mbi.RegionSize
                addr = (addr or 0) + (mbi.RegionSize or 1)
                if addr >= 0x7FFFFFFFFFFF: break
            k32.CloseHandle(handle)
            if not hits: self._write(self._log, f"✔ PID {proc.pid} — Clean", "ok")
            else: self._write(self._log, f"⚠ PID {proc.pid} — {len(hits)} signature(s) found", "critical")

        self._write(self._log, f"\n── Done — {total_hits} total hit(s) ──", "head")
        self.app.set_status(f"Memory scan done — {total_hits} hit(s)")
        self.after(0, lambda: (self._start_btn.configure(state="normal"),
                               self._stop_btn.configure(state="disabled")))


class SysInfoPage(BasePage):
    NAME = "Sys Info"

    def __init__(self, parent, app):
        super().__init__(parent, app)
        self._build()

    def _build(self):
        top = tk.Frame(self, bg=BG2)
        top.pack(fill="x")
        tk.Label(top, text="SYSTEM INFO", font=("Segoe UI Semibold", 11),
                 bg=BG2, fg=ACCENT).pack(side="left", padx=20, pady=12)
        tk.Button(top, text="▶  RUN CHECKS", font=BOLD, bg=ORANGE, fg=BG,
                  relief="flat", bd=0, padx=16, pady=6, cursor="hand2",
                  command=self._start).pack(side="right", padx=10, pady=10)
        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")

        cards = tk.Frame(self, bg=BG)
        cards.pack(fill="x", padx=16, pady=12)

        self._uptime_var = tk.StringVar(value="—")
        self._hwid_var   = tk.StringVar(value="—")

        for label, var in [("⏱  MC Uptime", self._uptime_var)]:
            c = tk.Frame(cards, bg=BG3, padx=14, pady=10, bd=0,
                         highlightthickness=1, highlightbackground=BORDER)
            c.pack(side="left", fill="both", expand=True, padx=(0,8))
            tk.Label(c, text=label, font=("Consolas", 8), bg=BG3, fg=DIM).pack(anchor="w")
            tk.Label(c, textvariable=var, font=("Segoe UI Semibold", 13),
                     bg=BG3, fg=TEXT, wraplength=260, justify="left").pack(anchor="w", pady=(4,0))

        hwid_f = tk.Frame(self, bg=BG3, padx=16, pady=12, bd=0,
                          highlightthickness=1, highlightbackground=BORDER)
        hwid_f.pack(fill="x", padx=16, pady=(0,8))
        tk.Label(hwid_f, text="🖥  HWID", font=("Consolas", 8), bg=BG3, fg=DIM).pack(anchor="w")
        tk.Label(hwid_f, textvariable=self._hwid_var, font=MONO,
                 bg=BG3, fg=ACCENT, wraplength=900, justify="left").pack(anchor="w", pady=(4,0))

        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")
        self._log = self._log_widget(self)
        self._log.pack(fill="both", expand=True, padx=10, pady=10)

    def _start(self):
        self._log.configure(state="normal"); self._log.delete("1.0","end"); self._log.configure(state="disabled")
        self._uptime_var.set("Checking…")
        self._hwid_var.set("Generating…")
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        self._write(self._log, f"Checks started {datetime.datetime.now().strftime('%H:%M:%S')}", "head")
        self._write(self._log, f"Host: {os.environ.get('COMPUTERNAME','?')}  User: {os.environ.get('USERNAME','?')}", "dim")

        self._write(self._log, "\n── Minecraft Uptime ──", "head")
        uptime_str = "Not running"
        if HAS_PSUTIL:
            for p in psutil.process_iter(["pid","name","create_time"]):
                try:
                    if "javaw" in (p.info["name"] or "").lower():
                        ct = datetime.datetime.fromtimestamp(p.info["create_time"])
                        el = datetime.datetime.now() - ct
                        h = int(el.total_seconds()//3600)
                        m = int((el.total_seconds()%3600)//60)
                        s = int(el.total_seconds()%60)
                        uptime_str = f"PID {p.pid} — {h}h {m}m {s}s"
                        self._write(self._log, f"✔ {p.info['name']} started {ct.strftime('%H:%M:%S')} — up {h}h {m}m {s}s", "ok")
                        break
                except (psutil.NoSuchProcess, psutil.AccessDenied): pass
        if uptime_str == "Not running":
            self._write(self._log, "No Minecraft process found", "warning")
        self._uptime_var.set(uptime_str)

        self._write(self._log, "\n── HWID ──", "head")
        try:
            hwid = self._gen_hwid()
            self._hwid_var.set(hwid)
            self._write(self._log, "✔ HWID generated", "ok")
            self._write(self._log, hwid, "dim")
        except Exception as e:
            self._hwid_var.set(f"Error: {e}")
            self._write(self._log, f"HWID failed: {e}", "warning")

        self._write(self._log, "\n✔ All checks done", "ok")
        self.app.set_status("Sys info checks complete")

    def _gen_hwid(self):
        if sys.platform != "win32": return "Windows-only"
        def wq(q):
            r = subprocess.run(["powershell","-Command",q], capture_output=True, text=True, timeout=8)
            return r.stdout.strip()
        mb   = wq("(Get-WmiObject win32_baseboard).Manufacturer+' '+(Get-WmiObject win32_baseboard).SerialNumber")
        cpu  = wq("(Get-WmiObject Win32_Processor).Name")
        disk = wq("(Get-PhysicalDisk | Select-Object -First 1).SerialNumber")
        raw  = f"{mb}|{cpu}|{disk}"
        return base64.b64encode(raw.encode()).decode().replace("=","")


if __name__ == "__main__":
    if sys.platform == "win32" and not is_admin():
        ctypes.windll.shell32.ShellExecuteW(None,"runas",sys.executable," ".join(sys.argv),None,1)
        sys.exit(0)
    App().mainloop()
