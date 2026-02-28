if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -Command `"Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; `$f=`$env:TEMP+'\sstool.ps1'; [System.IO.File]::WriteAllText(`$f,(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Lyrqo/ss-tool/main/ss%20tool.ps1'),[System.Text.Encoding]::UTF8); & `$f`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$cBG     = [System.Drawing.ColorTranslator]::FromHtml("#0a0c12")
$cBG2    = [System.Drawing.ColorTranslator]::FromHtml("#0f1219")
$cBG3    = [System.Drawing.ColorTranslator]::FromHtml("#141820")
$cACCENT = [System.Drawing.ColorTranslator]::FromHtml("#00d4ff")
$cRED    = [System.Drawing.ColorTranslator]::FromHtml("#ff3d5a")
$cGREEN  = [System.Drawing.ColorTranslator]::FromHtml("#00e87a")
$cORANGE = [System.Drawing.ColorTranslator]::FromHtml("#ffaa00")
$cTEXT   = [System.Drawing.ColorTranslator]::FromHtml("#d0d8e8")
$cDIM    = [System.Drawing.ColorTranslator]::FromHtml("#4a5568")
$cBORDER = [System.Drawing.ColorTranslator]::FromHtml("#1e2535")
$cWHITE  = [System.Drawing.Color]::White

$fUI   = New-Object System.Drawing.Font("Segoe UI", 10)
$fBold = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fMono = New-Object System.Drawing.Font("Consolas", 9)
$fHead = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$fTiny = New-Object System.Drawing.Font("Consolas", 8)

# --- Cheat data ---
$cheatStrings = @(
    "AimAssist","AnchorTweaks","AutoAnchor","AutoCrystal","AutoDoubleHand",
    "AutoHitCrystal","AutoPot","AutoTotem","AutoArmor","InventoryTotem",
    "Hitboxes","JumpReset","LegitTotem","PingSpoof","SelfDestruct",
    "ShieldBreaker","TriggerBot","Velocity","AxeSpam","WebMacro","FastPlace"
)
$MEM_SIGS = @(
    "KillAura","killaura","AutoCrystal","autocrystal","Scaffold","scaffold",
    "Velocity","NoFall","Freecam","ESP","Xray","xray","BHop","Flight",
    "CrystalAura","BaritoneAPI","agentmain","premain","ClassFileTransformer",
    "bytebuddy","javassist","aimbot","wallhack","autoclick","triggerbot",
    "sendPacket","injectPacket","noknockback"
)
$SI_KEYWORDS = @(
    "AutoCrystal","CrystalAura","CrystalPlace","BreakCrystal","ExplodeCrystal",
    "CrystalSwap","Surround","AntiSurround","SurroundBreaker","Trap","HoleFiller",
    "BedAura","AnchorAura","AutoTotem","TotemPopper","PopCounter","AutoOffhand",
    "PacketFly","MotionFly","ElytraFly","Phase","KillAura","TriggerBot",
    "AutoClicker","AutoObsidian","sendPacket","injectPacket","ClassFileTransformer",
    "bytebuddy","agentmain","premain"
)
$SI_PATHS = @(
    "$env:ProgramFiles\SystemInformer\SystemInformer.exe",
    "${env:ProgramFiles(x86)}\SystemInformer\SystemInformer.exe",
    "$env:ProgramFiles\Process Hacker 2\ProcessHacker.exe",
    "${env:ProgramFiles(x86)}\Process Hacker 2\ProcessHacker.exe",
    "C:\Tools\SystemInformer\SystemInformer.exe",
    "C:\Tools\ProcessHacker\ProcessHacker.exe"
)

$global:McFolder = ""
$global:OutFolder = ""
$global:StopScan  = $false
$global:StopMem   = $false
$global:StopSI    = $false

# --- Helpers ---
function New-Lbl($txt,$x,$y,$w,$h,$fg,$bg,$font=$fUI,$align="MiddleLeft") {
    $l = New-Object System.Windows.Forms.Label
    $l.Text=$txt; $l.Location=New-Object System.Drawing.Point($x,$y)
    $l.Size=New-Object System.Drawing.Size($w,$h)
    $l.ForeColor=$fg; $l.BackColor=$bg; $l.Font=$font
    $l.TextAlign=[System.Drawing.ContentAlignment]::$align
    return $l
}
function New-Btn($txt,$x,$y,$w,$h,$bg,$fg) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text=$txt; $b.Location=New-Object System.Drawing.Point($x,$y)
    $b.Size=New-Object System.Drawing.Size($w,$h)
    $b.BackColor=$bg; $b.ForeColor=$fg; $b.FlatStyle="Flat"
    $b.FlatAppearance.BorderSize=0; $b.Font=$fBold; $b.Cursor="Hand"
    return $b
}
function New-Tbox($x,$y,$w,$h,$multi=$false) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location=New-Object System.Drawing.Point($x,$y)
    $t.Size=New-Object System.Drawing.Size($w,$h)
    $t.BackColor=$cBG3; $t.ForeColor=$cTEXT; $t.BorderStyle="None"; $t.Font=$fMono
    if ($multi) { $t.Multiline=$true; $t.ScrollBars="Vertical"; $t.ReadOnly=$true; $t.WordWrap=$true }
    return $t
}
function Log($box,$txt) {
    if ($box.InvokeRequired) { $box.Invoke([Action]{ $box.AppendText("$txt`r`n"); $box.ScrollToCaret() }) }
    else { $box.AppendText("$txt`r`n"); $box.ScrollToCaret() }
}
function Browse-Folder($title) {
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.BrowseForFolder(0,$title,0,0)
    if ($folder) { return $folder.Self.Path } else { return $null }
}

# --- Mod analyzer functions ---
function Get-SHA1($filePath) {
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}
function Get-ZoneId($filePath) {
    $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
    if ($ads -match "HostUrl=(.+)") { return $matches[1].Trim() }
    return $null
}
function Fetch-Modrinth($hash) {
    try {
        $r = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($r.project_id) {
            $p = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($r.project_id)" -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ Name = $p.title; Slug = $p.slug }
        }
    } catch {}
    return @{ Name = ""; Slug = "" }
}
function Fetch-Megabase($hash) {
    try {
        $r = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $r.error) { return $r.data }
    } catch {}
    return $null
}
function Check-CheatStrings($filePath) {
    $found = [System.Collections.Generic.HashSet[string]]::new()
    $content = Get-Content -Raw $filePath -ErrorAction SilentlyContinue
    if (-not $content) { return $found }
    foreach ($s in $cheatStrings) {
        if ($content -match $s) { $found.Add($s) | Out-Null }
    }
    return $found
}

# --- Form ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "SS Tool  //  MC Cheat Scanner"
$Form.Size = New-Object System.Drawing.Size(1100,720)
$Form.MinimumSize = New-Object System.Drawing.Size(960,600)
$Form.BackColor = $cBG
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"

$Header = New-Object System.Windows.Forms.Panel
$Header.Dock = "Top"; $Header.Height = 52; $Header.BackColor = $cBG2
$Header.Controls.Add((New-Lbl "SS TOOL  //  MC CHEAT SCANNER" 16 12 500 28 $cACCENT $cBG2 $fHead))
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
$adminTxt   = if ($isAdmin) { "[ADMIN]" } else { "[NOT ADMIN]" }
$adminColor = if ($isAdmin) { $cGREEN } else { $cRED }
$Header.Controls.Add((New-Lbl $adminTxt 950 16 120 22 $adminColor $cBG2 $fTiny "MiddleRight"))
$Form.Controls.Add($Header)

$NavLine = New-Object System.Windows.Forms.Panel
$NavLine.Dock = "Top"; $NavLine.Height = 1; $NavLine.BackColor = $cBORDER
$Form.Controls.Add($NavLine)

$Nav = New-Object System.Windows.Forms.Panel
$Nav.Dock = "Top"; $Nav.Height = 40; $Nav.BackColor = $cBG2
$Form.Controls.Add($Nav)

$NavLine2 = New-Object System.Windows.Forms.Panel
$NavLine2.Dock = "Top"; $NavLine2.Height = 1; $NavLine2.BackColor = $cBORDER
$Form.Controls.Add($NavLine2)

$Container = New-Object System.Windows.Forms.Panel
$Container.Dock = "Fill"; $Container.BackColor = $cBG
$Form.Controls.Add($Container)

$StatusBar = New-Object System.Windows.Forms.Panel
$StatusBar.Dock = "Bottom"; $StatusBar.Height = 24; $StatusBar.BackColor = $cBG2
$StatusLbl = New-Lbl "Ready - set paths in Setup then run a scan" 10 4 900 18 $cDIM $cBG2 $fTiny
$StatusBar.Controls.Add($StatusLbl)
$Form.Controls.Add($StatusBar)

function Set-Status($msg) {
    if ($StatusLbl.InvokeRequired) { $StatusLbl.Invoke([Action]{ $StatusLbl.Text = $msg }) }
    else { $StatusLbl.Text = $msg }
}

$Pages = @{}
function Show-Page($name) {
    foreach ($p in $Pages.Values) { $p.Visible = $false }
    $Pages[$name].Visible = $true
    foreach ($nb in $Nav.Controls) {
        if ($nb -is [System.Windows.Forms.Button]) {
            if ($nb.Tag -eq $name) { $nb.ForeColor = $cACCENT; $nb.BackColor = $cBG3 }
            else { $nb.ForeColor = $cDIM; $nb.BackColor = $cBG2 }
        }
    }
}

$navNames = @("Setup","Scanner","Memory","Sys Info","System Informer")
$nx = 0
foreach ($name in $navNames) {
    $nb = New-Object System.Windows.Forms.Button
    $nb.Text = " $name "; $nb.Tag = $name
    $nb.Location = New-Object System.Drawing.Point($nx,0); $nb.Size = New-Object System.Drawing.Size(140,40)
    $nb.BackColor = $cBG2; $nb.ForeColor = $cDIM; $nb.FlatStyle = "Flat"
    $nb.FlatAppearance.BorderSize = 0; $nb.Font = $fBold; $nb.Cursor = "Hand"
    $nb.Add_Click({ param($s,$e) Show-Page $s.Tag })
    $Nav.Controls.Add($nb)
    $nx += 140
    $page = New-Object System.Windows.Forms.Panel
    $page.Dock = "Fill"; $page.BackColor = $cBG; $page.Visible = $false
    $Container.Controls.Add($page)
    $Pages[$name] = $page
}

$pSetup   = $Pages["Setup"]
$pScan    = $Pages["Scanner"]
$pMemory  = $Pages["Memory"]
$pSysInfo = $Pages["Sys Info"]
$pSI      = $Pages["System Informer"]

# =====================================================================
# SETUP PAGE
# =====================================================================
$pSetup.Controls.Add((New-Lbl "SETUP" 20 18 300 30 $cACCENT $cBG $fHead))
$pSetup.Controls.Add((New-Lbl "Set your folders before running any scan." 20 52 600 22 $cDIM $cBG $fUI))

$pSetup.Controls.Add((New-Lbl "Minecraft Mods Folder" 20 88 300 22 $cACCENT $cBG $fBold))
$McEntry = New-Tbox 20 114 740 28
$McEntry.Text = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
$global:McFolder = $McEntry.Text
$pSetup.Controls.Add($McEntry)
$bMc = New-Btn "Browse" 770 112 100 30 $cBG3 $cACCENT
$bMc.Add_Click({
    $path = Browse-Folder "Select Minecraft mods folder"
    if ($path) { $McEntry.Text = $path; $global:McFolder = $path }
})
$pSetup.Controls.Add($bMc)
$bMcOpen = New-Btn "Open" 878 112 80 30 $cBG3 $cDIM
$bMcOpen.Add_Click({
    $p = if ($McEntry.Text.Trim()) { $McEntry.Text.Trim() } else { $env:APPDATA }
    Start-Process explorer.exe $p
})
$pSetup.Controls.Add($bMcOpen)

$pSetup.Controls.Add((New-Lbl "Output / Report Folder" 20 158 300 22 $cACCENT $cBG $fBold))
$OutEntry = New-Tbox 20 184 740 28
$OutEntry.Text = "$env:USERPROFILE\Desktop"
$global:OutFolder = $OutEntry.Text
$pSetup.Controls.Add($OutEntry)
$bOut = New-Btn "Browse" 770 182 100 30 $cBG3 $cACCENT
$bOut.Add_Click({
    $path = Browse-Folder "Select output folder"
    if ($path) { $OutEntry.Text = $path; $global:OutFolder = $path }
})
$pSetup.Controls.Add($bOut)
$bOutOpen = New-Btn "Open" 878 182 80 30 $cBG3 $cDIM
$bOutOpen.Add_Click({
    $p = if ($OutEntry.Text.Trim()) { $OutEntry.Text.Trim() } else { $env:USERPROFILE }
    Start-Process explorer.exe $p
})
$pSetup.Controls.Add($bOutOpen)

$pSetup.Controls.Add((New-Lbl "Quick Launch" 20 228 300 22 $cACCENT $cBG $fBold))
$ql1 = New-Btn "> Mod Scanner"   20  254 150 36 $cGREEN $cBG
$ql2 = New-Btn "> Memory Scan"  180  254 150 36 $cACCENT $cBG
$ql3 = New-Btn "> Sys Info"     340  254 130 36 $cORANGE $cBG
$ql4 = New-Btn "> SI Deep Scan" 480  254 150 36 $cRED $cWHITE
$ql1.Add_Click({ Show-Page "Scanner" })
$ql2.Add_Click({ Show-Page "Memory" })
$ql3.Add_Click({ Show-Page "Sys Info" })
$ql4.Add_Click({ Show-Page "System Informer" })
$pSetup.Controls.AddRange(@($ql1,$ql2,$ql3,$ql4))

$pSetup.Controls.Add((New-Lbl "Requirements" 20 310 200 22 $cACCENT $cBG $fBold))
$adminReq = if ($isAdmin) { "[OK] Admin" } else { "[X] Admin" }
$winReq   = if ([System.Environment]::OSVersion.Platform -eq "Win32NT") { "[OK] Windows" } else { "[X] Windows" }
$siFoundPath = $SI_PATHS | Where-Object { Test-Path $_ } | Select-Object -First 1
$siReq    = if ($siFoundPath) { "[OK] System Informer" } else { "[X] System Informer (get from systeminformer.sourceforge.io)" }
$pSetup.Controls.Add((New-Lbl "$adminReq   $winReq   $siReq" 20 336 900 24 $cTEXT $cBG $fMono))

# =====================================================================
# SCANNER PAGE  (HabibiModAnalyzer logic)
# =====================================================================
$scanTopBar = New-Object System.Windows.Forms.Panel
$scanTopBar.Dock = "Top"; $scanTopBar.Height = 48; $scanTopBar.BackColor = $cBG2
$pScan.Controls.Add($scanTopBar)
$scanTopBar.Controls.Add((New-Lbl "MOD ANALYZER" 16 14 220 22 $cACCENT $cBG2 $fBold))
$scanTopBar.Controls.Add((New-Lbl "Checks Modrinth + Megabase, then scans for cheat strings in unknown jars" 240 16 520 18 $cDIM $cBG2 $fTiny))

$stopScanBtn = New-Btn "STOP" 940 10 100 28 $cRED $cWHITE
$stopScanBtn.Enabled = $false
$stopScanBtn.Add_Click({ $global:StopScan = $true })
$scanTopBar.Controls.Add($stopScanBtn)

$startScanBtn = New-Btn "> START SCAN" 820 10 116 28 $cGREEN $cBG
$scanTopBar.Controls.Add($startScanBtn)

$scanProg = New-Object System.Windows.Forms.ProgressBar
$scanProg.Dock = "Top"; $scanProg.Height = 4
$scanProg.Style = "Continuous"; $scanProg.ForeColor = $cACCENT
$pScan.Controls.Add($scanProg)

$scanSplit = New-Object System.Windows.Forms.SplitContainer
$scanSplit.Dock = "Fill"; $scanSplit.SplitterDistance = 300; $scanSplit.BackColor = $cBORDER
$scanSplit.Panel1.BackColor = $cBG2; $scanSplit.Panel2.BackColor = $cBG
$pScan.Controls.Add($scanSplit)

$scanSplit.Panel1.Controls.Add((New-Lbl "RESULTS" 10 8 200 18 $cDIM $cBG2 $fTiny))

$cntPanel = New-Object System.Windows.Forms.Panel
$cntPanel.Location = New-Object System.Drawing.Point(6,28)
$cntPanel.Size = New-Object System.Drawing.Size(282,48)
$cntPanel.BackColor = $cBG2
$verLbl   = New-Lbl "0  OK"    0   0 94 48 $cGREEN  $cBG3 $fBold "MiddleCenter"
$unkLbl   = New-Lbl "0  UNK"  95   0 94 48 $cORANGE $cBG3 $fBold "MiddleCenter"
$cheatLbl = New-Lbl "0  CHEAT" 190 0 94 48 $cRED    $cBG3 $fBold "MiddleCenter"
$cntPanel.Controls.AddRange(@($verLbl,$unkLbl,$cheatLbl))
$scanSplit.Panel1.Controls.Add($cntPanel)

$findBox = New-Object System.Windows.Forms.ListBox
$findBox.Location = New-Object System.Drawing.Point(6,82)
$findBox.Size = New-Object System.Drawing.Size(282,500)
$findBox.BackColor = $cBG2; $findBox.ForeColor = $cTEXT
$findBox.BorderStyle = "None"; $findBox.Font = $fMono
$scanSplit.Panel1.Controls.Add($findBox)

$scanSplit.Panel2.Controls.Add((New-Lbl "SCAN LOG" 10 8 200 18 $cDIM $cBG $fTiny))
$scanLog = New-Tbox 6 28 0 0 $true; $scanLog.Dock = "Fill"; $scanLog.BackColor = $cBG
$scanSplit.Panel2.Controls.Add($scanLog)

$startScanBtn.Add_Click({
    $global:McFolder  = $McEntry.Text.Trim()
    $global:OutFolder = $OutEntry.Text.Trim()
    if (-not $global:McFolder -or -not (Test-Path $global:McFolder)) {
        Log $scanLog "[ERROR] Set a valid Minecraft mods folder in Setup."; return
    }
    if (-not $global:OutFolder -or -not (Test-Path $global:OutFolder)) {
        Log $scanLog "[ERROR] Set a valid output folder in Setup."; return
    }
    $global:StopScan = $false
    $findBox.Items.Clear(); $scanLog.Clear(); $scanProg.Value = 0
    $verLbl.Text = "0  OK"; $unkLbl.Text = "0  UNK"; $cheatLbl.Text = "0  CHEAT"
    $startScanBtn.Enabled = $false; $stopScanBtn.Enabled = $true
    Set-Status "Mod analyzer running..."

    $t = [System.Threading.Thread]::new({
        $mc  = $global:McFolder
        $out = $global:OutFolder
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        Log $scanLog "Mod Analyzer started  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Log $scanLog "Folder: $mc"
        Log $scanLog ""

        $jarFiles = Get-ChildItem -Path $mc -Filter "*.jar" -ErrorAction SilentlyContinue
        $total = $jarFiles.Count
        if ($total -eq 0) {
            Log $scanLog "[WARN] No .jar files found in that folder."
            $startScanBtn.Invoke([Action]{ $startScanBtn.Enabled = $true })
            $stopScanBtn.Invoke([Action]{ $stopScanBtn.Enabled = $false })
            Set-Status "No jars found"; return
        }
        Log $scanLog "Found $total jar file(s) to check"
        Log $scanLog ""

        $counter = 0
        $verifiedMods = [System.Collections.ArrayList]::new()
        $unknownMods  = [System.Collections.ArrayList]::new()
        $cheatMods    = [System.Collections.ArrayList]::new()

        foreach ($file in $jarFiles) {
            if ($global:StopScan) { Log $scanLog "-- Scan stopped by user --"; break }
            $counter++
            $pct = [int](($counter / $total) * 85) + 5
            $scanProg.Invoke([Action]{ $scanProg.Value = $pct })
            Log $scanLog "[$counter/$total] $($file.Name)"

            $hash = Get-SHA1 $file.FullName

            $mr = Fetch-Modrinth $hash
            if ($mr.Slug) {
                Log $scanLog "  [OK] Modrinth verified: $($mr.Name)"
                $verifiedMods.Add([PSCustomObject]@{ ModName = $mr.Name; FileName = $file.Name }) | Out-Null
                $findBox.Invoke([Action]{ $findBox.Items.Add("[OK] $($file.Name)") | Out-Null })
                $v = [int]($verLbl.Text.Split(" ")[0]) + 1
                $verLbl.Invoke([Action]{ $verLbl.Text = "$v  OK" })
                continue
            }

            $mb = Fetch-Megabase $hash
            if ($mb -and $mb.name) {
                Log $scanLog "  [OK] Megabase verified: $($mb.name)"
                $verifiedMods.Add([PSCustomObject]@{ ModName = $mb.name; FileName = $file.Name }) | Out-Null
                $findBox.Invoke([Action]{ $findBox.Items.Add("[OK] $($file.Name)") | Out-Null })
                $v = [int]($verLbl.Text.Split(" ")[0]) + 1
                $verLbl.Invoke([Action]{ $verLbl.Text = "$v  OK" })
                continue
            }

            Log $scanLog "  [?] Not in databases, scanning strings..."
            $strings = Check-CheatStrings $file.FullName
            if ($strings.Count -gt 0) {
                $joined = ($strings -join ", ")
                Log $scanLog "  [CHEAT] Hits: $joined"
                $cheatMods.Add([PSCustomObject]@{ FileName = $file.Name; DepFile = ""; Strings = $joined }) | Out-Null
                $findBox.Invoke([Action]{ $findBox.Items.Add("[CHEAT] $($file.Name)") | Out-Null })
                $c = [int]($cheatLbl.Text.Split(" ")[0]) + 1
                $cheatLbl.Invoke([Action]{ $cheatLbl.Text = "$c  CHEAT" })
                continue
            }

            # Try nested jars in META-INF/jars
            $tempExtract = $null
            $foundInDep  = $false
            try {
                $tempExtract = Join-Path $env:TEMP ("habibi_" + [System.IO.Path]::GetRandomFileName())
                New-Item -ItemType Directory -Path $tempExtract | Out-Null
                [System.IO.Compression.ZipFile]::ExtractToDirectory($file.FullName, $tempExtract)
                $depJarsPath = Join-Path $tempExtract "META-INF\jars"
                if (Test-Path $depJarsPath) {
                    foreach ($dep in (Get-ChildItem $depJarsPath -Filter "*.jar")) {
                        $depStrings = Check-CheatStrings $dep.FullName
                        if ($depStrings.Count -gt 0) {
                            $joined = ($depStrings -join ", ")
                            Log $scanLog "  [CHEAT] Dep jar $($dep.Name): $joined"
                            $cheatMods.Add([PSCustomObject]@{ FileName = $file.Name; DepFile = $dep.Name; Strings = $joined }) | Out-Null
                            $findBox.Invoke([Action]{ $findBox.Items.Add("[CHEAT] $($file.Name) > $($dep.Name)") | Out-Null })
                            $c = [int]($cheatLbl.Text.Split(" ")[0]) + 1
                            $cheatLbl.Invoke([Action]{ $cheatLbl.Text = "$c  CHEAT" })
                            $foundInDep = $true
                        }
                    }
                }
            } catch {}
            finally {
                if ($tempExtract -and (Test-Path $tempExtract)) {
                    Remove-Item -Recurse -Force $tempExtract -ErrorAction SilentlyContinue
                }
            }

            if (-not $foundInDep) {
                $zone = Get-ZoneId $file.FullName
                $unknownMods.Add([PSCustomObject]@{ FileName = $file.Name; ZoneId = $zone }) | Out-Null
                $findBox.Invoke([Action]{ $findBox.Items.Add("[UNK] $($file.Name)") | Out-Null })
                $u = [int]($unkLbl.Text.Split(" ")[0]) + 1
                $unkLbl.Invoke([Action]{ $unkLbl.Text = "$u  UNK" })
                if ($zone) { Log $scanLog "  [UNK] Source: $zone" }
                else { Log $scanLog "  [UNK] No database match, no cheat strings" }
            }
        }

        # Write report
        $scanProg.Invoke([Action]{ $scanProg.Value = 95 })
        Log $scanLog ""
        Log $scanLog "Writing report..."
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $lines = @(
            "="*60,
            "  MOD ANALYZER REPORT",
            "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "  $env:COMPUTERNAME / $env:USERNAME",
            "  Folder: $mc",
            "="*60,
            "",
            "  Total: $total   Verified: $($verifiedMods.Count)   Unknown: $($unknownMods.Count)   Cheat: $($cheatMods.Count)",
            ""
        )
        if ($verifiedMods.Count -gt 0) {
            $lines += "--- VERIFIED MODS ---"
            foreach ($m in $verifiedMods) { $lines += "  [OK]    $($m.ModName)  --  $($m.FileName)" }
            $lines += ""
        }
        if ($unknownMods.Count -gt 0) {
            $lines += "--- UNKNOWN MODS ---"
            foreach ($m in $unknownMods) {
                if ($m.ZoneId) { $lines += "  [UNK]   $($m.FileName)  --  from: $($m.ZoneId)" }
                else { $lines += "  [UNK]   $($m.FileName)" }
            }
            $lines += ""
        }
        if ($cheatMods.Count -gt 0) {
            $lines += "--- CHEAT MODS ---"
            foreach ($m in $cheatMods) {
                if ($m.DepFile) { $lines += "  [CHEAT] $($m.FileName) > $($m.DepFile)  --  $($m.Strings)" }
                else { $lines += "  [CHEAT] $($m.FileName)  --  $($m.Strings)" }
            }
            $lines += ""
        }
        $lines | Out-File "$out\modscan_$stamp.txt" -Encoding UTF8
        Log $scanLog "Report saved: $out\modscan_$stamp.txt"
        $scanProg.Invoke([Action]{ $scanProg.Value = 100 })
        Set-Status "Done -- OK: $($verifiedMods.Count)  UNK: $($unknownMods.Count)  CHEAT: $($cheatMods.Count)"
        Log $scanLog ""
        Log $scanLog "Scan complete."
        $startScanBtn.Invoke([Action]{ $startScanBtn.Enabled = $true })
        $stopScanBtn.Invoke([Action]{ $stopScanBtn.Enabled = $false })
    })
    $t.IsBackground = $true; $t.Start()
})

# =====================================================================
# MEMORY PAGE
# =====================================================================
$memTopBar = New-Object System.Windows.Forms.Panel
$memTopBar.Dock = "Top"; $memTopBar.Height = 48; $memTopBar.BackColor = $cBG2
$pMemory.Controls.Add($memTopBar)
$memTopBar.Controls.Add((New-Lbl "MEMORY SCANNER" 16 14 300 22 $cACCENT $cBG2 $fBold))
$memTopBar.Controls.Add((New-Lbl "Scans javaw.exe RAM for cheat signatures" 240 16 400 18 $cDIM $cBG2 $fTiny))

$stopMemBtn = New-Btn "STOP" 940 10 100 28 $cRED $cWHITE
$stopMemBtn.Enabled = $false
$stopMemBtn.Add_Click({ $global:StopMem = $true })
$memTopBar.Controls.Add($stopMemBtn)

$startMemBtn = New-Btn "> SCAN MEMORY" 800 10 136 28 $cACCENT $cBG
$memTopBar.Controls.Add($startMemBtn)

$memLog = New-Tbox 8 56 0 0 $true; $memLog.Dock = "Fill"; $memLog.BackColor = $cBG
$pMemory.Controls.Add($memLog)

$startMemBtn.Add_Click({
    $memLog.Clear(); $global:StopMem = $false
    $startMemBtn.Enabled = $false; $stopMemBtn.Enabled = $true
    Set-Status "Memory scan running..."
    $t = [System.Threading.Thread]::new({
        Log $memLog "Memory scan started  $(Get-Date -Format 'HH:mm:ss')"
        Log $memLog ""
        $javaws = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
        if (-not $javaws) { $javaws = Get-Process -Name "java" -ErrorAction SilentlyContinue }
        if (-not $javaws) {
            Log $memLog "[WARN] No javaw/java process found. Is Minecraft running?"
            $startMemBtn.Invoke([Action]{ $startMemBtn.Enabled = $true })
            $stopMemBtn.Invoke([Action]{ $stopMemBtn.Enabled = $false })
            Set-Status "No Minecraft found"; return
        }
        Add-Type @"
using System; using System.Runtime.InteropServices;
public class MemReader {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a,bool b,int c);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int s,out int r);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h,IntPtr a,out MBI m,uint s);
    [StructLayout(LayoutKind.Sequential)] public struct MBI {
        public IntPtr Base,AllocBase; public uint AllocProtect;
        public IntPtr RegionSize; public uint State,Protect,Type;
    }
}
"@ -ErrorAction SilentlyContinue
        $totalHits = 0
        foreach ($proc in $javaws) {
            if ($global:StopMem) { break }
            Log $memLog "Scanning PID $($proc.Id)..."
            $handle = [MemReader]::OpenProcess(0x0410,$false,$proc.Id)
            if ($handle -eq [IntPtr]::Zero) {
                Log $memLog "[WARN] Cannot open PID $($proc.Id) - need admin"
                continue
            }
            $addr = [IntPtr]::Zero; $hits = @{}; $scanned = 0
            while ($scanned -lt 512MB -and -not $global:StopMem) {
                $mbi = New-Object MemReader+MBI
                $ret = [MemReader]::VirtualQueryEx($handle,$addr,[ref]$mbi,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
                if ($ret -eq 0) { break }
                $size = $mbi.RegionSize.ToInt64()
                if ($size -le 0) { break }
                $readable = ($mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x20 -or $mbi.Protect -eq 0x40)
                if ($mbi.State -eq 0x1000 -and $readable) {
                    $buf = New-Object byte[] ([Math]::Min($size,4MB)); $read = 0
                    if ([MemReader]::ReadProcessMemory($handle,$mbi.Base,$buf,$buf.Length,[ref]$read) -and $read -gt 0) {
                        $str = [System.Text.Encoding]::UTF8.GetString($buf,0,$read)
                        foreach ($sig in $MEM_SIGS) {
                            if (-not $hits[$sig] -and $str.Contains($sig)) {
                                $hits[$sig] = $true
                                Log $memLog "[CRIT] HIT: $sig"
                                $totalHits++
                            }
                        }
                    }
                    $scanned += $read
                }
                $next = $mbi.Base.ToInt64() + $size
                if ($next -ge 0x7FFFFFFFFFFF) { break }
                $addr = [IntPtr]::new($next)
            }
            [MemReader]::CloseHandle($handle) | Out-Null
            if ($hits.Count -eq 0) { Log $memLog "  Clean: PID $($proc.Id)" }
            else { Log $memLog "  ! PID $($proc.Id) - $($hits.Count) signature(s)" }
        }
        Log $memLog ""; Log $memLog "Done -- $totalHits total hit(s)"
        Set-Status "Memory scan done -- $totalHits hit(s)"
        $startMemBtn.Invoke([Action]{ $startMemBtn.Enabled = $true })
        $stopMemBtn.Invoke([Action]{ $stopMemBtn.Enabled = $false })
    })
    $t.IsBackground = $true; $t.Start()
})

# =====================================================================
# SYS INFO PAGE
# =====================================================================
$sysTopBar = New-Object System.Windows.Forms.Panel
$sysTopBar.Dock = "Top"; $sysTopBar.Height = 48; $sysTopBar.BackColor = $cBG2
$pSysInfo.Controls.Add($sysTopBar)
$sysTopBar.Controls.Add((New-Lbl "SYSTEM INFO" 16 14 300 22 $cACCENT $cBG2 $fBold))

$stopSysBtn = New-Btn "STOP" 940 10 100 28 $cRED $cWHITE
$stopSysBtn.Enabled = $false
$sysTopBar.Controls.Add($stopSysBtn)

$runSysBtn = New-Btn "> RUN CHECKS" 820 10 116 28 $cORANGE $cBG
$sysTopBar.Controls.Add($runSysBtn)

$uptimePanel = New-Object System.Windows.Forms.Panel
$uptimePanel.Location = New-Object System.Drawing.Point(8,56)
$uptimePanel.Size = New-Object System.Drawing.Size(600,56)
$uptimePanel.BackColor = $cBG3
$pSysInfo.Controls.Add($uptimePanel)
$uptimePanel.Controls.Add((New-Lbl "MC UPTIME" 12 6 200 16 $cDIM $cBG3 $fTiny))
$uptimeVal = New-Lbl "---" 12 24 580 24 $cTEXT $cBG3 $fBold
$uptimePanel.Controls.Add($uptimeVal)

$hwidPanel = New-Object System.Windows.Forms.Panel
$hwidPanel.Location = New-Object System.Drawing.Point(8,120)
$hwidPanel.Size = New-Object System.Drawing.Size(1050,56)
$hwidPanel.BackColor = $cBG3
$pSysInfo.Controls.Add($hwidPanel)
$hwidPanel.Controls.Add((New-Lbl "HWID" 12 6 200 16 $cDIM $cBG3 $fTiny))
$hwidVal = New-Lbl "---" 12 24 1020 24 $cACCENT $cBG3 $fMono
$hwidPanel.Controls.Add($hwidVal)

$sysLog = New-Tbox 8 184 1066 400 $true
$sysLog.Anchor = "Top,Bottom,Left,Right"
$pSysInfo.Controls.Add($sysLog)

$runSysBtn.Add_Click({
    $sysLog.Clear()
    $uptimeVal.Text = "Checking..."
    $hwidVal.Text   = "Generating..."
    $runSysBtn.Enabled = $false; $stopSysBtn.Enabled = $true
    Set-Status "Running sys info checks..."
    $t = [System.Threading.Thread]::new({
        Log $sysLog "Checks started  $(Get-Date -Format 'HH:mm:ss')"
        Log $sysLog "Host: $env:COMPUTERNAME   User: $env:USERNAME"
        Log $sysLog ""
        Log $sysLog "--- MC Uptime ---"
        $jw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $jw) { $jw = Get-Process -Name "java" -ErrorAction SilentlyContinue | Select-Object -First 1 }
        if ($jw) {
            $el = (Get-Date) - $jw.StartTime
            $startedAt = $jw.StartTime.ToString("HH:mm:ss")
            $pid_ = $jw.Id; $pname = $jw.Name
            $ups = "$($el.Hours)h $($el.Minutes)m $($el.Seconds)s"
            $uptimeVal.Invoke([Action]{ $uptimeVal.Text = "$pname PID $pid_  --  $ups  (started $startedAt)" })
            Log $sysLog "[OK] $pname PID $pid_ running for $ups (since $startedAt)"
        } else {
            $uptimeVal.Invoke([Action]{ $uptimeVal.Text = "Minecraft not running" })
            Log $sysLog "No javaw/java process found."
        }
        Log $sysLog ""
        Log $sysLog "--- HWID ---"
        try {
            $mb   = (Get-WmiObject win32_baseboard).Manufacturer + " " + (Get-WmiObject win32_baseboard).SerialNumber
            $cpu  = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
            $disk = (Get-PhysicalDisk | Select-Object -First 1).SerialNumber
            $raw  = "$mb|$cpu|$disk"
            $hwid = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($raw)).Replace("=","")
            $hwidVal.Invoke([Action]{ $hwidVal.Text = $hwid })
            Log $sysLog "[OK] HWID generated:"
            Log $sysLog $hwid
        } catch {
            $err = $_.ToString()
            $hwidVal.Invoke([Action]{ $hwidVal.Text = "Error: $err" })
            Log $sysLog "HWID failed: $err"
        }
        Log $sysLog ""; Log $sysLog "All checks complete."
        Set-Status "Sys info checks complete"
        $runSysBtn.Invoke([Action]{ $runSysBtn.Enabled = $true })
        $stopSysBtn.Invoke([Action]{ $stopSysBtn.Enabled = $false })
    })
    $t.IsBackground = $true; $t.Start()
})

# =====================================================================
# SYSTEM INFORMER PAGE
# =====================================================================
$siTopBar = New-Object System.Windows.Forms.Panel
$siTopBar.Dock = "Top"; $siTopBar.Height = 48; $siTopBar.BackColor = $cBG2
$pSI.Controls.Add($siTopBar)
$siTopBar.Controls.Add((New-Lbl "SYSTEM INFORMER DEEP SCAN" 16 14 360 22 $cACCENT $cBG2 $fBold))
$siTopBar.Controls.Add((New-Lbl "Scans javaw private memory for cheat keywords (case insensitive)" 380 16 500 18 $cDIM $cBG2 $fTiny))

$stopSIBtn = New-Btn "STOP" 940 10 100 28 $cRED $cWHITE
$stopSIBtn.Enabled = $false
$stopSIBtn.Add_Click({ $global:StopSI = $true })
$siTopBar.Controls.Add($stopSIBtn)

$startSIBtn = New-Btn "> RUN SI SCAN" 810 10 126 28 $cRED $cWHITE
$siTopBar.Controls.Add($startSIBtn)

$siInfoPanel = New-Object System.Windows.Forms.Panel
$siInfoPanel.Dock = "Top"; $siInfoPanel.Height = 56; $siInfoPanel.BackColor = $cBG3
$pSI.Controls.Add($siInfoPanel)
$siStatusVal  = New-Lbl "Idle -- press Run SI Scan to start" 16 8 700 18 $cDIM $cBG3 $fMono
$siKeywordVal = New-Lbl "Keywords: $($SI_KEYWORDS.Count) loaded" 16 30 700 18 $cDIM $cBG3 $fTiny
$siInfoPanel.Controls.AddRange(@($siStatusVal,$siKeywordVal))

$siSplit = New-Object System.Windows.Forms.SplitContainer
$siSplit.Dock = "Fill"; $siSplit.SplitterDistance = 320; $siSplit.BackColor = $cBORDER
$siSplit.Panel1.BackColor = $cBG2; $siSplit.Panel2.BackColor = $cBG
$pSI.Controls.Add($siSplit)

$siSplit.Panel1.Controls.Add((New-Lbl "HITS" 10 8 200 18 $cDIM $cBG2 $fTiny))
$siHitBox = New-Object System.Windows.Forms.ListBox
$siHitBox.Location = New-Object System.Drawing.Point(6,30)
$siHitBox.Size = New-Object System.Drawing.Size(302,530)
$siHitBox.BackColor = $cBG2; $siHitBox.ForeColor = $cRED
$siHitBox.BorderStyle = "None"; $siHitBox.Font = $fMono
$siSplit.Panel1.Controls.Add($siHitBox)

$siSplit.Panel2.Controls.Add((New-Lbl "SI SCAN LOG" 10 8 200 18 $cDIM $cBG $fTiny))
$siLog = New-Tbox 6 28 0 0 $true; $siLog.Dock = "Fill"; $siLog.BackColor = $cBG
$siSplit.Panel2.Controls.Add($siLog)

$startSIBtn.Add_Click({
    $global:OutFolder = $OutEntry.Text.Trim()
    if (-not $global:OutFolder -or -not (Test-Path $global:OutFolder)) {
        Log $siLog "[ERROR] Set a valid output folder in Setup first."; return
    }
    $siLog.Clear(); $siHitBox.Items.Clear(); $global:StopSI = $false
    $startSIBtn.Enabled = $false; $stopSIBtn.Enabled = $true
    $siStatusVal.Text = "Starting..."
    Set-Status "System Informer scan running..."

    $t = [System.Threading.Thread]::new({
        $out = $global:OutFolder
        Log $siLog "SI Deep Scan started  $(Get-Date -Format 'HH:mm:ss')"
        Log $siLog ""

        $siExe = $SI_PATHS | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $siExe) {
            Log $siLog "[ERROR] System Informer not found."
            Log $siLog "Download from: https://systeminformer.sourceforge.io"
            $siStatusVal.Invoke([Action]{ $siStatusVal.Text = "System Informer not found" })
            $startSIBtn.Invoke([Action]{ $startSIBtn.Enabled = $true })
            $stopSIBtn.Invoke([Action]{ $stopSIBtn.Enabled = $false })
            Set-Status "SI not found"; return
        }
        Log $siLog "[OK] Found: $siExe"

        $siProc = Get-Process -Name "SystemInformer","ProcessHacker" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $siProc) {
            Log $siLog "Launching System Informer..."
            Start-Process $siExe
            Start-Sleep -Seconds 3
            $siProc = Get-Process -Name "SystemInformer","ProcessHacker" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if (-not $siProc) {
            Log $siLog "[ERROR] Could not launch System Informer."
            $startSIBtn.Invoke([Action]{ $startSIBtn.Enabled = $true })
            $stopSIBtn.Invoke([Action]{ $stopSIBtn.Enabled = $false }); return
        }
        Log $siLog "[OK] System Informer running PID $($siProc.Id)"

        $javaw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $javaw) {
            Log $siLog "[WARN] No javaw.exe found - is Minecraft running?"
            $siStatusVal.Invoke([Action]{ $siStatusVal.Text = "No javaw.exe found" })
            $startSIBtn.Invoke([Action]{ $startSIBtn.Enabled = $true })
            $stopSIBtn.Invoke([Action]{ $stopSIBtn.Enabled = $false })
            Set-Status "No Minecraft found"; return
        }
        Log $siLog "[OK] javaw.exe PID $($javaw.Id)"
        $siStatusVal.Invoke([Action]{ $siStatusVal.Text = "Scanning $($SI_KEYWORDS.Count) keywords in PID $($javaw.Id)..." })

        Add-Type @"
using System; using System.Runtime.InteropServices;
public class SIMemSearch {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a,bool b,int c);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int s,out int r);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h,IntPtr a,out MBI2 m,uint s);
    [StructLayout(LayoutKind.Sequential)] public struct MBI2 {
        public IntPtr Base,AllocBase; public uint AllocProtect;
        public IntPtr RegionSize; public uint State,Protect,Type;
    }
}
"@ -ErrorAction SilentlyContinue

        $handle = [SIMemSearch]::OpenProcess(0x0410,$false,$javaw.Id)
        if ($handle -eq [IntPtr]::Zero) {
            Log $siLog "[ERROR] Cannot open javaw.exe - ensure running as admin"
            $startSIBtn.Invoke([Action]{ $startSIBtn.Enabled = $true })
            $stopSIBtn.Invoke([Action]{ $stopSIBtn.Enabled = $false }); return
        }

        $allHits = @{}
        $addr = [IntPtr]::Zero; $scanned = 0
        Log $siLog "Scanning private memory regions (case insensitive)..."
        Log $siLog ""

        while ($scanned -lt 1GB -and -not $global:StopSI) {
            $mbi = New-Object SIMemSearch+MBI2
            $ret = [SIMemSearch]::VirtualQueryEx($handle,$addr,[ref]$mbi,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
            if ($ret -eq 0) { break }
            $size = $mbi.RegionSize.ToInt64()
            if ($size -le 0) { break }
            $isPrivate = $mbi.Type  -eq 0x20000
            $isCommit  = $mbi.State -eq 0x1000
            $readable  = ($mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x20 -or $mbi.Protect -eq 0x40)
            if ($isPrivate -and $isCommit -and $readable) {
                $buf = New-Object byte[] ([Math]::Min($size,8MB)); $read = 0
                if ([SIMemSearch]::ReadProcessMemory($handle,$mbi.Base,$buf,$buf.Length,[ref]$read) -and $read -gt 0) {
                    $str = [System.Text.Encoding]::UTF8.GetString($buf,0,$read)
                    foreach ($kw in $SI_KEYWORDS) {
                        if ($str.IndexOf($kw,[System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            if (-not $allHits[$kw]) { $allHits[$kw] = 0 }
                            $allHits[$kw]++
                        }
                    }
                }
                $scanned += $read
            }
            $next = $mbi.Base.ToInt64() + $size
            if ($next -ge 0x7FFFFFFFFFFF) { break }
            $addr = [IntPtr]::new($next)
        }
        [SIMemSearch]::CloseHandle($handle) | Out-Null

        Log $siLog "Scan complete - writing results..."
        Log $siLog ""

        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportLines = @(
            "="*60,
            "  SS TOOL - SYSTEM INFORMER DEEP SCAN",
            "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "  javaw.exe PID $($javaw.Id)",
            "="*60,""
        )
        $hitCount = 0
        foreach ($kw in $SI_KEYWORDS) {
            if ($allHits[$kw] -and $allHits[$kw] -gt 0) {
                $cnt = $allHits[$kw]
                Log $siLog "[CRIT] HIT: '$kw' -- $cnt region(s)"
                $siHitBox.Invoke([Action]{ $siHitBox.Items.Add("[CRIT] $kw  ($cnt regions)") | Out-Null })
                $reportLines += "  [HIT]  $kw  --  $cnt memory region(s)"
                $hitCount++
            } else {
                Log $siLog "  [OK] $kw"
                $reportLines += "  [OK]   $kw"
            }
        }
        $reportLines += @("","="*60,"  Total keywords hit: $hitCount / $($SI_KEYWORDS.Count)","="*60)
        $reportLines | Out-File "$out\si_scan_$stamp.txt" -Encoding UTF8
        Log $siLog ""
        Log $siLog "Report saved: $out\si_scan_$stamp.txt"
        Log $siLog ""
        Log $siLog "SI scan complete -- $hitCount keyword(s) hit out of $($SI_KEYWORDS.Count)"
        $siStatusVal.Invoke([Action]{ $siStatusVal.Text = "Done -- $hitCount hit(s) out of $($SI_KEYWORDS.Count) keywords" })
        Set-Status "SI scan done -- $hitCount hit(s)"
        $startSIBtn.Invoke([Action]{ $startSIBtn.Enabled = $true })
        $stopSIBtn.Invoke([Action]{ $stopSIBtn.Enabled = $false })
    })
    $t.IsBackground = $true; $t.Start()
})

# =====================================================================
Show-Page "Setup"
[System.Windows.Forms.Application]::Run($Form)
