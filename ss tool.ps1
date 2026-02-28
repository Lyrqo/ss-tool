if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -Command `"Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/Lyrqo/ss-tool/main/ss%20tool.ps1')`"" -Verb RunAs
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

$fBold  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fMono  = New-Object System.Drawing.Font("Consolas", 10)
$fHead  = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$fSub   = New-Object System.Drawing.Font("Segoe UI", 12)
$fTiny  = New-Object System.Drawing.Font("Consolas", 9)
$fBtn   = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$fLabel = New-Object System.Drawing.Font("Segoe UI", 10)

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
    "${env:ProgramFiles(x86)}\Process Hacker 2\ProcessHacker.exe"
)

$global:McFolder  = ""
$global:OutFolder = ""
$global:StopAll   = $false

function New-Lbl($txt,$x,$y,$w,$h,$fg,$bg,$font=$fLabel,$align="MiddleLeft") {
    $l = New-Object System.Windows.Forms.Label
    $l.Text=$txt; $l.Location=New-Object System.Drawing.Point($x,$y)
    $l.Size=New-Object System.Drawing.Size($w,$h)
    $l.ForeColor=$fg; $l.BackColor=$bg; $l.Font=$font
    $l.TextAlign=[System.Drawing.ContentAlignment]::$align
    return $l
}
function New-Btn($txt,$x,$y,$w,$h,$bg,$fg,$font=$fBtn) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text=$txt; $b.Location=New-Object System.Drawing.Point($x,$y)
    $b.Size=New-Object System.Drawing.Size($w,$h)
    $b.BackColor=$bg; $b.ForeColor=$fg; $b.FlatStyle="Flat"
    $b.FlatAppearance.BorderSize=0; $b.Font=$font; $b.Cursor="Hand"
    return $b
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
function Get-SHA1($fp) { return (Get-FileHash -Path $fp -Algorithm SHA1).Hash }
function Get-ZoneId($fp) {
    $ads = Get-Content -Raw -Stream Zone.Identifier $fp -ErrorAction SilentlyContinue
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
function Check-CheatStrings($fp) {
    $found = [System.Collections.Generic.HashSet[string]]::new()
    $content = Get-Content -Raw $fp -ErrorAction SilentlyContinue
    if (-not $content) { return $found }
    foreach ($s in $cheatStrings) { if ($content -match $s) { $found.Add($s) | Out-Null } }
    return $found
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "SS Tool  //  MC Cheat Scanner"
$Form.Size = New-Object System.Drawing.Size(1100,750)
$Form.MinimumSize = New-Object System.Drawing.Size(1100,750)
$Form.BackColor = $cBG
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
$adminTxt   = if ($isAdmin) { "  ADMIN" } else { "  NOT ADMIN" }
$adminColor = if ($isAdmin) { $cGREEN } else { $cRED }

$Header = New-Object System.Windows.Forms.Panel
$Header.Dock = "Top"; $Header.Height = 70; $Header.BackColor = $cBG2
$Header.Controls.Add((New-Lbl "SS TOOL" 24 10 400 50 $cACCENT $cBG2 $fHead))
$Header.Controls.Add((New-Lbl "MC Cheat Scanner" 24 46 400 22 $cDIM $cBG2 $fTiny))
$Header.Controls.Add((New-Lbl $adminTxt 900 24 180 24 $adminColor $cBG2 $fBold "MiddleRight"))
$Form.Controls.Add($Header)

$AccentLine = New-Object System.Windows.Forms.Panel
$AccentLine.Dock = "Top"; $AccentLine.Height = 3; $AccentLine.BackColor = $cACCENT
$Form.Controls.Add($AccentLine)

$Pages = @{}
$Container = New-Object System.Windows.Forms.Panel
$Container.Dock = "Fill"; $Container.BackColor = $cBG
$Form.Controls.Add($Container)

$StatusBar = New-Object System.Windows.Forms.Panel
$StatusBar.Dock = "Bottom"; $StatusBar.Height = 28; $StatusBar.BackColor = $cBG2
$StatusLbl = New-Lbl "Ready" 12 5 900 20 $cDIM $cBG2 $fTiny
$StatusBar.Controls.Add($StatusLbl)
$Form.Controls.Add($StatusBar)

function Set-Status($msg) {
    if ($StatusLbl.InvokeRequired) { $StatusLbl.Invoke([Action]{ $StatusLbl.Text = $msg }) }
    else { $StatusLbl.Text = $msg }
}

foreach ($name in @("Mods","Output","Scan")) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = "Fill"; $p.BackColor = $cBG; $p.Visible = $false
    $Container.Controls.Add($p)
    $Pages[$name] = $p
}

function Show-Page($name) {
    foreach ($p in $Pages.Values) { $p.Visible = $false }
    $Pages[$name].Visible = $true
}

$pMods   = $Pages["Mods"]
$pOutput = $Pages["Output"]
$pScan   = $Pages["Scan"]

function New-StepDots($parent,$active) {
    $dots = New-Object System.Windows.Forms.Panel
    $dots.Size = New-Object System.Drawing.Size(120,16)
    $dots.Location = New-Object System.Drawing.Point(490,580)
    $dots.BackColor = $cBG
    for ($i = 1; $i -le 3; $i++) {
        $d = New-Object System.Windows.Forms.Panel
        $d.Size = New-Object System.Drawing.Size(28,8)
        $d.Location = New-Object System.Drawing.Point((($i-1)*38),4)
        $d.BackColor = if ($i -eq $active) { $cACCENT } else { $cBG3 }
        $dots.Controls.Add($d)
    }
    $parent.Controls.Add($dots)
}

function MakeFolderPage($page,$title,$subtitle,$defaultPath,$active) {
    $page.Controls.Add((New-Lbl $title 80 100 940 54 $cACCENT $cBG $fHead "MiddleCenter"))
    $page.Controls.Add((New-Lbl $subtitle 80 158 940 30 $cDIM $cBG $fSub "MiddleCenter"))

    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Location = New-Object System.Drawing.Point(80,230)
    $pathBox.Size = New-Object System.Drawing.Size(720,40)
    $pathBox.BackColor = $cBG3; $pathBox.ForeColor = $cTEXT
    $pathBox.BorderStyle = "None"; $pathBox.Font = $fMono
    $pathBox.Text = $defaultPath
    $page.Controls.Add($pathBox)

    $browseBtn = New-Btn "Browse" 814 228 180 44 $cACCENT $cBG $fBold
    $page.Controls.Add($browseBtn)

    $errLbl = New-Lbl "" 80 282 940 26 $cRED $cBG $fTiny "MiddleCenter"
    $page.Controls.Add($errLbl)

    New-StepDots $page $active

    return $pathBox,$browseBtn,$errLbl
}

$mcPathBox,$mcBrowse,$mcErr = MakeFolderPage $pMods "Select Mods Folder" "Choose the folder where your Minecraft mods are stored." "$env:USERPROFILE\AppData\Roaming\.minecraft\mods" 1
$mcBrowse.Add_Click({
    $p = Browse-Folder "Select Minecraft mods folder"
    if ($p) { $mcPathBox.Text = $p }
})

$pMods.Controls.Add((New-Lbl "The scanner will check all .jar files inside this folder against Modrinth, Megabase and cheat string databases." 80 316 940 22 $cDIM $cBG $fTiny "MiddleCenter"))

$mcNextBtn = New-Btn "Next  >" 820 500 180 54 $cGREEN $cBG
$pMods.Controls.Add($mcNextBtn)
$mcNextBtn.Add_Click({
    $p = $mcPathBox.Text.Trim()
    if (-not $p -or -not (Test-Path $p -PathType Container)) {
        $mcErr.Text = "  Invalid path — please browse and select a valid folder."
        return
    }
    $global:McFolder = $p
    $mcErr.Text = ""
    Show-Page "Output"
})

$outPathBox,$outBrowse,$outErr = MakeFolderPage $pOutput "Select Output Folder" "Scan reports will be saved here when the scan finishes." "$env:USERPROFILE\Desktop" 2
$outBrowse.Add_Click({
    $p = Browse-Folder "Select output folder for reports"
    if ($p) { $outPathBox.Text = $p }
})

$pOutput.Controls.Add((New-Lbl "Reports are saved as .txt files with a date/time stamp." 80 316 940 22 $cDIM $cBG $fTiny "MiddleCenter"))

$outBackBtn = New-Btn "< Back" 80 500 160 54 $cBG3 $cDIM
$pOutput.Controls.Add($outBackBtn)
$outBackBtn.Add_Click({ Show-Page "Mods" })

$outNextBtn = New-Btn "Next  >" 820 500 180 54 $cGREEN $cBG
$pOutput.Controls.Add($outNextBtn)
$outNextBtn.Add_Click({
    $p = $outPathBox.Text.Trim()
    if (-not $p -or -not (Test-Path $p -PathType Container)) {
        $outErr.Text = "  Invalid path — please browse and select a valid folder."
        return
    }
    $global:OutFolder = $p
    $outErr.Text = ""
    Show-Page "Scan"
})

$scanTopBar = New-Object System.Windows.Forms.Panel
$scanTopBar.Dock = "Top"; $scanTopBar.Height = 72; $scanTopBar.BackColor = $cBG2
$pScan.Controls.Add($scanTopBar)

$runBtn = New-Btn ">  RUN ALL SCANS" 12 12 260 50 $cGREEN $cBG
$scanTopBar.Controls.Add($runBtn)

$stopBtn2 = New-Btn "STOP" 12 12 260 50 $cRED $cWHITE
$stopBtn2.Visible = $false; $stopBtn2.Enabled = $false
$scanTopBar.Controls.Add($stopBtn2)
$stopBtn2.Add_Click({ $global:StopAll = $true })

$backBtn = New-Btn "< Back" 284 12 140 50 $cBG3 $cDIM $fBold
$scanTopBar.Controls.Add($backBtn)
$backBtn.Add_Click({ Show-Page "Output" })

$progBar = New-Object System.Windows.Forms.ProgressBar
$progBar.Dock = "Top"; $progBar.Height = 8
$progBar.Style = "Continuous"; $progBar.ForeColor = $cACCENT; $progBar.BackColor = $cBG2
$pScan.Controls.Add($progBar)

function Set-Prog($val) {
    if ($progBar.InvokeRequired) { $progBar.Invoke([Action]{ $progBar.Value = [Math]::Min($val,100) }) }
    else { $progBar.Value = [Math]::Min($val,100) }
}

$scanSplit = New-Object System.Windows.Forms.SplitContainer
$scanSplit.Dock = "Fill"; $scanSplit.SplitterDistance = 420
$scanSplit.BackColor = $cBORDER
$scanSplit.Panel1.BackColor = $cBG
$scanSplit.Panel2.BackColor = $cBG
$pScan.Controls.Add($scanSplit)

$scanSplit.Panel1.Controls.Add((New-Lbl "  RESULTS" 0 0 420 28 $cACCENT $cBG2 $fBold))

$leftScroll = New-Object System.Windows.Forms.Panel
$leftScroll.Location = New-Object System.Drawing.Point(0,30)
$leftScroll.Size = New-Object System.Drawing.Size(418,560)
$leftScroll.BackColor = $cBG
$leftScroll.AutoScroll = $true
$scanSplit.Panel1.Controls.Add($leftScroll)

function New-ResPanel($title,$color,$top) {
    $outer = New-Object System.Windows.Forms.Panel
    $outer.Location = New-Object System.Drawing.Point(6,$top)
    $outer.Size = New-Object System.Drawing.Size(400,150)
    $outer.BackColor = $cBG2

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Dock = "Top"; $hdr.Height = 32; $hdr.BackColor = $color

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "  $title"; $lbl.Dock = "Fill"
    $lbl.ForeColor = $cBG; $lbl.Font = $fBold
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $hdr.Controls.Add($lbl)
    $outer.Controls.Add($hdr)

    $box = New-Object System.Windows.Forms.ListBox
    $box.Location = New-Object System.Drawing.Point(0,32)
    $box.Size = New-Object System.Drawing.Size(400,118)
    $box.BackColor = $cBG2; $box.ForeColor = $cTEXT
    $box.BorderStyle = "None"; $box.Font = $fTiny
    $outer.Controls.Add($box)

    return $outer,$box
}

$ty = 6
$modPanel,$modBox = New-ResPanel "MOD ANALYZER"  $cGREEN  $ty; $ty += 158
$memPanel,$memBox = New-ResPanel "MEMORY SCAN"   $cACCENT $ty; $ty += 158
$sysPanel,$sysBox = New-ResPanel "SYS INFO"      $cORANGE $ty; $ty += 158
$siPanel,$siBox   = New-ResPanel "SI DEEP SCAN"  $cRED    $ty; $ty += 158
$leftScroll.Controls.AddRange(@($modPanel,$memPanel,$sysPanel,$siPanel))

$sumPanel = New-Object System.Windows.Forms.Panel
$sumPanel.Location = New-Object System.Drawing.Point(6,$ty)
$sumPanel.Size = New-Object System.Drawing.Size(400,58)
$sumPanel.BackColor = $cBG3
$okLbl    = New-Lbl "OK: --"    10  6  100 20 $cGREEN  $cBG3 $fBold
$unkLbl   = New-Lbl "UNK: --"  115  6  110 20 $cORANGE $cBG3 $fBold
$cheatLbl = New-Lbl "CHEAT: --" 230  6  160 20 $cRED    $cBG3 $fBold
$memLbl   = New-Lbl "MEM: --"   10 30  110 20 $cACCENT $cBG3 $fBold
$siLbl    = New-Lbl "SI: --"   130 30  110 20 $cRED    $cBG3 $fBold
$sumPanel.Controls.AddRange(@($okLbl,$unkLbl,$cheatLbl,$memLbl,$siLbl))
$leftScroll.Controls.Add($sumPanel)

$scanSplit.Panel2.Controls.Add((New-Lbl "  LIVE LOG" 0 0 660 28 $cACCENT $cBG2 $fBold))
$liveLog = New-Object System.Windows.Forms.TextBox
$liveLog.Location = New-Object System.Drawing.Point(0,30)
$liveLog.Anchor = "Top,Bottom,Left,Right"
$liveLog.Size = New-Object System.Drawing.Size(660,560)
$liveLog.BackColor = $cBG; $liveLog.ForeColor = $cTEXT
$liveLog.BorderStyle = "None"; $liveLog.Font = $fTiny
$liveLog.Multiline = $true; $liveLog.ScrollBars = "Vertical"
$liveLog.ReadOnly = $true; $liveLog.WordWrap = $true
$scanSplit.Panel2.Controls.Add($liveLog)

$runBtn.Add_Click({
    $mc  = $global:McFolder
    $out = $global:OutFolder
    if (-not (Test-Path $mc)) { Log $liveLog "[ERROR] Mods folder not found."; return }

    $global:StopAll = $false
    $modBox.Items.Clear(); $memBox.Items.Clear()
    $sysBox.Items.Clear(); $siBox.Items.Clear()
    $liveLog.Clear(); $progBar.Value = 0
    $okLbl.Text = "OK: --"; $unkLbl.Text = "UNK: --"
    $cheatLbl.Text = "CHEAT: --"; $memLbl.Text = "MEM: --"; $siLbl.Text = "SI: --"

    $runBtn.Visible = $false
    $stopBtn2.Visible = $true; $stopBtn2.Enabled = $true
    $backBtn.Enabled = $false
    Set-Status "Running all scans..."

    $t = [System.Threading.Thread]::new({
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        Log $liveLog "SS TOOL FULL SCAN"
        Log $liveLog "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $env:COMPUTERNAME / $env:USERNAME"
        Log $liveLog "Mods: $mc"
        Log $liveLog ""

        Log $liveLog "=== MOD ANALYZER ==="
        Set-Status "Scanning mods..."; Set-Prog 5

        $jarFiles = Get-ChildItem -Path $mc -Filter "*.jar" -ErrorAction SilentlyContinue
        $total = $jarFiles.Count
        $verOK = 0; $verUNK = 0; $verCHEAT = 0; $reportMods = @()

        if ($total -eq 0) {
            Log $liveLog "[WARN] No .jar files found."
            $modBox.Invoke([Action]{ $modBox.Items.Add("No jars found") | Out-Null })
        } else {
            Log $liveLog "Found $total jar(s)"
            $counter = 0
            foreach ($file in $jarFiles) {
                if ($global:StopAll) { Log $liveLog "-- Stopped --"; break }
                $counter++
                Set-Prog ([int](($counter/$total)*28)+5)
                Log $liveLog "[$counter/$total] $($file.Name)"
                $hash = Get-SHA1 $file.FullName

                $mr = Fetch-Modrinth $hash
                if ($mr.Slug) {
                    Log $liveLog "  [OK] $($mr.Name)"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[OK] $($file.Name)") | Out-Null })
                    $verOK++; $reportMods += "[OK]    $($mr.Name)  --  $($file.Name)"; continue
                }
                $mb = Fetch-Megabase $hash
                if ($mb -and $mb.name) {
                    Log $liveLog "  [OK] $($mb.name)"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[OK] $($file.Name)") | Out-Null })
                    $verOK++; $reportMods += "[OK]    $($mb.name)  --  $($file.Name)"; continue
                }
                $strings = Check-CheatStrings $file.FullName
                if ($strings.Count -gt 0) {
                    $joined = ($strings -join ", ")
                    Log $liveLog "  [CHEAT] $joined"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[CHEAT] $($file.Name)") | Out-Null })
                    $verCHEAT++; $reportMods += "[CHEAT] $($file.Name)  --  $joined"; continue
                }
                $tempEx = $null; $foundInDep = $false
                try {
                    $tempEx = Join-Path $env:TEMP ("hab_" + [System.IO.Path]::GetRandomFileName())
                    New-Item -ItemType Directory -Path $tempEx | Out-Null
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($file.FullName,$tempEx)
                    $depPath = Join-Path $tempEx "META-INF\jars"
                    if (Test-Path $depPath) {
                        foreach ($dep in (Get-ChildItem $depPath -Filter "*.jar")) {
                            $ds = Check-CheatStrings $dep.FullName
                            if ($ds.Count -gt 0) {
                                $joined = ($ds -join ", ")
                                Log $liveLog "  [CHEAT] dep $($dep.Name): $joined"
                                $modBox.Invoke([Action]{ $modBox.Items.Add("[CHEAT] $($file.Name) > $($dep.Name)") | Out-Null })
                                $verCHEAT++; $reportMods += "[CHEAT] $($file.Name) > $($dep.Name)  --  $joined"
                                $foundInDep = $true
                            }
                        }
                    }
                } catch {} finally {
                    if ($tempEx -and (Test-Path $tempEx)) { Remove-Item -Recurse -Force $tempEx -ErrorAction SilentlyContinue }
                }
                if (-not $foundInDep) {
                    $zone = Get-ZoneId $file.FullName
                    $zStr = if ($zone) { "from: $zone" } else { "no source" }
                    Log $liveLog "  [UNK] $zStr"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[UNK] $($file.Name)") | Out-Null })
                    $verUNK++; $reportMods += "[UNK]   $($file.Name)  --  $zStr"
                }
            }
        }
        $ok_=$verOK; $unk_=$verUNK; $ch_=$verCHEAT
        $okLbl.Invoke([Action]{ $okLbl.Text = "OK: $ok_" })
        $unkLbl.Invoke([Action]{ $unkLbl.Text = "UNK: $unk_" })
        $cheatLbl.Invoke([Action]{ $cheatLbl.Text = "CHEAT: $ch_" })
        Log $liveLog "Mods done  OK:$verOK  UNK:$verUNK  CHEAT:$verCHEAT"
        Log $liveLog ""; Set-Prog 35

        if (-not $global:StopAll) {
            Log $liveLog "=== MEMORY SCAN ==="
            Set-Status "Scanning memory..."
            Add-Type @"
using System; using System.Runtime.InteropServices;
public class MemReader2 {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a,bool b,int c);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int s,out int r);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h,IntPtr a,out MBI3 m,uint s);
    [StructLayout(LayoutKind.Sequential)] public struct MBI3 {
        public IntPtr Base,AllocBase; public uint AllocProtect;
        public IntPtr RegionSize; public uint State,Protect,Type;
    }
}
"@ -ErrorAction SilentlyContinue
            $javaws = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
            if (-not $javaws) { $javaws = Get-Process -Name "java" -ErrorAction SilentlyContinue }
            $totalMemHits = 0
            if (-not $javaws) {
                Log $liveLog "[WARN] Minecraft not running"
                $memBox.Invoke([Action]{ $memBox.Items.Add("Minecraft not running") | Out-Null })
                $memLbl.Invoke([Action]{ $memLbl.Text = "MEM: N/A" })
            } else {
                foreach ($proc in $javaws) {
                    if ($global:StopAll) { break }
                    Log $liveLog "Scanning PID $($proc.Id)..."
                    $handle = [MemReader2]::OpenProcess(0x0410,$false,$proc.Id)
                    if ($handle -eq [IntPtr]::Zero) { Log $liveLog "[WARN] Cannot open PID $($proc.Id)"; continue }
                    $addr = [IntPtr]::Zero; $hits = @{}; $scanned = 0
                    while ($scanned -lt 512MB -and -not $global:StopAll) {
                        $mbi = New-Object MemReader2+MBI3
                        $ret = [MemReader2]::VirtualQueryEx($handle,$addr,[ref]$mbi,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
                        if ($ret -eq 0) { break }
                        $size = $mbi.RegionSize.ToInt64(); if ($size -le 0) { break }
                        $readable = ($mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x20 -or $mbi.Protect -eq 0x40)
                        if ($mbi.State -eq 0x1000 -and $readable) {
                            $buf = New-Object byte[] ([Math]::Min($size,4MB)); $read = 0
                            if ([MemReader2]::ReadProcessMemory($handle,$mbi.Base,$buf,$buf.Length,[ref]$read) -and $read -gt 0) {
                                $str = [System.Text.Encoding]::UTF8.GetString($buf,0,$read)
                                foreach ($sig in $MEM_SIGS) {
                                    if (-not $hits[$sig] -and $str.Contains($sig)) {
                                        $hits[$sig] = $true
                                        Log $liveLog "  [HIT] $sig"
                                        $memBox.Invoke([Action]{ $memBox.Items.Add("[HIT] $sig") | Out-Null })
                                        $totalMemHits++
                                    }
                                }
                            }
                            $scanned += $read
                        }
                        $next = $mbi.Base.ToInt64() + $size
                        if ($next -ge 0x7FFFFFFFFFFF) { break }
                        $addr = [IntPtr]::new($next)
                    }
                    [MemReader2]::CloseHandle($handle) | Out-Null
                    if ($hits.Count -eq 0) {
                        Log $liveLog "  [OK] PID $($proc.Id) clean"
                        $memBox.Invoke([Action]{ $memBox.Items.Add("[OK] PID $($proc.Id) clean") | Out-Null })
                    }
                }
                $mh = $totalMemHits
                $memLbl.Invoke([Action]{ $memLbl.Text = "MEM: $mh hit(s)" })
            }
            Log $liveLog "Memory done  $totalMemHits hit(s)"
            Log $liveLog ""; Set-Prog 60
        }

        if (-not $global:StopAll) {
            Log $liveLog "=== SYS INFO ==="
            Set-Status "Gathering sys info..."
            $jw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $jw) { $jw = Get-Process -Name "java" -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if ($jw) {
                $el = (Get-Date) - $jw.StartTime
                $ups = "$($el.Hours)h $($el.Minutes)m $($el.Seconds)s"
                Log $liveLog "  Uptime: $ups (since $($jw.StartTime.ToString('HH:mm:ss'))) PID $($jw.Id)"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("Uptime: $ups since $($jw.StartTime.ToString('HH:mm:ss'))") | Out-Null })
            } else {
                Log $liveLog "  MC not running"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("MC not running") | Out-Null })
            }
            try {
                $mb2  = (Get-WmiObject win32_baseboard).Manufacturer + " " + (Get-WmiObject win32_baseboard).SerialNumber
                $cpu2 = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
                $dsk  = (Get-PhysicalDisk | Select-Object -First 1).SerialNumber
                $hwid = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$mb2|$cpu2|$dsk")).Replace("=","")
                Log $liveLog "  HWID: $hwid"
                $hw = $hwid.Substring(0,[Math]::Min(38,$hwid.Length)) + "..."
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("HWID: $hw") | Out-Null })
            } catch {
                Log $liveLog "  HWID error: $_"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("HWID: error") | Out-Null })
            }
            Log $liveLog "Sys info done"
            Log $liveLog ""; Set-Prog 75
        }

        if (-not $global:StopAll) {
            Log $liveLog "=== SI DEEP SCAN ==="
            Set-Status "SI deep scan..."
            $siExe = $SI_PATHS | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $siExe) {
                Log $liveLog "[WARN] System Informer not installed - skipping"
                Log $liveLog "       Get it: systeminformer.sourceforge.io"
                $siBox.Invoke([Action]{ $siBox.Items.Add("System Informer not found") | Out-Null })
                $siLbl.Invoke([Action]{ $siLbl.Text = "SI: N/A" })
            } else {
                $siProc = Get-Process -Name "SystemInformer","ProcessHacker" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $siProc) { Start-Process $siExe; Start-Sleep 3 }
                $javaw2 = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $javaw2) {
                    Log $liveLog "[WARN] Minecraft not running - skipping SI"
                    $siBox.Invoke([Action]{ $siBox.Items.Add("MC not running") | Out-Null })
                    $siLbl.Invoke([Action]{ $siLbl.Text = "SI: N/A" })
                } else {
                    Add-Type @"
using System; using System.Runtime.InteropServices;
public class SIMem2 {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a,bool b,int c);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int s,out int r);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h,IntPtr a,out MBI4 m,uint s);
    [StructLayout(LayoutKind.Sequential)] public struct MBI4 {
        public IntPtr Base,AllocBase; public uint AllocProtect;
        public IntPtr RegionSize; public uint State,Protect,Type;
    }
}
"@ -ErrorAction SilentlyContinue
                    $handle2 = [SIMem2]::OpenProcess(0x0410,$false,$javaw2.Id)
                    $allHits2 = @{}; $addr2 = [IntPtr]::Zero; $scanned2 = 0
                    if ($handle2 -eq [IntPtr]::Zero) {
                        Log $liveLog "[ERROR] Cannot open javaw - run as admin"
                    } else {
                        while ($scanned2 -lt 1GB -and -not $global:StopAll) {
                            $mbi2 = New-Object SIMem2+MBI4
                            $ret2 = [SIMem2]::VirtualQueryEx($handle2,$addr2,[ref]$mbi2,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi2))
                            if ($ret2 -eq 0) { break }
                            $size2 = $mbi2.RegionSize.ToInt64(); if ($size2 -le 0) { break }
                            $priv2 = $mbi2.Type -eq 0x20000; $comm2 = $mbi2.State -eq 0x1000
                            $read2 = ($mbi2.Protect -eq 0x02 -or $mbi2.Protect -eq 0x04 -or $mbi2.Protect -eq 0x20 -or $mbi2.Protect -eq 0x40)
                            if ($priv2 -and $comm2 -and $read2) {
                                $buf2 = New-Object byte[] ([Math]::Min($size2,8MB)); $rb2 = 0
                                if ([SIMem2]::ReadProcessMemory($handle2,$mbi2.Base,$buf2,$buf2.Length,[ref]$rb2) -and $rb2 -gt 0) {
                                    $str2 = [System.Text.Encoding]::UTF8.GetString($buf2,0,$rb2)
                                    foreach ($kw in $SI_KEYWORDS) {
                                        if ($str2.IndexOf($kw,[System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                                            if (-not $allHits2[$kw]) { $allHits2[$kw] = 0 }
                                            $allHits2[$kw]++
                                        }
                                    }
                                }
                                $scanned2 += $rb2
                            }
                            $next2 = $mbi2.Base.ToInt64() + $size2
                            if ($next2 -ge 0x7FFFFFFFFFFF) { break }
                            $addr2 = [IntPtr]::new($next2)
                        }
                        [SIMem2]::CloseHandle($handle2) | Out-Null
                    }
                    $siHitCount = 0
                    foreach ($kw in $SI_KEYWORDS) {
                        if ($allHits2[$kw] -and $allHits2[$kw] -gt 0) {
                            Log $liveLog "  [HIT] $kw ($($allHits2[$kw]) regions)"
                            $siBox.Invoke([Action]{ $siBox.Items.Add("[HIT] $kw") | Out-Null })
                            $siHitCount++
                        }
                    }
                    if ($siHitCount -eq 0) {
                        Log $liveLog "  [OK] No hits"
                        $siBox.Invoke([Action]{ $siBox.Items.Add("[OK] No hits") | Out-Null })
                    }
                    $sh = $siHitCount
                    $siLbl.Invoke([Action]{ $siLbl.Text = "SI: $sh hit(s)" })
                }
            }
            Log $liveLog "SI done"; Log $liveLog ""; Set-Prog 90
        }

        if (-not $global:StopAll) {
            Log $liveLog "Writing report..."
            $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $lines = @("="*60,"  SS TOOL FULL SCAN REPORT","  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')","  $env:COMPUTERNAME / $env:USERNAME","  Mods: $mc","="*60,"","--- MOD ANALYZER ---")
            foreach ($r in $reportMods) { $lines += "  $r" }
            $lines | Out-File "$out\fullscan_$stamp.txt" -Encoding UTF8
            Log $liveLog "Report saved: $out\fullscan_$stamp.txt"
        }

        Set-Prog 100
        Set-Status "All scans complete"
        Log $liveLog ""; Log $liveLog "ALL SCANS COMPLETE"

        $runBtn.Invoke([Action]{ $runBtn.Visible = $true })
        $stopBtn2.Invoke([Action]{ $stopBtn2.Visible = $false; $stopBtn2.Enabled = $false })
        $backBtn.Invoke([Action]{ $backBtn.Enabled = $true })
    })
    $t.IsBackground = $true; $t.Start()
})

Show-Page "Mods"
[System.Windows.Forms.Application]::Run($Form)
