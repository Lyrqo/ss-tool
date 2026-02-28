if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -Command `"Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/Lyrqo/ss-tool/main/ss%20tool.ps1')`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$BG      = [System.Drawing.ColorTranslator]::FromHtml("#0a0c12")
$BG2     = [System.Drawing.ColorTranslator]::FromHtml("#0f1219")
$BG3     = [System.Drawing.ColorTranslator]::FromHtml("#141820")
$ACCENT  = [System.Drawing.ColorTranslator]::FromHtml("#00d4ff")
$RED     = [System.Drawing.ColorTranslator]::FromHtml("#ff3d5a")
$GREEN   = [System.Drawing.ColorTranslator]::FromHtml("#00e87a")
$ORANGE  = [System.Drawing.ColorTranslator]::FromHtml("#ffaa00")
$TEXT    = [System.Drawing.ColorTranslator]::FromHtml("#d0d8e8")
$DIM     = [System.Drawing.ColorTranslator]::FromHtml("#4a5568")
$BORDER  = [System.Drawing.ColorTranslator]::FromHtml("#1e2535")

$FONT_UI   = New-Object System.Drawing.Font("Segoe UI", 10)
$FONT_BOLD = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$FONT_MONO = New-Object System.Drawing.Font("Consolas", 9)
$FONT_HEAD = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$FONT_TINY = New-Object System.Drawing.Font("Consolas", 8)

$CHEAT_NAMES = @(
    "wurst","impact","future","liquidbounce","aristois","meteor",
    "killaura","sigma","entropy","novoline","rusherhack","vape",
    "astolfo","inertia","ghost","rise","tenacity","aura","esp",
    "aimbot","bhop","scaffold","velocity","criticals","nofall",
    "autoeat","autofish","tracers","xray","freecam","fly","speed",
    "jesus","mixin","bytebuddy","javassist","agentmain","premain"
)

$SCAN_EXTS = @(".jar",".zip",".class",".json",".cfg",".properties")

$global:StopScan   = $false
$global:McFolder   = ""
$global:OutFolder  = ""
$global:Findings   = @()

function New-Label {
    param($Text, $X, $Y, $W, $H, $FG, $BG_C, $Font = $FONT_UI, $Align = "MiddleLeft")
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $Text
    $l.Location  = New-Object System.Drawing.Point($X, $Y)
    $l.Size      = New-Object System.Drawing.Size($W, $H)
    $l.ForeColor = $FG
    $l.BackColor = $BG_C
    $l.Font      = $Font
    $l.TextAlign = [System.Drawing.ContentAlignment]::$Align
    return $l
}

function New-Button {
    param($Text, $X, $Y, $W, $H, $BG_C, $FG)
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $Text
    $b.Location  = New-Object System.Drawing.Point($X, $Y)
    $b.Size      = New-Object System.Drawing.Size($W, $H)
    $b.BackColor = $BG_C
    $b.ForeColor = $FG
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.Font      = $FONT_BOLD
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    return $b
}

function New-TextBox {
    param($X, $Y, $W, $H, $Multi = $false)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location    = New-Object System.Drawing.Point($X, $Y)
    $t.Size        = New-Object System.Drawing.Size($W, $H)
    $t.BackColor   = $BG3
    $t.ForeColor   = $TEXT
    $t.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $t.Font        = $FONT_MONO
    if ($Multi) {
        $t.Multiline  = $true
        $t.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
        $t.ReadOnly   = $true
        $t.WordWrap   = $true
    }
    return $t
}

function Write-Log {
    param($LogBox, $Text, $Color = $null)
    if ($LogBox.InvokeRequired) {
        $LogBox.Invoke([Action[System.Windows.Forms.TextBox, string, object]]{ param($lb,$t,$c) Write-Log $lb $t $c }, $LogBox, $Text, $Color)
        return
    }
    $LogBox.AppendText("$Text`r`n")
    $LogBox.ScrollToCaret()
}

function Add-Finding {
    param($ListBox, $Severity, $Category, $Detail)
    $icon = switch ($Severity) { "critical" {"[CRIT]"} "warning" {"[WARN]"} default {"[INFO]"} }
    $line = "$icon $Category`: $Detail"
    if ($ListBox.InvokeRequired) {
        $ListBox.Invoke([Action]{ $ListBox.Items.Add($line) | Out-Null }) 
    } else {
        $ListBox.Items.Add($line) | Out-Null
    }
    $global:Findings += [PSCustomObject]@{ Severity=$Severity; Category=$Category; Detail=$Detail }
}

# ── MAIN FORM ──────────────────────────────────────────────────────────────────
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "SS Tool  //  MC Cheat Scanner"
$Form.Size            = New-Object System.Drawing.Size(1100, 720)
$Form.MinimumSize     = New-Object System.Drawing.Size(960, 600)
$Form.BackColor       = $BG
$Form.ForeColor       = $TEXT
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "Sizable"

# Header
$Header = New-Object System.Windows.Forms.Panel
$Header.Dock      = "Top"
$Header.Height    = 52
$Header.BackColor = $BG2
$Form.Controls.Add($Header)

$Header.Controls.Add((New-Label "⚡  SS TOOL  //  MC CHEAT SCANNER" 16 12 500 28 $ACCENT $BG2 $FONT_HEAD))
$AdminTxt = if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) { "✔ ADMIN" } else { "⚠ NOT ADMIN" }
$AdminCol = if ($AdminTxt -eq "✔ ADMIN") { $GREEN } else { $RED }
$Header.Controls.Add((New-Label $AdminTxt 950 16 120 22 $AdminCol $BG2 $FONT_TINY "MiddleRight"))

$HeaderLine = New-Object System.Windows.Forms.Panel
$HeaderLine.Dock      = "Top"
$HeaderLine.Height    = 1
$HeaderLine.BackColor = $BORDER
$Form.Controls.Add($HeaderLine)

# Tab Control
$Tabs = New-Object System.Windows.Forms.TabControl
$Tabs.Dock          = "Fill"
$Tabs.Font          = $FONT_UI
$Tabs.BackColor     = $BG
$Tabs.Appearance    = [System.Windows.Forms.TabAppearance]::Normal
$Form.Controls.Add($Tabs)

# Status bar
$StatusBar = New-Object System.Windows.Forms.Panel
$StatusBar.Dock      = "Bottom"
$StatusBar.Height    = 24
$StatusBar.BackColor = $BG2
$Form.Controls.Add($StatusBar)

$StatusLabel = New-Label "Ready — set paths in Setup then run a scan" 10 4 900 18 $DIM $BG2 $FONT_TINY
$StatusBar.Controls.Add($StatusLabel)

function Set-Status { param($msg) 
    if ($StatusLabel.InvokeRequired) { $StatusLabel.Invoke([Action]{ $StatusLabel.Text = $msg }) }
    else { $StatusLabel.Text = $msg }
}

# ── TAB: SETUP ─────────────────────────────────────────────────────────────────
$TabSetup = New-Object System.Windows.Forms.TabPage
$TabSetup.Text      = "  ⚙  Setup  "
$TabSetup.BackColor = $BG
$Tabs.TabPages.Add($TabSetup)

$TabSetup.Controls.Add((New-Label "SETUP" 20 16 200 28 $ACCENT $BG $FONT_HEAD))
$TabSetup.Controls.Add((New-Label "Set your folders before running any scan." 20 46 600 20 $DIM $BG $FONT_UI))

$TabSetup.Controls.Add((New-Label "① Minecraft Mods Folder" 20 82 300 20 $ACCENT $BG $FONT_BOLD))
$McEntry = New-TextBox 20 106 780 26
$TabSetup.Controls.Add($McEntry)
$BrowseMc = New-Button "Browse" 810 104 100 28 $BG3 $ACCENT
$BrowseMc.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select Minecraft mods folder"
    if ($d.ShowDialog() -eq "OK") { $McEntry.Text = $d.SelectedPath; $global:McFolder = $d.SelectedPath }
})
$TabSetup.Controls.Add($BrowseMc)

$TabSetup.Controls.Add((New-Label "② Output / Report Folder" 20 148 300 20 $ACCENT $BG $FONT_BOLD))
$OutEntry = New-TextBox 20 172 780 26
$TabSetup.Controls.Add($OutEntry)
$BrowseOut = New-Button "Browse" 810 170 100 28 $BG3 $ACCENT
$BrowseOut.Add_Click({
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = "Select output folder"
    if ($d.ShowDialog() -eq "OK") { $OutEntry.Text = $d.SelectedPath; $global:OutFolder = $d.SelectedPath }
})
$TabSetup.Controls.Add($BrowseOut)

$TabSetup.Controls.Add((New-Label "③ Quick Launch" 20 216 300 20 $ACCENT $BG $FONT_BOLD))
$LaunchScan = New-Button "▶  File Scanner" 20 240 150 34 $GREEN $BG
$LaunchScan.Add_Click({ $Tabs.SelectedTab = $TabScan })
$TabSetup.Controls.Add($LaunchScan)

$LaunchMem = New-Button "▶  Memory Scan" 180 240 150 34 $ACCENT $BG
$LaunchMem.Add_Click({ $Tabs.SelectedTab = $TabMemory })
$TabSetup.Controls.Add($LaunchMem)

$LaunchSys = New-Button "▶  Sys Info" 340 240 150 34 $ORANGE $BG
$LaunchSys.Add_Click({ $Tabs.SelectedTab = $TabSysInfo })
$TabSetup.Controls.Add($LaunchSys)

$TabSetup.Controls.Add((New-Label "Requirements" 20 300 200 20 $ACCENT $BG $FONT_BOLD))
$ReqText = ""
$ReqText += if (Get-Command python -ErrorAction SilentlyContinue) { "✔ Python   " } else { "✘ Python   " }
$ReqText += if ($AdminTxt -eq "✔ ADMIN") { "✔ Admin   " } else { "✘ Admin   " }
$ReqText += if ([System.Environment]::OSVersion.Platform -eq "Win32NT") { "✔ Windows" } else { "✘ Windows" }
$TabSetup.Controls.Add((New-Label $ReqText 20 324 600 22 $TEXT $BG $FONT_MONO))

# ── TAB: FILE SCANNER ──────────────────────────────────────────────────────────
$TabScan = New-Object System.Windows.Forms.TabPage
$TabScan.Text      = "  🔍  Scanner  "
$TabScan.BackColor = $BG
$Tabs.TabPages.Add($TabScan)

$ScanTopPanel = New-Object System.Windows.Forms.Panel
$ScanTopPanel.Dock      = "Top"
$ScanTopPanel.Height    = 48
$ScanTopPanel.BackColor = $BG2
$TabScan.Controls.Add($ScanTopPanel)

$ScanTopPanel.Controls.Add((New-Label "FILE SCANNER" 16 12 300 26 $ACCENT $BG2 $FONT_BOLD))

$StopScanBtn = New-Button "■  STOP" 940 10 100 28 $RED ([System.Drawing.Color]::White)
$StopScanBtn.Enabled = $false
$StopScanBtn.Add_Click({ $global:StopScan = $true })
$ScanTopPanel.Controls.Add($StopScanBtn)

$StartScanBtn = New-Button "▶  START SCAN" 820 10 116 28 $GREEN $BG
$ScanTopPanel.Controls.Add($StartScanBtn)

$ScanProgress = New-Object System.Windows.Forms.ProgressBar
$ScanProgress.Dock  = "Top"
$ScanProgress.Height = 4
$ScanProgress.Style  = "Continuous"
$ScanProgress.BackColor = $BG2
$ScanProgress.ForeColor = $ACCENT
$TabScan.Controls.Add($ScanProgress)

$ScanBody = New-Object System.Windows.Forms.SplitContainer
$ScanBody.Dock            = "Fill"
$ScanBody.SplitterDistance = 300
$ScanBody.BackColor       = $BORDER
$ScanBody.Panel1.BackColor = $BG2
$ScanBody.Panel2.BackColor = $BG
$TabScan.Controls.Add($ScanBody)

$ScanBody.Panel1.Controls.Add((New-Label "FINDINGS" 10 8 200 18 $DIM $BG2 $FONT_TINY))

$CountPanel = New-Object System.Windows.Forms.Panel
$CountPanel.Location  = New-Object System.Drawing.Point(6, 28)
$CountPanel.Size      = New-Object System.Drawing.Size(282, 48)
$CountPanel.BackColor = $BG2
$ScanBody.Panel1.Controls.Add($CountPanel)

$CritLabel = New-Label "0  CRIT" 0 0 94 48 $RED $BG3 $FONT_BOLD "MiddleCenter"
$WarnLabel = New-Label "0  WARN" 95 0 94 48 $ORANGE $BG3 $FONT_BOLD "MiddleCenter"
$InfoLabel = New-Label "0  INFO" 190 0 94 48 $ACCENT $BG3 $FONT_BOLD "MiddleCenter"
$CountPanel.Controls.Add($CritLabel)
$CountPanel.Controls.Add($WarnLabel)
$CountPanel.Controls.Add($InfoLabel)

$FindingsList = New-Object System.Windows.Forms.ListBox
$FindingsList.Location  = New-Object System.Drawing.Point(6, 82)
$FindingsList.Size      = New-Object System.Drawing.Size(282, 460)
$FindingsList.BackColor = $BG2
$FindingsList.ForeColor = $TEXT
$FindingsList.BorderStyle = "None"
$FindingsList.Font      = $FONT_MONO
$ScanBody.Panel1.Controls.Add($FindingsList)

$ScanBody.Panel2.Controls.Add((New-Label "SCAN LOG" 10 8 200 18 $DIM $BG $FONT_TINY))
$ScanLog = New-TextBox 6 28 0 0 $true
$ScanLog.Dock      = "Fill"
$ScanLog.BackColor = $BG
$ScanLog.ForeColor = $TEXT
$ScanBody.Panel2.Controls.Add($ScanLog)

$StartScanBtn.Add_Click({
    $global:McFolder  = $McEntry.Text.Trim()
    $global:OutFolder = $OutEntry.Text.Trim()
    if (-not $global:McFolder -or -not (Test-Path $global:McFolder)) {
        Write-Log $ScanLog "[ERROR] Set a valid Minecraft folder in Setup first."
        return
    }
    if (-not $global:OutFolder -or -not (Test-Path $global:OutFolder)) {
        Write-Log $ScanLog "[ERROR] Set a valid output folder in Setup first."
        return
    }
    $global:StopScan = $false
    $global:Findings = @()
    $FindingsList.Items.Clear()
    $ScanLog.Clear()
    $ScanProgress.Value = 0
    $CritLabel.Text = "0  CRIT"
    $WarnLabel.Text = "0  WARN"
    $InfoLabel.Text = "0  INFO"
    $StartScanBtn.Enabled = $false
    $StopScanBtn.Enabled  = $true
    Set-Status "File scan running..."

    $job = [System.Threading.Thread]::new({
        $mc  = $global:McFolder
        $out = $global:OutFolder
        $ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Log $ScanLog "Started  $ts"
        Write-Log $ScanLog "Folder   $mc"
        Write-Log $ScanLog ""

        # Step 1 - Directory scan
        Write-Log $ScanLog "── Directory Scan ──────────────────────────"
        $ScanProgress.Invoke([Action]{ $ScanProgress.Value = 20 })
        $skipDirs = @("versions","assets","libraries","natives","cache")
        Get-ChildItem -Path $mc -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $rel = $_.FullName.Replace($mc,"").TrimStart("\")
            $topDir = $rel.Split("\")[0].ToLower()
            $skipDirs -notcontains $topDir
        } | ForEach-Object {
            if ($global:StopScan) { return }
            $name = $_.Name.ToLower()
            $ext  = $_.Extension.ToLower()
            if ($SCAN_EXTS -notcontains $ext) { return }
            foreach ($ch in $CHEAT_NAMES) {
                if ($name -match $ch) {
                    Write-Log $ScanLog "[CRIT] Cheat file: $($_.Name)"
                    Add-Finding $FindingsList "critical" "Cheat File" "Matches '$ch' — $($_.FullName)"
                    $c = [int]($CritLabel.Text.Split(" ")[0]) + 1
                    $CritLabel.Invoke([Action]{ $CritLabel.Text = "$c  CRIT" })
                }
            }
            if ($ext -in @(".json",".cfg",".properties")) {
                try {
                    $content = Get-Content $_.FullName -Raw -ErrorAction Stop | Select-String -Pattern ($CHEAT_NAMES -join "|") -Quiet
                    if ($content) {
                        Write-Log $ScanLog "[WARN] Cheat string in config: $($_.Name)"
                        Add-Finding $FindingsList "warning" "Config Match" "$($_.FullName)"
                        $w = [int]($WarnLabel.Text.Split(" ")[0]) + 1
                        $WarnLabel.Invoke([Action]{ $WarnLabel.Text = "$w  WARN" })
                    }
                } catch {}
            }
        }
        Write-Log $ScanLog "✔ Directory scan done"

        # Step 2 - Startup check
        $ScanProgress.Invoke([Action]{ $ScanProgress.Value = 60 })
        Write-Log $ScanLog ""
        Write-Log $ScanLog "── Startup Check ───────────────────────────"
        $startupPaths = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        )
        foreach ($sp in $startupPaths) {
            if (Test-Path $sp) {
                Get-ChildItem $sp | ForEach-Object {
                    foreach ($ch in $CHEAT_NAMES) {
                        if ($_.Name.ToLower() -match $ch) {
                            Write-Log $ScanLog "[CRIT] Cheat in startup: $($_.Name)"
                            Add-Finding $FindingsList "critical" "Startup" "$($_.FullName)"
                        }
                    }
                }
            }
        }
        $regPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
        )
        foreach ($rp in $regPaths) {
            if (Test-Path $rp) {
                Get-ItemProperty $rp | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $val = (Get-ItemProperty $rp).$($_.Name)
                    foreach ($ch in $CHEAT_NAMES) {
                        if ($_.Name.ToLower() -match $ch -or "$val".ToLower() -match $ch) {
                            Write-Log $ScanLog "[CRIT] Registry Run: $($_.Name)"
                            Add-Finding $FindingsList "critical" "Registry Run" "$($_.Name) = $val"
                        }
                    }
                }
            }
        }
        Write-Log $ScanLog "✔ Startup check done"

        # Step 3 - Write report
        $ScanProgress.Invoke([Action]{ $ScanProgress.Value = 90 })
        Write-Log $ScanLog ""
        Write-Log $ScanLog "── Writing Report ──────────────────────────"
        $stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
        $txtPath = "$out\scan_$stamp.txt"
        $jsonPath= "$out\scan_$stamp.json"
        $lines   = @(
            "="*60,
            "  SS TOOL // MC CHEAT SCANNER REPORT",
            "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "  $env:COMPUTERNAME / $env:USERNAME",
            "  Scanned: $mc",
            "="*60, "",
            "  Total: $($global:Findings.Count)  Critical: $(($global:Findings | Where-Object Severity -eq 'critical').Count)  Warning: $(($global:Findings | Where-Object Severity -eq 'warning').Count)",
            ""
        )
        foreach ($f in $global:Findings) {
            $lines += "  [$($f.Severity.ToUpper())]  $($f.Category) — $($f.Detail)"
        }
        $lines | Out-File $txtPath -Encoding UTF8
        $global:Findings | ConvertTo-Json | Out-File $jsonPath -Encoding UTF8
        Write-Log $ScanLog "✔ Report: $txtPath"
        Write-Log $ScanLog "✔ JSON:   $jsonPath"

        $ScanProgress.Invoke([Action]{ $ScanProgress.Value = 100 })
        $crits = ($global:Findings | Where-Object Severity -eq "critical").Count
        Set-Status "Done — $($global:Findings.Count) findings, $crits critical"
        Write-Log $ScanLog ""
        Write-Log $ScanLog "✔ Scan complete"
        $StartScanBtn.Invoke([Action]{ $StartScanBtn.Enabled = $true })
        $StopScanBtn.Invoke([Action]{ $StopScanBtn.Enabled = $false })
    })
    $job.IsBackground = $true
    $job.Start()
})

# ── TAB: MEMORY SCANNER ────────────────────────────────────────────────────────
$TabMemory = New-Object System.Windows.Forms.TabPage
$TabMemory.Text      = "  🧠  Memory  "
$TabMemory.BackColor = $BG
$Tabs.TabPages.Add($TabMemory)

$MemTopPanel = New-Object System.Windows.Forms.Panel
$MemTopPanel.Dock      = "Top"
$MemTopPanel.Height    = 48
$MemTopPanel.BackColor = $BG2
$TabMemory.Controls.Add($MemTopPanel)

$MemTopPanel.Controls.Add((New-Label "MEMORY SCANNER" 16 12 400 26 $ACCENT $BG2 $FONT_BOLD))
$MemTopPanel.Controls.Add((New-Label "Scans javaw.exe RAM for cheat signatures  (requires admin)" 220 16 500 18 $DIM $BG2 $FONT_TINY))

$global:StopMem = $false
$StopMemBtn = New-Button "■  STOP" 940 10 100 28 $RED ([System.Drawing.Color]::White)
$StopMemBtn.Enabled = $false
$StopMemBtn.Add_Click({ $global:StopMem = $true })
$MemTopPanel.Controls.Add($StopMemBtn)

$StartMemBtn = New-Button "▶  SCAN MEMORY" 800 10 136 28 $ACCENT $BG
$MemTopPanel.Controls.Add($StartMemBtn)

$MemLog = New-TextBox 8 56 0 0 $true
$MemLog.Dock      = "Fill"
$MemLog.BackColor = $BG
$MemLog.ForeColor = $TEXT
$TabMemory.Controls.Add($MemLog)

$StartMemBtn.Add_Click({
    $MemLog.Clear()
    $global:StopMem = $false
    $StartMemBtn.Enabled = $false
    $StopMemBtn.Enabled  = $true
    Set-Status "Memory scan running..."

    $job = [System.Threading.Thread]::new({
        Write-Log $MemLog "Memory scan started  $(Get-Date -Format 'HH:mm:ss')"
        Write-Log $MemLog ""

        $javaws = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
        if (-not $javaws) {
            Write-Log $MemLog "[WARN] No javaw.exe found — is Minecraft running?"
            $StartMemBtn.Invoke([Action]{ $StartMemBtn.Enabled = $true })
            $StopMemBtn.Invoke([Action]{ $StopMemBtn.Enabled = $false })
            Set-Status "Memory scan: no Minecraft found"
            return
        }

        $MEM_SIGS = @(
            "KillAura","killaura","AutoCrystal","autocrystal","Scaffold","scaffold",
            "Velocity","NoFall","Freecam","ESP","Xray","xray","BHop","Flight","flight",
            "CrystalAura","BaritoneAPI","baritone.api","agentmain","premain",
            "ClassFileTransformer","bytebuddy","javassist","aimbot","wallhack",
            "autoclick","triggerbot","sendPacket","injectPacket","noknockback"
        )

        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MemReader {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool b, int c);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr a, byte[] b, int s, out int r);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h, IntPtr a, out MEMORY_BASIC_INFORMATION m, uint s);
    [StructLayout(LayoutKind.Sequential)] public struct MEMORY_BASIC_INFORMATION {
        public IntPtr BaseAddress, AllocationBase;
        public uint AllocationProtect;
        public IntPtr RegionSize;
        public uint State, Protect, Type;
    }
}
"@ -ErrorAction SilentlyContinue

        $totalHits = 0
        foreach ($proc in $javaws) {
            Write-Log $MemLog "Scanning PID $($proc.Id)..."
            $handle = [MemReader]::OpenProcess(0x0410, $false, $proc.Id)
            if ($handle -eq [IntPtr]::Zero) {
                Write-Log $MemLog "[WARN] Cannot open PID $($proc.Id) — need admin"
                continue
            }
            $addr  = [IntPtr]::Zero
            $hits  = @{}
            $scanned = 0
            $maxScan = 512MB

            while ($scanned -lt $maxScan -and -not $global:StopMem) {
                $mbi = New-Object MemReader+MEMORY_BASIC_INFORMATION
                $ret = [MemReader]::VirtualQueryEx($handle, $addr, [ref]$mbi, [System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
                if ($ret -eq 0) { break }
                $size = $mbi.RegionSize.ToInt64()
                if ($size -le 0) { break }
                if ($mbi.State -eq 0x1000 -and ($mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x20 -or $mbi.Protect -eq 0x40)) {
                    $buf  = New-Object byte[] ([Math]::Min($size, 4MB))
                    $read = 0
                    if ([MemReader]::ReadProcessMemory($handle, $mbi.BaseAddress, $buf, $buf.Length, [ref]$read) -and $read -gt 0) {
                        $str = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
                        foreach ($sig in $MEM_SIGS) {
                            if (-not $hits[$sig] -and $str.Contains($sig)) {
                                $hits[$sig] = $true
                                Write-Log $MemLog "[CRIT] HIT: $sig"
                                $totalHits++
                            }
                        }
                    }
                    $scanned += $read
                }
                $next = $mbi.BaseAddress.ToInt64() + $size
                if ($next -ge 0x7FFFFFFFFFFF) { break }
                $addr = [IntPtr]::new($next)
            }
            [MemReader]::CloseHandle($handle) | Out-Null
            if ($hits.Count -eq 0) { Write-Log $MemLog "✔ PID $($proc.Id) — Clean" }
            else { Write-Log $MemLog "⚠ PID $($proc.Id) — $($hits.Count) signature(s) found" }
        }

        Write-Log $MemLog ""
        Write-Log $MemLog "── Done — $totalHits total hit(s) ──"
        Set-Status "Memory scan done — $totalHits hit(s)"
        $StartMemBtn.Invoke([Action]{ $StartMemBtn.Enabled = $true })
        $StopMemBtn.Invoke([Action]{ $StopMemBtn.Enabled = $false })
    })
    $job.IsBackground = $true
    $job.Start()
})

# ── TAB: SYS INFO ──────────────────────────────────────────────────────────────
$TabSysInfo = New-Object System.Windows.Forms.TabPage
$TabSysInfo.Text      = "  🖥  Sys Info  "
$TabSysInfo.BackColor = $BG
$Tabs.TabPages.Add($TabSysInfo)

$SysTopPanel = New-Object System.Windows.Forms.Panel
$SysTopPanel.Dock      = "Top"
$SysTopPanel.Height    = 48
$SysTopPanel.BackColor = $BG2
$TabSysInfo.Controls.Add($SysTopPanel)

$SysTopPanel.Controls.Add((New-Label "SYSTEM INFO" 16 12 300 26 $ACCENT $BG2 $FONT_BOLD))

$RunSysBtn = New-Button "▶  RUN CHECKS" 820 10 140 28 $ORANGE $BG
$SysTopPanel.Controls.Add($RunSysBtn)

$UptimePanel = New-Object System.Windows.Forms.Panel
$UptimePanel.Location  = New-Object System.Drawing.Point(8, 56)
$UptimePanel.Size      = New-Object System.Drawing.Size(400, 60)
$UptimePanel.BackColor = $BG3
$TabSysInfo.Controls.Add($UptimePanel)
$UptimePanel.Controls.Add((New-Label "⏱  MC UPTIME" 12 6 200 16 $DIM $BG3 $FONT_TINY))
$UptimeVal = New-Label "—" 12 24 380 28 $TEXT $BG3 $FONT_BOLD
$UptimePanel.Controls.Add($UptimeVal)

$HwidPanel = New-Object System.Windows.Forms.Panel
$HwidPanel.Location  = New-Object System.Drawing.Point(8, 124)
$HwidPanel.Size      = New-Object System.Drawing.Size(1050, 60)
$HwidPanel.BackColor = $BG3
$TabSysInfo.Controls.Add($HwidPanel)
$HwidPanel.Controls.Add((New-Label "🖥  HWID" 12 6 200 16 $DIM $BG3 $FONT_TINY))
$HwidVal = New-Label "—" 12 24 1020 28 $ACCENT $BG3 $FONT_MONO
$HwidPanel.Controls.Add($HwidVal)

$SysLog = New-TextBox 8 194 0 0 $true
$SysLog.Anchor    = "Top,Bottom,Left,Right"
$SysLog.Size      = New-Object System.Drawing.Size(1066, 420)
$SysLog.BackColor = $BG
$SysLog.ForeColor = $TEXT
$TabSysInfo.Controls.Add($SysLog)

$RunSysBtn.Add_Click({
    $SysLog.Clear()
    $UptimeVal.Text = "Checking..."
    $HwidVal.Text   = "Generating..."
    Set-Status "Running sys info checks..."

    $job = [System.Threading.Thread]::new({
        Write-Log $SysLog "Checks started  $(Get-Date -Format 'HH:mm:ss')"
        Write-Log $SysLog "Host: $env:COMPUTERNAME   User: $env:USERNAME"
        Write-Log $SysLog ""

        Write-Log $SysLog "── MC Uptime ───────────────────────────────"
        $javaw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($javaw) {
            $started = $javaw.StartTime
            $elapsed = (Get-Date) - $started
            $upStr   = "$($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s"
            $UptimeVal.Invoke([Action]{ $UptimeVal.Text = "PID $($javaw.Id) — $upStr (started $($started.ToString('HH:mm:ss')))" })
            Write-Log $SysLog "✔ javaw PID $($javaw.Id) — running $upStr"
        } else {
            $UptimeVal.Invoke([Action]{ $UptimeVal.Text = "Not running" })
            Write-Log $SysLog "[WARN] No Minecraft process found"
        }

        Write-Log $SysLog ""
        Write-Log $SysLog "── HWID ────────────────────────────────────"
        try {
            $mb   = (Get-WmiObject win32_baseboard).Manufacturer + " " + (Get-WmiObject win32_baseboard).SerialNumber
            $cpu  = (Get-WmiObject Win32_Processor).Name
            $disk = (Get-PhysicalDisk | Select-Object -First 1).SerialNumber
            $raw  = "$mb|$cpu|$disk"
            $bytes= [System.Text.Encoding]::UTF8.GetBytes($raw)
            $hwid = [Convert]::ToBase64String($bytes).Replace("=","")
            $HwidVal.Invoke([Action]{ $HwidVal.Text = $hwid })
            Write-Log $SysLog "✔ HWID generated"
            Write-Log $SysLog $hwid
        } catch {
            $HwidVal.Invoke([Action]{ $HwidVal.Text = "Error: $_" })
            Write-Log $SysLog "[WARN] HWID failed: $_"
        }

        Write-Log $SysLog ""
        Write-Log $SysLog "✔ All checks complete"
        Set-Status "Sys info checks complete"
    })
    $job.IsBackground = $true
    $job.Start()
})

[System.Windows.Forms.Application]::Run($Form)
