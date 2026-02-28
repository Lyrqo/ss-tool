import tkinter as tk
from tkinter import ttk, filedialog, scrolledtext
import threading
import os
import sys
import re
import time
import datetime
import json
import ctypes
import ctypes.wintypes as wintypes
import urllib.request
import hashlib
import base64
import subprocess

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

try:
    import win32gui
    import win32con
    import win32api
    import win32process
    HAS_WIN32 = True
except ImportError:
    HAS_WIN32 = False

try:
    import pyautogui
    pyautogui.FAILSAFE = False
    pyautogui.PAUSE = 0.15
    HAS_PYAUTOGUI = True
except ImportError:
    HAS_PYAUTOGUI = False

CRYSTAL_KEYWORDS = [
    "AutoCrystal", "CrystalAura", "CrystalPlace", "PlaceCrystal",
    "BreakCrystal", "ExplodeCrystal", "CrystalSwap", "CSwap",
    "Surround", "AntiSurround", "SurroundBreaker", "Trap", "HoleFiller",
    "BedAura", "AnchorAura", "BedBomb", "AutoBed", "AutoAnchor",
    "AutoTotem", "TotemPopper", "PopCounter", "TotemCounter", "AutoOffhand",
    "PacketFly", "MotionFly", "ElytraFly", "ElytraBoost", "Phase",
    "KillAura", "AuraModule", "TriggerBot", "AutoClicker",
    "AutoObsidian", "ObsidianFiller", "AutoSwap", "OffhandSwap",
    "sendPacket", "injectPacket", "ClassFileTransformer", "bytebuddy",
]

SI_PATHS = [
    r"C:\Program Files\SystemInformer\SystemInformer.exe",
    r"C:\Program Files (x86)\SystemInformer\SystemInformer.exe",
    r"C:\Program Files\Process Hacker 2\ProcessHacker.exe",
    r"C:\Program Files (x86)\Process Hacker 2\ProcessHacker.exe",
    r"C:\Tools\SystemInformer\SystemInformer.exe",
    r"C:\Tools\ProcessHacker\ProcessHacker.exe",
]

SI_WINDOW_CLASSES = ["MainWindowClass", "ProcessHacker"]

CHEAT_NAMES = [
    "wurst", "impact", "future", "liquidbounce", "aristois", "meteor",
    "killaura", "sigma", "entropy", "novoline", "rusherhack", "vape",
    "astolfo", "inertia", "ghost", "rise", "tenacity", "nearbyplayers",
    "aura", "esp", "aimbot", "bhop", "scaffold", "velocity", "criticals",
    "nofall", "autoeat", "autofish", "tracers", "xray", "freecam",
    "fly", "speed", "jesus", "mixin", "bytebuddy", "javassist",
    "classinjector", "agentmain", "premain", "instrumentation",
]

BAD_JVM_FLAGS = [
    "-javaagent", "-agentlib", "-agentpath",
    "-Xbootclasspath", "bytebuddy", "javassist", "premain", "agentmain",
]

MEM_SIGS = [
    b"sendPacket", b"handlePacket", b"injectPacket", b"fakePacket",
    b"KillAura", b"killaura", b"AimAssist", b"AutoCrystal", b"autocrystal",
    b"Scaffold", b"scaffold", b"ClickTP", b"Velocity", b"NoFall",
    b"Freecam", b"ESP", b"Tracers", b"Xray", b"xray", b"BHop",
    b"Speed", b"Flight", b"flight", b"AutoEat", b"AutoFish",
    b"CrystalAura", b"BaritoneAPI", b"baritone.api", b"PathingCommand",
    b"agentmain", b"premain", b"ClassFileTransformer", b"Instrumentation",
    b"redefineClasses", b"bytebuddy", b"net.bytebuddy", b"javassist",
    b"aimbot", b"wallhack", b"noclip", b"autoclick", b"triggerbot",
    b"noknockback", b"antiknockback",
]

SCAN_EXTS = {".jar", ".zip", ".class", ".json", ".cfg", ".properties"}

BG     = "#0d0f14"
BG2    = "#13161e"
BG3    = "#1a1d27"
ACCENT = "#00e5ff"
RED    = "#ff4757"
GREEN  = "#2ed573"
ORANGE = "#ffa502"
TEXT   = "#e8eaf0"
DIM    = "#6b7280"
BORDER = "#252836"
MONO   = ("Consolas", 9)
UI     = ("Segoe UI", 10)
BOLD   = ("Segoe UI Semibold", 11)

class FolderPrompt(tk.Tk):
    """Initial popup that asks for the Minecraft folder before the main scanner opens."""

    def __init__(self):
        super().__init__()
        self.title("MC Cheat Scanner — Setup")
        self.geometry("560x220")
        self.resizable(False, False)
        self.configure(bg=BG)
        self.result = None

        self.eval('tk::PlaceWindow . center')

        tk.Label(self, text="⚡  MC CHEAT SCANNER", font=("Segoe UI Semibold", 14),
                 bg=BG, fg=ACCENT).pack(pady=(22, 4))
        tk.Label(self, text="Enter the Minecraft instance folder to scan\n(e.g. the folder containing mods/, config/, etc.)",
                 font=UI, bg=BG, fg=DIM, justify="center").pack(pady=(0, 12))

        row = tk.Frame(self, bg=BG)
        row.pack(fill="x", padx=24)

        self._entry = tk.Entry(row, font=UI, bg=BG2, fg=TEXT,
                                insertbackground=ACCENT, relief="flat", bd=0,
                                highlightthickness=1, highlightcolor=ACCENT,
                                highlightbackground=BORDER)
        self._entry.pack(side="left", fill="x", expand=True, ipady=6, padx=(0, 8))

        tk.Button(row, text="📁 Browse", font=UI, bg=BG2, fg=ACCENT,
                  activebackground=BORDER, activeforeground=ACCENT,
                  relief="flat", bd=0, padx=10, pady=4, cursor="hand2",
                  command=self._browse).pack(side="left")

        tk.Button(self, text="▶  START SCAN", font=BOLD, bg=GREEN, fg=BG,
                  activebackground="#26c25a", activeforeground=BG,
                  relief="flat", bd=0, padx=24, pady=8, cursor="hand2",
                  command=self._confirm).pack(pady=18)

        self._entry.focus()
        self.bind("<Return>", lambda e: self._confirm())

    def _browse(self):
        d = filedialog.askdirectory(title="Select Minecraft instance folder")
        if d:
            self._entry.delete(0, "end")
            self._entry.insert(0, d)

    def _confirm(self):
        path = self._entry.get().strip()
        if not path:
            self._entry.configure(highlightbackground=RED)
            return
        if not os.path.isdir(path):
            self._entry.configure(highlightbackground=RED)
            tk.Label(self, text="⚠  Folder not found!", font=UI, bg=BG, fg=RED).pack()
            return
        self.result = path
        self.destroy()

class Scanner(tk.Tk):
    def __init__(self, mc_folder):
        super().__init__()
        self.title("MC Cheat Scanner  v2.0")
        self.geometry("1050x720")
        self.minsize(900, 600)
        self.configure(bg=BG)

        self._mc_folder = mc_folder

        self._thread   = None
        self._stop     = threading.Event()
        self._outdir   = tk.StringVar()
        self._status   = tk.StringVar(value="Ready")
        self._progress = tk.DoubleVar()
        self._findings = []
        self._mc_procs = []

        self._build()
        self._check_deps()
        self._write(f"  📁  Scanning folder: {self._mc_folder}", "ok")
        self.after(800, self._auto_sysinfo)

    def _build(self):
        header = tk.Frame(self, bg=BG2, height=56)
        header.pack(fill="x")
        header.pack_propagate(False)

        tf = tk.Frame(header, bg=BG2)
        tf.pack(side="left", padx=20, pady=10)
        tk.Label(tf, text="⚡", font=("Segoe UI", 18), bg=BG2, fg=ACCENT).pack(side="left")
        tk.Label(tf, text="  MC CHEAT SCANNER", font=("Segoe UI Semibold", 14), bg=BG2, fg=TEXT).pack(side="left")
        tk.Label(tf, text="  v3.0", font=UI, bg=BG2, fg=DIM).pack(side="left")

        self._status_lbl = tk.Label(header, textvariable=self._status,
                                     font=UI, bg=GREEN, fg=BG, padx=10, pady=2)
        self._status_lbl.pack(side="right", padx=20, pady=16)

        tk.Frame(self, bg=BORDER, height=1).pack(fill="x")

        style = ttk.Style()
        style.theme_use("clam")
        style.configure("scan.Horizontal.TProgressbar",
                         troughcolor=BG2, background=ACCENT,
                         lightcolor=ACCENT, darkcolor=ACCENT, bordercolor=BG)
        style.configure("Dark.TNotebook", background=BG2, borderwidth=0)
        style.configure("Dark.TNotebook.Tab", background=BG3, foreground=DIM,
                         padding=[16, 6], font=("Segoe UI", 10))
        style.map("Dark.TNotebook.Tab",
                   background=[("selected", BG)],
                   foreground=[("selected", ACCENT)])

        self._notebook = ttk.Notebook(self, style="Dark.TNotebook")
        self._notebook.pack(fill="both", expand=True)

        self._build_scan_tab()
        self._build_sysinfo_tab()

        bar = tk.Frame(self, bg=BG3, height=26)
        bar.pack(fill="x", side="bottom")
        bar.pack_propagate(False)

        self._bot_lbl = tk.Label(bar, text="Select an output folder and press START SCAN",
                                  font=("Segoe UI", 8), bg=BG3, fg=DIM)
        self._bot_lbl.pack(side="left", padx=12, pady=4)

        self._time_lbl = tk.Label(bar, text="", font=("Segoe UI", 8), bg=BG3, fg=DIM)
        self._time_lbl.pack(side="right", padx=12)

    def _build_scan_tab(self):
        tab = tk.Frame(self._notebook, bg=BG)
        self._notebook.add(tab, text="  🔍  Cheat Scanner  ")

        cfg = tk.Frame(tab, bg=BG3, pady=12)
        cfg.pack(fill="x")

        tk.Label(cfg, text="Output Folder:", font=BOLD, bg=BG3, fg=DIM).pack(side="left", padx=(20, 8))

        self._dir_entry = tk.Entry(cfg, textvariable=self._outdir, font=UI,
                                    bg=BG, fg=TEXT, insertbackground=ACCENT,
                                    relief="flat", bd=0, highlightthickness=1,
                                    highlightcolor=ACCENT, highlightbackground=BORDER, width=40)
        self._dir_entry.pack(side="left", ipady=5, padx=(0, 8))

        tk.Button(cfg, text="📁  Browse", font=UI, bg=BG2, fg=ACCENT,
                  activebackground=BORDER, activeforeground=ACCENT,
                  relief="flat", bd=0, padx=14, pady=5, cursor="hand2",
                  command=self._browse).pack(side="left", padx=(0, 12))

        tk.Label(cfg, text=f"🗂  {self._mc_folder}", font=("Segoe UI", 9),
                 bg=BG3, fg=ACCENT).pack(side="left", padx=(0, 12))

        self._start_btn = tk.Button(cfg, text="▶  START SCAN", font=BOLD,
                                     bg=GREEN, fg=BG, activebackground="#26c25a",
                                     activeforeground=BG, relief="flat", bd=0,
                                     padx=20, pady=6, cursor="hand2",
                                     command=self._start)
        self._start_btn.pack(side="left", padx=(0, 8))

        self._stop_btn = tk.Button(cfg, text="■  STOP", font=BOLD, bg=RED,
                                    fg="white", activebackground="#c0392b",
                                    activeforeground="white", relief="flat",
                                    bd=0, padx=20, pady=6, cursor="hand2",
                                    command=self._do_stop, state="disabled")
        self._stop_btn.pack(side="left")

        pb_frame = tk.Frame(tab, bg=BG, pady=6)
        pb_frame.pack(fill="x", padx=20)
        ttk.Progressbar(pb_frame, variable=self._progress,
                         style="scan.Horizontal.TProgressbar",
                         maximum=100).pack(fill="x")

        tk.Frame(tab, bg=BORDER, height=1).pack(fill="x")
        content = tk.Frame(tab, bg=BG)
        content.pack(fill="both", expand=True)

        left = tk.Frame(content, bg=BG2, width=340)
        left.pack(side="left", fill="y")
        left.pack_propagate(False)

        tk.Label(left, text="  🔍  FINDINGS", font=BOLD, bg=BG2, fg=ACCENT, anchor="w").pack(fill="x", padx=12, pady=(12, 4))
        tk.Frame(left, bg=BORDER, height=1).pack(fill="x")

        lb_wrap = tk.Frame(left, bg=BG2)
        lb_wrap.pack(fill="both", expand=True, padx=8, pady=8)

        sb = tk.Scrollbar(lb_wrap, bg=BG2, troughcolor=BG, bd=0, relief="flat")
        sb.pack(side="right", fill="y")

        self._lb = tk.Listbox(lb_wrap, bg=BG2, fg=TEXT, selectbackground=ACCENT,
                               selectforeground=BG, font=MONO, relief="flat", bd=0,
                               yscrollcommand=sb.set, activestyle="none", cursor="hand2")
        self._lb.pack(side="left", fill="both", expand=True)
        sb.config(command=self._lb.yview)
        self._lb.bind("<<ListboxSelect>>", self._on_select)

        counts = tk.Frame(left, bg=BG3, pady=6)
        counts.pack(fill="x")

        self._c_crit = tk.StringVar(value="0")
        self._c_warn = tk.StringVar(value="0")
        self._c_info = tk.StringVar(value="0")

        for label, var, color in [("🔴 Critical", self._c_crit, RED),
                                    ("🟠 Warning",  self._c_warn, ORANGE),
                                    ("🔵 Info",     self._c_info, ACCENT)]:
            f = tk.Frame(counts, bg=BG3)
            f.pack(side="left", expand=True)
            tk.Label(f, text=label, font=("Segoe UI", 8), bg=BG3, fg=DIM).pack()
            tk.Label(f, textvariable=var, font=("Segoe UI Semibold", 16), bg=BG3, fg=color).pack()

        right = tk.Frame(content, bg=BG)
        right.pack(side="left", fill="both", expand=True)

        tk.Label(right, text="  📋  SCAN LOG", font=BOLD, bg=BG, fg=ACCENT, anchor="w").pack(fill="x", padx=12, pady=(12, 4))
        tk.Frame(right, bg=BORDER, height=1).pack(fill="x")

        self._log = scrolledtext.ScrolledText(right, bg=BG, fg=TEXT, font=MONO,
                                               relief="flat", bd=0,
                                               insertbackground=ACCENT,
                                               state="disabled", wrap="word",
                                               padx=10, pady=8)
        self._log.pack(fill="both", expand=True)

        self._log.tag_config("head",     foreground=ACCENT,  font=("Consolas", 9, "bold"))
        self._log.tag_config("critical", foreground=RED,     font=("Consolas", 9, "bold"))
        self._log.tag_config("warning",  foreground=ORANGE)
        self._log.tag_config("info",     foreground=ACCENT)
        self._log.tag_config("ok",       foreground=GREEN)
        self._log.tag_config("dim",      foreground=DIM)
        self._log.tag_config("normal",   foreground=TEXT)

    def _build_sysinfo_tab(self):
        tab = tk.Frame(self._notebook, bg=BG)
        self._notebook.add(tab, text="  🌐  System Info  ")

        top = tk.Frame(tab, bg=BG3, pady=10)
        top.pack(fill="x")

        self._sysinfo_btn = tk.Button(top, text="▶  RUN CHECKS", font=BOLD,
                                       bg=GREEN, fg=BG, activebackground="#26c25a",
                                       activeforeground=BG, relief="flat", bd=0,
                                       padx=20, pady=6, cursor="hand2",
                                       command=self._start_sysinfo)
        self._sysinfo_btn.pack(side="left", padx=20)

        tk.Label(top, text="Checks country, VPN, HWID and Minecraft uptime",
                 font=UI, bg=BG3, fg=DIM).pack(side="left", padx=8)

        tk.Frame(tab, bg=BORDER, height=1).pack(fill="x")

        cards = tk.Frame(tab, bg=BG)
        cards.pack(fill="x", padx=16, pady=12)

        def make_card(parent, title):
            card = tk.Frame(parent, bg=BG2, padx=14, pady=10)
            card.pack(side="left", fill="both", expand=True, padx=6)
            tk.Label(card, text=title, font=("Segoe UI", 8), bg=BG2, fg=DIM).pack(anchor="w")
            val = tk.StringVar(value="—")
            lbl = tk.Label(card, textvariable=val, font=("Segoe UI Semibold", 13),
                            bg=BG2, fg=TEXT, wraplength=220, justify="left")
            lbl.pack(anchor="w", pady=(2, 0))
            return val, lbl

        self._si_country, self._si_country_lbl = make_card(cards, "🌍  Country")
        self._si_vpn,     self._si_vpn_lbl     = make_card(cards, "🔒  VPN / Proxy")
        self._si_uptime,  self._si_uptime_lbl  = make_card(cards, "⏱  Minecraft Uptime")

        tk.Frame(tab, bg=BORDER, height=1).pack(fill="x")

        hwid_frame = tk.Frame(tab, bg=BG3, pady=14)
        hwid_frame.pack(fill="x", padx=16, pady=(8, 0))

        tk.Label(hwid_frame, text="🖥  HWID", font=BOLD, bg=BG3, fg=ACCENT).pack(anchor="w", padx=4)
        self._si_hwid = tk.StringVar(value="—")
        tk.Label(hwid_frame, textvariable=self._si_hwid, font=MONO,
                 bg=BG3, fg=TEXT, wraplength=900, justify="left").pack(anchor="w", padx=4, pady=(4, 0))

        tk.Frame(tab, bg=BORDER, height=1).pack(fill="x", pady=(8, 0))

        tk.Label(tab, text="  📋  LOG", font=BOLD, bg=BG, fg=ACCENT, anchor="w").pack(fill="x", padx=12, pady=(8, 4))

        self._si_log = scrolledtext.ScrolledText(tab, bg=BG, fg=TEXT, font=MONO,
                                                  relief="flat", bd=0,
                                                  insertbackground=ACCENT,
                                                  state="disabled", wrap="word",
                                                  padx=10, pady=8)
        self._si_log.pack(fill="both", expand=True)

        self._si_log.tag_config("head",    foreground=ACCENT, font=("Consolas", 9, "bold"))
        self._si_log.tag_config("ok",      foreground=GREEN)
        self._si_log.tag_config("warning", foreground=ORANGE)
        self._si_log.tag_config("critical",foreground=RED, font=("Consolas", 9, "bold"))
        self._si_log.tag_config("dim",     foreground=DIM)
        self._si_log.tag_config("normal",  foreground=TEXT)

    def _write(self, text, tag="normal"):
        self._log.configure(state="normal")
        self._log.insert("end", text + "\n", tag)
        self._log.configure(state="disabled")
        self._log.see("end")

    def _section(self, title):
        self._write(f"\n{'─' * 60}", "dim")
        self._write(f"  {title}", "head")
        self._write(f"{'─' * 60}", "dim")

    def _finding(self, severity, category, detail, extra=""):
        self._findings.append({
            "severity": severity, "category": category,
            "detail": detail, "extra": extra,
            "time": datetime.datetime.now().isoformat(),
        })
        icon  = {"critical": "🔴", "warning": "🟠", "info": "🔵"}.get(severity, "⚪")
        short = f"{icon} {category}: {detail[:48]}{'…' if len(detail) > 48 else ''}"
        self._lb.insert("end", short)
        color = {"critical": RED, "warning": ORANGE, "info": ACCENT}.get(severity, TEXT)
        self._lb.itemconfig(self._lb.size() - 1, fg=color)
        self._c_crit.set(str(sum(1 for f in self._findings if f["severity"] == "critical")))
        self._c_warn.set(str(sum(1 for f in self._findings if f["severity"] == "warning")))
        self._c_info.set(str(sum(1 for f in self._findings if f["severity"] == "info")))

    def _on_select(self, _):
        sel = self._lb.curselection()
        if not sel or sel[0] >= len(self._findings):
            return
        f = self._findings[sel[0]]
        self._write("\n  ━━ Finding Detail ━━", "head")
        self._write(f"  Severity : {f['severity'].upper()}", "warning")
        self._write(f"  Category : {f['category']}", "normal")
        self._write(f"  Detail   : {f['detail']}", "normal")
        if f["extra"]:
            self._write(f"  Extra    : {f['extra']}", "dim")
        self._write(f"  Time     : {f['time']}", "dim")

    def _set_status(self, text, color=GREEN):
        self._status.set(text)
        self._status_lbl.configure(bg=color)
        self._bot_lbl.configure(text=text)

    def _browse(self):
        d = filedialog.askdirectory(title="Choose output folder")
        if d:
            self._outdir.set(d)

    def _check_deps(self):
        if not HAS_PSUTIL:
            self._write("⚠  psutil missing — pip install psutil", "warning")
        else:
            self._write("✔  psutil ready", "ok")
        if sys.platform != "win32":
            self._write("⚠  Memory scanning is Windows-only", "warning")
        else:
            self._write("✔  Windows detected", "ok")
        if not HAS_WIN32:
            self._write("⚠  pywin32 missing — pip install pywin32  (System Informer step needs this)", "warning")
        else:
            self._write("✔  pywin32 ready", "ok")
        if not HAS_PYAUTOGUI:
            self._write("⚠  pyautogui missing — pip install pyautogui  (System Informer step needs this)", "warning")
        else:
            self._write("✔  pyautogui ready", "ok")
        try:
            admin = ctypes.windll.shell32.IsUserAnAdmin()
        except Exception:
            admin = False
        self._write("✔  Running as Administrator" if admin else
                    "⚠  Not Administrator — some processes may be skipped",
                    "ok" if admin else "warning")
        self._write("\nSelect an output folder and press  ▶ START SCAN", "dim")

    def _start(self):
        if not self._outdir.get():
            self._write("❌  Select an output folder first!", "critical")
            return
        if not os.path.isdir(self._outdir.get()):
            self._write("❌  Output folder doesn't exist!", "critical")
            return

        self._findings.clear()
        self._lb.delete(0, "end")
        self._c_crit.set("0")
        self._c_warn.set("0")
        self._c_info.set("0")
        self._log.configure(state="normal")
        self._log.delete("1.0", "end")
        self._log.configure(state="disabled")
        self._progress.set(0)
        self._stop.clear()

        self._start_btn.configure(state="disabled")
        self._stop_btn.configure(state="normal")
        self._set_status("Scanning…", ORANGE)

        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _do_stop(self):
        self._stop.set()
        self._set_status("Stopping…", RED)

    def _done(self, cancelled=False):
        self._start_btn.configure(state="normal")
        self._stop_btn.configure(state="disabled")
        if cancelled:
            self._set_status("Stopped", RED)
        else:
            crits = sum(1 for f in self._findings if f["severity"] == "critical")
            self._set_status(f"Done — {len(self._findings)} finding(s), {crits} critical",
                              RED if crits else GREEN)

    def _run(self):
        t0 = time.time()
        self._write(f"\n  Started : {datetime.datetime.now().strftime('%Y-%m-%d  %H:%M:%S')}", "head")
        self._write(f"  Host    : {os.environ.get('COMPUTERNAME', 'Unknown')}", "dim")
        self._write(f"  User    : {os.environ.get('USERNAME', 'Unknown')}", "dim")
        self._write(f"  Folder  : {self._mc_folder}\n", "dim")

        steps = [
            ("Finding Minecraft processes",             self._scan_procs),
            ("Checking JVM arguments",                  self._scan_jvm),
            ("Checking open file handles",              self._scan_handles),
            ("Scanning process memory",                 self._scan_memory),
            ("Scanning Minecraft folders",              self._scan_dirs),
            ("Checking startup entries",                self._scan_startup),
            ("System Informer — crystal PVP deep scan", self._run_si_scan),
            ("Writing report",                          self._write_report),
        ]

        for i, (label, fn) in enumerate(steps):
            if self._stop.is_set():
                self._write("\n⚠  Stopped by user.", "warning")
                self.after(0, self._done, True)
                return
            self._progress.set((i / len(steps)) * 100)
            self._section(f"{i+1}/{len(steps)}  —  {label}")
            try:
                fn()
            except Exception as e:
                self._write(f"  ⚠  Error: {e}", "warning")

        elapsed = time.time() - t0
        self._progress.set(100)
        self._time_lbl.configure(text=f"Scan time: {elapsed:.1f}s")
        self._write(f"\n✔  Finished in {elapsed:.1f}s", "ok")
        self.after(0, self._done, False)

    def _scan_procs(self):
        if not HAS_PSUTIL:
            self._write("  psutil unavailable — skipping", "dim")
            return
        self._mc_procs = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                name = (proc.info['name'] or "").lower()
                cmd  = " ".join(proc.info['cmdline'] or []).lower()
                if ("java" in name or "minecraft" in name) and \
                   any(k in cmd for k in ["minecraft", "lwjgl", "net.minecraft", "forge", "fabric"]):
                    self._mc_procs.append(proc)
                    self._write(f"  ✔  Minecraft — PID {proc.pid}  ({proc.info['name']})", "ok")
                    self._finding("info", "Process", f"Minecraft PID {proc.pid}", proc.info['name'])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        if not self._mc_procs:
            self._write("  No running Minecraft instances found — file scan will still run", "dim")

    def _scan_jvm(self):
        if not self._mc_procs:
            self._write("  No processes to check", "dim")
            return
        for proc in self._mc_procs:
            try:
                cmd = " ".join(proc.cmdline())
                for flag in BAD_JVM_FLAGS:
                    if flag.lower() in cmd.lower():
                        sev = "critical" if flag.startswith("-") else "warning"
                        self._write(f"  {'🔴' if sev == 'critical' else '🟠'}  Suspicious flag: {flag}", sev)
                        self._finding(sev, "JVM Flag", f"'{flag}' in PID {proc.pid}", cmd[:200])
                agents = re.findall(r'-javaagent[=:]([^\s"]+)', cmd, re.IGNORECASE)
                for agent in agents:
                    self._write(f"  🔴  Agent JAR: {agent}", "critical")
                    self._finding("critical", "Java Agent", f"Agent: {os.path.basename(agent)}", agent)
                    for cheat in CHEAT_NAMES:
                        if cheat in agent.lower():
                            self._write(f"  🚨  KNOWN CHEAT MATCH: {cheat.upper()}", "critical")
                            self._finding("critical", "Known Cheat", f"Matches: {cheat}", agent)
                if not agents:
                    self._write(f"  ✔  No agent flags — PID {proc.pid}", "ok")
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                self._write(f"  ⚠  Access denied PID {proc.pid}", "warning")

    def _scan_handles(self):
        if not self._mc_procs:
            self._write("  No processes to check", "dim")
            return
        for proc in self._mc_procs:
            try:
                files = proc.open_files()
                self._write(f"  PID {proc.pid} — {len(files)} open handle(s)", "info")
                for f in files:
                    pl = f.path.lower()
                    for cheat in CHEAT_NAMES:
                        if cheat in pl:
                            self._write(f"  🔴  Cheat file open: {f.path}", "critical")
                            self._finding("critical", "Cheat File Handle", f"Matches '{cheat}'", f.path)
                    if f.path.endswith(".jar") and "minecraft" not in pl:
                        self._write(f"  🟠  Unknown JAR: {f.path}", "warning")
                        self._finding("warning", "Unknown JAR", "Unexpected JAR open by Minecraft", f.path)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                self._write(f"  ⚠  Access denied PID {proc.pid}", "warning")

    def _scan_memory(self):
        if sys.platform != "win32" or not self._mc_procs:
            self._write("  Skipped (Windows-only / no processes)", "dim")
            return

        MEM_COMMIT    = 0x1000
        PAGE_READABLE = {0x02, 0x04, 0x20, 0x40}
        k32           = ctypes.windll.kernel32

        class MBI(ctypes.Structure):
            _fields_ = [
                ("BaseAddress",       ctypes.c_void_p),
                ("AllocationBase",    ctypes.c_void_p),
                ("AllocationProtect", wintypes.DWORD),
                ("RegionSize",        ctypes.c_size_t),
                ("State",             wintypes.DWORD),
                ("Protect",           wintypes.DWORD),
                ("Type",              wintypes.DWORD),
            ]

        for proc in self._mc_procs:
            self._write(f"  Scanning PID {proc.pid}…", "info")
            handle = k32.OpenProcess(0x0400 | 0x0010, False, proc.pid)
            if not handle:
                self._write(f"  ⚠  Can't open PID {proc.pid}", "warning")
                continue

            hits, addr, scanned = set(), 0, 0
            while scanned < 512 * 1024 * 1024 and not self._stop.is_set():
                mbi = MBI()
                if not k32.VirtualQueryEx(handle, ctypes.c_void_p(addr),
                                           ctypes.byref(mbi), ctypes.sizeof(mbi)):
                    break
                if mbi.State == MEM_COMMIT and mbi.Protect in PAGE_READABLE and mbi.RegionSize > 0:
                    buf = (ctypes.c_char * mbi.RegionSize)()
                    n   = ctypes.c_size_t(0)
                    if k32.ReadProcessMemory(handle, ctypes.c_void_p(addr),
                                              buf, mbi.RegionSize, ctypes.byref(n)):
                        chunk = bytes(buf[:n.value])
                        for sig in MEM_SIGS:
                            if sig in chunk and sig not in hits:
                                hits.add(sig)
                                dec = sig.decode("utf-8", errors="replace")
                                self._write(f"  🔴  Memory hit: {dec}", "critical")
                                self._finding("critical", "Memory Signature",
                                               f"'{dec}' in PID {proc.pid} memory")
                    scanned += mbi.RegionSize
                addr = (addr or 0) + (mbi.RegionSize or 1)
                if addr >= 0x7FFFFFFFFFFF:
                    break

            k32.CloseHandle(handle)
            if not hits:
                self._write(f"  ✔  Clean — PID {proc.pid}", "ok")
            else:
                self._write(f"  ⚠  {len(hits)} hit(s) in PID {proc.pid}", "warning")

    def _scan_dirs(self):
        """Scan the user-provided Minecraft folder instead of the default path."""
        root = self._mc_folder
        self._write(f"  Scanning: {root}", "info")

        for dirpath, dirnames, filenames in os.walk(root):
            if self._stop.is_set():
                return
            dirnames[:] = [d for d in dirnames if d.lower() not in
                            {"versions", "assets", "libraries", "natives", "cache"}]
            for fname in filenames:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in SCAN_EXTS:
                    continue
                fpath = os.path.join(dirpath, fname)
                for cheat in CHEAT_NAMES:
                    if cheat in fname.lower():
                        self._write(f"  🔴  Cheat file: {fname}", "critical")
                        self._finding("critical", "Cheat File", f"Matches '{cheat}'", fpath)
                if ext in {".json", ".cfg", ".properties"}:
                    try:
                        content = open(fpath, errors="replace").read(65536).lower()
                        for cheat in CHEAT_NAMES:
                            if cheat in content:
                                self._write(f"  🟠  Cheat string in config: {fname}", "warning")
                                self._finding("warning", "Config Match",
                                               f"'{cheat}' in config file", fpath)
                                break
                    except Exception:
                        pass

    def _scan_startup(self):
        if sys.platform != "win32":
            self._write("  Skipped (Windows-only)", "dim")
            return
        dirs = [
            os.path.join(os.environ.get("APPDATA", ""),
                          r"Microsoft\Windows\Start Menu\Programs\Startup"),
            os.path.join(os.environ.get("PROGRAMDATA", ""),
                          r"Microsoft\Windows\Start Menu\Programs\Startup"),
        ]
        for d in dirs:
            if os.path.isdir(d):
                for item in os.listdir(d):
                    for cheat in CHEAT_NAMES:
                        if cheat in item.lower():
                            self._write(f"  🔴  Cheat in startup: {item}", "critical")
                            self._finding("critical", "Startup Entry",
                                           f"Matches '{cheat}'", os.path.join(d, item))
        try:
            import winreg
            for hive, path in [
                (winreg.HKEY_CURRENT_USER,  r"Software\Microsoft\Windows\CurrentVersion\Run"),
                (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Run"),
            ]:
                try:
                    key = winreg.OpenKey(hive, path)
                    i   = 0
                    while True:
                        try:
                            name, val, _ = winreg.EnumValue(key, i)
                            for cheat in CHEAT_NAMES:
                                if cheat in val.lower() or cheat in name.lower():
                                    self._write(f"  🔴  Registry Run: {name}", "critical")
                                    self._finding("critical", "Registry Run",
                                                   f"'{name}' matches '{cheat}'", val)
                            i += 1
                        except OSError:
                            break
                    winreg.CloseKey(key)
                except OSError:
                    pass
        except ImportError:
            pass
        self._write("  ✔  Done", "ok")

    def _auto_sysinfo(self):
        self._notebook.select(1)
        self._start_sysinfo()

    def _si_write(self, text, tag="normal"):
        self._si_log.configure(state="normal")
        self._si_log.insert("end", text + "\n", tag)
        self._si_log.configure(state="disabled")
        self._si_log.see("end")

    def _start_sysinfo(self):
        self._sysinfo_btn.configure(state="disabled")
        self._si_country.set("Checking…")
        self._si_vpn.set("Checking…")
        self._si_uptime.set("Checking…")
        self._si_hwid.set("Generating…")
        self._si_log.configure(state="normal")
        self._si_log.delete("1.0", "end")
        self._si_log.configure(state="disabled")
        threading.Thread(target=self._run_sysinfo, daemon=True).start()

    def _run_sysinfo(self):
        self._si_write(f"\n  Started : {datetime.datetime.now().strftime('%Y-%m-%d  %H:%M:%S')}", "head")
        self._si_write(f"  Host    : {os.environ.get('COMPUTERNAME', 'Unknown')}", "dim")
        self._si_write(f"  User    : {os.environ.get('USERNAME', 'Unknown')}\n", "dim")

        self._si_write("  ─── Country & VPN ───────────────────────────────────────", "dim")
        try:
            req = urllib.request.Request(
                "https://api.ip2location.io/",
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req, timeout=8) as r:
                ip_data = json.loads(r.read().decode())

            country = ip_data.get("country_name", "Unknown")
            is_proxy = ip_data.get("is_proxy", False)
            ip_addr  = ip_data.get("ip", "Unknown")

            self._si_country.set(country)
            self._si_country_lbl.configure(fg=TEXT)
            self._si_write(f"  ✔  IP: {ip_addr}", "ok")
            self._si_write(f"  ✔  Country: {country}", "ok")

            if is_proxy:
                self._si_vpn.set("⚠  VPN / Proxy Detected")
                self._si_vpn_lbl.configure(fg=RED)
                self._si_write("  🔴  VPN or proxy detected via ip2location", "critical")
                self._finding("critical", "VPN Detected", f"IP {ip_addr} flagged as proxy/VPN")
            else:
                vpn_adapter = self._detect_vpn_adapter()
                if vpn_adapter:
                    self._si_vpn.set(f"⚠  VPN Adapter: {vpn_adapter}")
                    self._si_vpn_lbl.configure(fg=ORANGE)
                    self._si_write(f"  🟠  VPN adapter found: {vpn_adapter}", "warning")
                    self._finding("warning", "VPN Adapter", f"Adapter without MAC: {vpn_adapter}")
                else:
                    self._si_vpn.set("✔  No VPN Detected")
                    self._si_vpn_lbl.configure(fg=GREEN)
                    self._si_write("  ✔  No VPN detected", "ok")

        except Exception as e:
            self._si_country.set("Error")
            self._si_vpn.set("Error")
            self._si_write(f"  ⚠  Could not reach ip2location: {e}", "warning")

        self._si_write("\n  ─── Minecraft Uptime ────────────────────────────────────", "dim")
        try:
            uptime_str = "Not running"
            if HAS_PSUTIL:
                for proc in psutil.process_iter(['pid', 'name', 'create_time']):
                    try:
                        name = (proc.info['name'] or "").lower()
                        if "javaw" in name or "java" in name:
                            ct = datetime.datetime.fromtimestamp(proc.info['create_time'])
                            elapsed = datetime.datetime.now() - ct
                            h = int(elapsed.total_seconds() // 3600)
                            m = int((elapsed.total_seconds() % 3600) // 60)
                            s = int(elapsed.total_seconds() % 60)
                            uptime_str = f"PID {proc.pid} — {h}h {m}m {s}s"
                            self._si_write(f"  ✔  {proc.info['name']} PID {proc.pid} started at {ct.strftime('%H:%M:%S')} — running {h}h {m}m {s}s", "ok")
                            break
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
            if uptime_str == "Not running":
                self._si_write("  ⚠  No Minecraft process found", "warning")
            self._si_uptime.set(uptime_str)
        except Exception as e:
            self._si_uptime.set("Error")
            self._si_write(f"  ⚠  Uptime check failed: {e}", "warning")

        self._si_write("\n  ─── HWID ────────────────────────────────────────────────", "dim")
        try:
            hwid = self._generate_hwid()
            self._si_hwid.set(hwid)
            self._si_write(f"  ✔  HWID generated", "ok")
            self._si_write(f"  {hwid}", "dim")
        except Exception as e:
            self._si_hwid.set("Error")
            self._si_write(f"  ⚠  HWID generation failed: {e}", "warning")

        self._si_write("\n  ✔  All checks complete", "ok")
        self.after(0, lambda: self._sysinfo_btn.configure(state="normal"))

    def _detect_vpn_adapter(self):
        if sys.platform != "win32":
            return None
        try:
            result = subprocess.run(
                ["powershell", "-Command",
                 "Get-NetAdapter | Where-Object { -not $_.MacAddress -and $_.Status -eq 'Up' } | Select-Object -ExpandProperty Name"],
                capture_output=True, text=True, timeout=8
            )
            name = result.stdout.strip()
            return name if name else None
        except Exception:
            return None

    def _generate_hwid(self):
        if sys.platform != "win32":
            return "Windows-only"
        try:
            def wmi_val(query):
                r = subprocess.run(
                    ["powershell", "-Command", query],
                    capture_output=True, text=True, timeout=8
                )
                return r.stdout.strip()

            mb   = wmi_val("(Get-WmiObject win32_baseboard).Manufacturer + ' ' + (Get-WmiObject win32_baseboard).Product + ' ' + (Get-WmiObject win32_baseboard).SerialNumber")
            ram  = wmi_val("(Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1 | ForEach-Object { $_.Manufacturer + ' ' + $_.PartNumber + ' ' + $_.SerialNumber })")
            disk = wmi_val("(Get-PhysicalDisk | Select-Object -First 1 | ForEach-Object { $_.FriendlyName + ' ' + $_.MediaType + ' ' + $_.SerialNumber })")
            cpu  = wmi_val("(Get-WmiObject Win32_Processor).Name")

            raw  = f"{mb} | {ram} | {disk} | {cpu}"
            hwid = base64.b64encode(raw.encode("utf-8")).decode("utf-8").replace("=", "")
            return hwid
        except Exception as e:
            return f"Error: {e}"

    def _write_report(self):
        out  = self._outdir.get()
        ts   = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        txt  = os.path.join(out, f"mc_scan_{ts}.txt")
        jf   = os.path.join(out, f"mc_scan_{ts}.json")

        crits = [f for f in self._findings if f["severity"] == "critical"]
        warns = [f for f in self._findings if f["severity"] == "warning"]
        infos = [f for f in self._findings if f["severity"] == "info"]

        lines = [
            "=" * 70,
            "  MC CHEAT SCANNER — REPORT",
            f"  {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"  {os.environ.get('COMPUTERNAME', 'Unknown')} / {os.environ.get('USERNAME', 'Unknown')}",
            f"  Scanned folder: {self._mc_folder}",
            "=" * 70,
            "",
            f"  Total: {len(self._findings)}  |  Critical: {len(crits)}  |  Warning: {len(warns)}  |  Info: {len(infos)}",
            "",
        ]

        for label, items, icon in [("CRITICAL", crits, "🔴"), ("WARNING", warns, "🟠"), ("INFO", infos, "🔵")]:
            if items:
                lines += ["", f"  {icon}  {label}", "  " + "─" * 50]
                for f in items:
                    lines += [f"  [{f['time']}]  {f['category']} — {f['detail']}",
                               f"  {f['extra']}" if f["extra"] else "", ""]

        lines += ["=" * 70]

        with open(txt, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))
        with open(jf, "w", encoding="utf-8") as fh:
            json.dump({
                "time":          datetime.datetime.now().isoformat(),
                "host":          os.environ.get("COMPUTERNAME", "Unknown"),
                "user":          os.environ.get("USERNAME", "Unknown"),
                "scanned_folder": self._mc_folder,
                "summary":       {"total": len(self._findings), "critical": len(crits),
                                   "warning": len(warns), "info": len(infos)},
                "findings":      self._findings,
            }, fh, indent=2)

        self._write(f"\n  ✔  {txt}", "ok")
        self._write(f"  ✔  {jf}", "ok")

    def _run_si_scan(self):
        if sys.platform != "win32":
            self._write("  Skipped (Windows-only)", "dim")
            return
        if not HAS_WIN32 or not HAS_PYAUTOGUI:
            missing = []
            if not HAS_WIN32:      missing.append("pywin32")
            if not HAS_PYAUTOGUI:  missing.append("pyautogui")
            self._write(f"  ⚠  Missing: {', '.join(missing)} — run: pip install {' '.join(missing)}", "warning")
            self._write("  System Informer step skipped", "dim")
            return

        si = SIAutomator(self._write, self._finding, self._stop)

        exe = si.find_exe()
        if not exe:
            self._write("  ⚠  System Informer / Process Hacker not found", "warning")
            self._write("  Download from: https://systeminformer.sourceforge.io", "dim")
            return

        self._write(f"  ✔  Found: {exe}", "ok")

        if not si.ensure_running(exe):
            self._write("  ⚠  Could not launch System Informer", "warning")
            return

        hwnd = si.wait_for_window(timeout=10)
        if not hwnd:
            self._write("  ⚠  System Informer window did not appear", "warning")
            return

        self._write(f"  ✔  System Informer window ready (hwnd={hwnd})", "ok")
        time.sleep(1.2)

        javaw_pid = si.find_javaw_pid()
        if not javaw_pid:
            self._write("  ⚠  No javaw.exe found — Minecraft may not be running", "warning")
            return

        self._write(f"  ✔  javaw.exe PID {javaw_pid}", "ok")

        if not si.focus_process_in_si(hwnd, javaw_pid):
            self._write("  ⚠  Could not select javaw in System Informer", "warning")
            return

        self._write("  Opening process properties…", "info")
        if not si.open_process_properties(hwnd):
            self._write("  ⚠  Could not open process properties", "warning")
            return

        time.sleep(1.0)

        prop_hwnd = si.wait_for_properties_window(timeout=6)
        if not prop_hwnd:
            self._write("  ⚠  Properties window did not open", "warning")
            return

        self._write(f"  ✔  Properties window open (hwnd={prop_hwnd})", "ok")

        if not si.click_memory_tab(prop_hwnd):
            self._write("  ⚠  Could not click Memory tab", "warning")
            return

        self._write("  ✔  Memory tab selected", "ok")
        time.sleep(0.5)

        self._write(f"  Running {len(CRYSTAL_KEYWORDS)} crystal PVP keyword searches…", "info")
        hits = si.run_memory_searches(prop_hwnd, CRYSTAL_KEYWORDS)

        for keyword, count in hits.items():
            if count > 0:
                self._write(f"  🔴  '{keyword}' — {count} memory region(s)", "critical")
                self._finding("critical", "SI Memory Hit",
                               f"Crystal keyword '{keyword}' found in javaw memory",
                               f"{count} region(s) matched")
            else:
                self._write(f"  ✔  '{keyword}' — clean", "ok")

        si.close_properties(prop_hwnd)
        self._write(f"\n  System Informer scan complete — {sum(v > 0 for v in hits.values())} keyword(s) hit", "info")

class SIAutomator:
    """Drives System Informer / Process Hacker via win32 + pyautogui."""

    def __init__(self, log_fn, finding_fn, stop_event):
        self._log     = log_fn
        self._finding = finding_fn
        self._stop    = stop_event

    def find_exe(self):
        for path in SI_PATHS:
            if os.path.isfile(path):
                return path
        for name in ("SystemInformer.exe", "ProcessHacker.exe"):
            for d in os.environ.get("PATH", "").split(os.pathsep):
                p = os.path.join(d, name)
                if os.path.isfile(p):
                    return p
        return None

    def ensure_running(self, exe):
        for cls in SI_WINDOW_CLASSES:
            if win32gui.FindWindow(cls, None):
                self._log("  ✔  System Informer already running", "ok")
                return True
        try:
            import subprocess
            subprocess.Popen([exe])
            return True
        except Exception as e:
            self._log(f"  ⚠  Launch failed: {e}", "warning")
            return False

    def wait_for_window(self, timeout=12):
        deadline = time.time() + timeout
        while time.time() < deadline:
            for cls in SI_WINDOW_CLASSES:
                hwnd = win32gui.FindWindow(cls, None)
                if hwnd:
                    return hwnd
            time.sleep(0.4)
        return None

    def find_javaw_pid(self):
        if not HAS_PSUTIL:
            return None
        for proc in psutil.process_iter(['pid', 'name']):
            try:
                if "javaw" in (proc.info['name'] or "").lower():
                    return proc.pid
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return None

    def focus_process_in_si(self, hwnd, target_pid):
        try:
            win32gui.SetForegroundWindow(hwnd)
            time.sleep(0.4)
            list_hwnd = self._find_child_by_class(hwnd, "SysListView32")
            if not list_hwnd:
                win32api.keybd_event(0x11, 0, 0, 0)
                win32api.keybd_event(0x46, 0, 0, 0)
                win32api.keybd_event(0x46, 0, win32con.KEYEVENTF_KEYUP, 0)
                win32api.keybd_event(0x11, 0, win32con.KEYEVENTF_KEYUP, 0)
                time.sleep(0.5)
                pyautogui.typewrite(str(target_pid), interval=0.05)
                pyautogui.press("enter")
                time.sleep(0.5)
                return True

            row = self._lv_find_text(list_hwnd, str(target_pid))
            if row == -1:
                return False

            LVM_SETITEMSTATE = 0x102B
            LVIS_SELECTED    = 0x0002
            LVIS_FOCUSED     = 0x0001

            class LVITEM(ctypes.Structure):
                _fields_ = [
                    ("mask",      ctypes.c_uint),
                    ("iItem",     ctypes.c_int),
                    ("iSubItem",  ctypes.c_int),
                    ("state",     ctypes.c_uint),
                    ("stateMask", ctypes.c_uint),
                    ("pszText",   ctypes.c_void_p),
                    ("cchTextMax",ctypes.c_int),
                    ("iImage",    ctypes.c_int),
                    ("lParam",    ctypes.c_long),
                ]

            lvi        = LVITEM()
            lvi.mask   = 0x0008
            lvi.state  = LVIS_SELECTED | LVIS_FOCUSED
            lvi.stateMask = LVIS_SELECTED | LVIS_FOCUSED

            ctypes.windll.user32.SendMessageW(
                list_hwnd, LVM_SETITEMSTATE, row, ctypes.byref(lvi))

            LVM_ENSUREVISIBLE = 0x1013
            ctypes.windll.user32.SendMessageW(list_hwnd, LVM_ENSUREVISIBLE, row, False)
            time.sleep(0.3)
            return True

        except Exception as e:
            self._log(f"  ⚠  focus_process_in_si error: {e}", "warning")
            return False

    def open_process_properties(self, hwnd):
        try:
            win32gui.SetForegroundWindow(hwnd)
            time.sleep(0.2)
            win32api.keybd_event(0x0D, 0, 0, 0)
            win32api.keybd_event(0x0D, 0, win32con.KEYEVENTF_KEYUP, 0)
            return True
        except Exception as e:
            self._log(f"  ⚠  open_process_properties error: {e}", "warning")
            return False

    def wait_for_properties_window(self, timeout=8):
        deadline = time.time() + timeout
        while time.time() < deadline:
            result = [None]
            def check(hwnd, _):
                title = win32gui.GetWindowText(hwnd)
                if "Properties" in title and win32gui.IsWindowVisible(hwnd):
                    result[0] = hwnd
            win32gui.EnumWindows(check, None)
            if result[0]:
                return result[0]
            time.sleep(0.3)
        return None

    def click_memory_tab(self, prop_hwnd):
        try:
            win32gui.SetForegroundWindow(prop_hwnd)
            time.sleep(0.3)

            tab_hwnd = self._find_child_by_class(prop_hwnd, "SysTabControl32")
            if not tab_hwnd:
                tab_hwnd = self._find_child_by_class(prop_hwnd, "TabControl")

            if tab_hwnd:
                TCM_GETITEMCOUNT = 0x1304
                TCM_GETITEMW     = 0x133C
                TCM_SETCURSEL    = 0x130C

                count = ctypes.windll.user32.SendMessageW(tab_hwnd, TCM_GETITEMCOUNT, 0, 0)

                mem_idx = -1
                for i in range(count):
                    buf = ctypes.create_unicode_buffer(64)

                    class TCITEM(ctypes.Structure):
                        _fields_ = [
                            ("mask",        ctypes.c_uint),
                            ("dwState",     ctypes.c_uint),
                            ("dwStateMask", ctypes.c_uint),
                            ("pszText",     ctypes.c_wchar_p),
                            ("cchTextMax",  ctypes.c_int),
                            ("iImage",      ctypes.c_int),
                            ("lParam",      ctypes.c_long),
                        ]

                    item = TCITEM()
                    item.mask      = 0x0001
                    item.pszText   = buf
                    item.cchTextMax= 64

                    ctypes.windll.user32.SendMessageW(
                        tab_hwnd, TCM_GETITEMW, i, ctypes.byref(item))

                    tab_text = buf.value.strip().lower()
                    if "memory" in tab_text:
                        mem_idx = i
                        break

                if mem_idx >= 0:
                    ctypes.windll.user32.SendMessageW(tab_hwnd, TCM_SETCURSEL, mem_idx, 0)
                    win32api.PostMessage(prop_hwnd, win32con.WM_COMMAND, mem_idx, 0)
                    time.sleep(0.4)
                    return True

            rect = win32gui.GetWindowRect(prop_hwnd)
            tab_y = rect[1] + 45
            tab_x_start = rect[0] + 10
            tab_width    = 70
            for i in range(12):
                pyautogui.click(tab_x_start + i * tab_width, tab_y)
                time.sleep(0.2)
                if i == 3:
                    return True

            return False
        except Exception as e:
            self._log(f"  ⚠  click_memory_tab error: {e}", "warning")
            return False

    def run_memory_searches(self, prop_hwnd, keywords):
        results = {}
        win32gui.SetForegroundWindow(prop_hwnd)
        time.sleep(0.3)

        for kw in keywords:
            if self._stop.is_set():
                break
            count = self._single_memory_search(prop_hwnd, kw)
            results[kw] = count
            time.sleep(0.2)

        return results

    def _single_memory_search(self, prop_hwnd, keyword):
        try:
            win32gui.SetForegroundWindow(prop_hwnd)
            time.sleep(0.15)

            win32api.keybd_event(0x11, 0, 0, 0)
            win32api.keybd_event(0x46, 0, 0, 0)
            win32api.keybd_event(0x46, 0, win32con.KEYEVENTF_KEYUP, 0)
            win32api.keybd_event(0x11, 0, win32con.KEYEVENTF_KEYUP, 0)
            time.sleep(0.5)

            search_hwnd = self._wait_for_child_dialog(prop_hwnd, timeout=3)
            if not search_hwnd:
                rect = win32gui.GetWindowRect(prop_hwnd)
                pyautogui.click(rect[0] + 60, rect[1] + 85)
                time.sleep(0.5)
                search_hwnd = self._wait_for_child_dialog(prop_hwnd, timeout=3)

            if not search_hwnd:
                return 0

            edit = self._find_child_by_class(search_hwnd, "Edit")
            if edit:
                win32gui.SetFocus(edit)
                time.sleep(0.1)
                win32api.keybd_event(0x11, 0, 0, 0)
                win32api.keybd_event(0x41, 0, 0, 0)
                win32api.keybd_event(0x41, 0, win32con.KEYEVENTF_KEYUP, 0)
                win32api.keybd_event(0x11, 0, win32con.KEYEVENTF_KEYUP, 0)
                pyautogui.typewrite(keyword, interval=0.03)

            combos = self._find_all_children_by_class(search_hwnd, "ComboBox")
            if len(combos) >= 1:
                ctypes.windll.user32.SendMessageW(combos[0], 0x014E, 4, 0)
                time.sleep(0.1)
            if len(combos) >= 2:
                cb = combos[1]
                n  = ctypes.windll.user32.SendMessageW(cb, 0x0146, 0, 0)
                for i in range(n):
                    buf = ctypes.create_unicode_buffer(64)
                    ctypes.windll.user32.SendMessageW(cb, 0x0148, i, buf)
                    if "contain" in buf.value.lower():
                        ctypes.windll.user32.SendMessageW(cb, 0x014E, i, 0)
                        break

            self._click_default_button(search_hwnd)
            time.sleep(1.5)

            result_lv = self._find_child_by_class(search_hwnd, "SysListView32")
            if result_lv:
                LVM_GETITEMCOUNT = 0x1004
                count = ctypes.windll.user32.SendMessageW(result_lv, LVM_GETITEMCOUNT, 0, 0)
                win32api.PostMessage(search_hwnd, win32con.WM_CLOSE, 0, 0)
                time.sleep(0.3)
                return count

            win32api.PostMessage(search_hwnd, win32con.WM_CLOSE, 0, 0)
            return 0

        except Exception as e:
            self._log(f"  ⚠  memory search error ({keyword}): {e}", "warning")
            return 0

    def close_properties(self, prop_hwnd):
        try:
            win32api.PostMessage(prop_hwnd, win32con.WM_CLOSE, 0, 0)
        except Exception:
            pass

    def _find_child_by_class(self, parent, cls):
        result = [None]
        def cb(hwnd, _):
            if win32gui.GetClassName(hwnd) == cls:
                result[0] = hwnd
                return False
            return True
        try:
            win32gui.EnumChildWindows(parent, cb, None)
        except Exception:
            pass
        return result[0]

    def _find_all_children_by_class(self, parent, cls):
        results = []
        def cb(hwnd, _):
            if win32gui.GetClassName(hwnd) == cls:
                results.append(hwnd)
            return True
        try:
            win32gui.EnumChildWindows(parent, cb, None)
        except Exception:
            pass
        return results

    def _lv_find_text(self, lv_hwnd, text):
        LVM_GETITEMCOUNT = 0x1004
        LVM_GETITEMTEXTW = 0x1073
        count = ctypes.windll.user32.SendMessageW(lv_hwnd, LVM_GETITEMCOUNT, 0, 0)
        for i in range(min(count, 2000)):
            buf = ctypes.create_unicode_buffer(256)

            class LVITEM(ctypes.Structure):
                _fields_ = [
                    ("mask",       ctypes.c_uint),
                    ("iItem",      ctypes.c_int),
                    ("iSubItem",   ctypes.c_int),
                    ("state",      ctypes.c_uint),
                    ("stateMask",  ctypes.c_uint),
                    ("pszText",    ctypes.c_wchar_p),
                    ("cchTextMax", ctypes.c_int),
                    ("iImage",     ctypes.c_int),
                    ("lParam",     ctypes.c_long),
                ]

            lvi = LVITEM()
            lvi.iItem      = i
            lvi.iSubItem   = 0
            lvi.pszText    = buf
            lvi.cchTextMax = 256

            ctypes.windll.user32.SendMessageW(lv_hwnd, LVM_GETITEMTEXTW, i, ctypes.byref(lvi))
            if text in buf.value:
                return i
        return -1

    def _wait_for_child_dialog(self, parent, timeout=4):
        deadline = time.time() + timeout
        while time.time() < deadline:
            result = [None]
            def cb(hwnd, _):
                cls   = win32gui.GetClassName(hwnd)
                title = win32gui.GetWindowText(hwnd).lower()
                if (cls in ("#32770", "Dialog") or "find" in title or "search" in title or "memory" in title) \
                        and win32gui.IsWindowVisible(hwnd):
                    result[0] = hwnd
                    return False
                return True
            win32gui.EnumWindows(cb, None)
            if result[0]:
                return result[0]
            time.sleep(0.25)
        return None

    def _click_default_button(self, hwnd):
        buttons = self._find_all_children_by_class(hwnd, "Button")
        for b in buttons:
            text = win32gui.GetWindowText(b).lower()
            if any(k in text for k in ["ok", "find", "search", "scan"]):
                rect = win32gui.GetWindowRect(b)
                cx   = (rect[0] + rect[2]) // 2
                cy   = (rect[1] + rect[3]) // 2
                pyautogui.click(cx, cy)
                return
        win32api.keybd_event(0x0D, 0, 0, 0)
        win32api.keybd_event(0x0D, 0, win32con.KEYEVENTF_KEYUP, 0)

if __name__ == "__main__":
    if sys.platform == "win32":
        try:
            if not ctypes.windll.shell32.IsUserAnAdmin():
                ctypes.windll.shell32.ShellExecuteW(
                    None, "runas", sys.executable, " ".join(sys.argv), None, 1)
                sys.exit(0)
        except Exception:
            pass

    prompt = FolderPrompt()
    prompt.mainloop()

    if prompt.result:
        Scanner(prompt.result).mainloop()
