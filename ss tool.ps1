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
$fBig  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)

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

$global:StopAll = $false

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
function New-Tbox($x,$y,$w,$h) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location=New-Object System.Drawing.Point($x,$y)
    $t.Size=New-Object System.Drawing.Size($w,$h)
    $t.BackColor=$cBG3; $t.ForeColor=$cTEXT; $t.BorderStyle="None"; $t.Font=$fMono
    return $t
}
function Log($box,$txt,$color=$null) {
    if ($box.InvokeRequired) {
        $box.Invoke([Action]{ $box.AppendText("$txt`r`n"); $box.ScrollToCaret() })
    } else {
        $box.AppendText("$txt`r`n"); $box.ScrollToCaret()
    }
}
function Browse-Folder($title) {
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.BrowseForFolder(0,$title,0,0)
    if ($folder) { return $folder.Self.Path } else { return $null }
}
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

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "SS Tool  //  MC Cheat Scanner"
$Form.Size = New-Object System.Drawing.Size(1100,820)
$Form.MinimumSize = New-Object System.Drawing.Size(960,700)
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

$mc  = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
$out = "$env:USERPROFILE\Desktop"

$CtrlBar = New-Object System.Windows.Forms.Panel
$CtrlBar.Dock = "Top"; $CtrlBar.Height = 56; $CtrlBar.BackColor = $cBG2
$Form.Controls.Add($CtrlBar)

$CtrlBar.Controls.Add((New-Lbl "Mods: $mc" 12 8 800 18 $cDIM $cBG2 $fTiny))
$CtrlBar.Controls.Add((New-Lbl "Report saved to: $out" 12 26 800 18 $cDIM $cBG2 $fTiny))

$StartBtn = New-Btn "> RUN ALL SCANS" 820 8 240 18 $cGREEN $cBG
$StartBtn.Size = New-Object System.Drawing.Size(240,18)
$StartBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$StartBtn.Size = New-Object System.Drawing.Size(240,36)
$StartBtn.Location = New-Object System.Drawing.Point(820,8)
$CtrlBar.Controls.Add($StartBtn)

$StopBtn = New-Btn "STOP" 820 8 240 36 $cRED $cWHITE
$StopBtn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$StopBtn.Location = New-Object System.Drawing.Point(820,8)
$StopBtn.Enabled = $false
$StopBtn.Visible = $false
$CtrlBar.Controls.Add($StopBtn)
$StopBtn.Add_Click({ $global:StopAll = $true })

$CtrlLine = New-Object System.Windows.Forms.Panel
$CtrlLine.Dock = "Top"; $CtrlLine.Height = 1; $CtrlLine.BackColor = $cBORDER
$Form.Controls.Add($CtrlLine)

$ProgBar = New-Object System.Windows.Forms.ProgressBar
$ProgBar.Dock = "Top"; $ProgBar.Height = 6
$ProgBar.Style = "Continuous"; $ProgBar.ForeColor = $cACCENT; $ProgBar.BackColor = $cBG2
$Form.Controls.Add($ProgBar)

$StatusBar = New-Object System.Windows.Forms.Panel
$StatusBar.Dock = "Bottom"; $StatusBar.Height = 24; $StatusBar.BackColor = $cBG2
$StatusLbl = New-Lbl "Ready -- set your paths above and click RUN ALL SCANS" 10 4 1060 18 $cDIM $cBG2 $fTiny
$StatusBar.Controls.Add($StatusLbl)
$Form.Controls.Add($StatusBar)

function Set-Status($msg) {
    if ($StatusLbl.InvokeRequired) { $StatusLbl.Invoke([Action]{ $StatusLbl.Text = $msg }) }
    else { $StatusLbl.Text = $msg }
}
function Set-Prog($val) {
    if ($ProgBar.InvokeRequired) { $ProgBar.Invoke([Action]{ $ProgBar.Value = [Math]::Min($val,100) }) }
    else { $ProgBar.Value = [Math]::Min($val,100) }
}

$MainSplit = New-Object System.Windows.Forms.SplitContainer
$MainSplit.Dock = "Fill"; $MainSplit.SplitterDistance = 440
$MainSplit.BackColor = $cBORDER
$MainSplit.Panel1.BackColor = $cBG
$MainSplit.Panel2.BackColor = $cBG
$Form.Controls.Add($MainSplit)

$MainSplit.Panel2.Controls.Add((New-Lbl "LIVE LOG" 10 8 200 18 $cDIM $cBG $fTiny))
$LiveLog = New-Object System.Windows.Forms.TextBox
$LiveLog.Location = New-Object System.Drawing.Point(6,28)
$LiveLog.Dock = "Fill"
$LiveLog.BackColor = $cBG; $LiveLog.ForeColor = $cTEXT
$LiveLog.BorderStyle = "None"; $LiveLog.Font = $fMono
$LiveLog.Multiline = $true; $LiveLog.ScrollBars = "Vertical"
$LiveLog.ReadOnly = $true; $LiveLog.WordWrap = $true
$MainSplit.Panel2.Controls.Add($LiveLog)

$LeftScroll = New-Object System.Windows.Forms.Panel
$LeftScroll.Dock = "Fill"; $LeftScroll.BackColor = $cBG
$LeftScroll.AutoScroll = $true
$MainSplit.Panel1.Controls.Add($LeftScroll)

function New-ResultPanel($title,$color,$top) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point(8,$top)
    $p.Size = New-Object System.Drawing.Size(410,160)
    $p.BackColor = $cBG2

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Dock = "Top"; $hdr.Height = 28; $hdr.BackColor = $color
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $title; $lbl.Dock = "Fill"
    $lbl.ForeColor = $cBG; $lbl.Font = $fBold
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $lbl.Padding = New-Object System.Windows.Forms.Padding(8,0,0,0)
    $hdr.Controls.Add($lbl)
    $p.Controls.Add($hdr)

    $box = New-Object System.Windows.Forms.ListBox
    $box.Location = New-Object System.Drawing.Point(0,28)
    $box.Size = New-Object System.Drawing.Size(410,132)
    $box.BackColor = $cBG2; $box.ForeColor = $cTEXT
    $box.BorderStyle = "None"; $box.Font = $fMono
    $p.Controls.Add($box)

    return $p,$box
}

$topY = 8
$modPanel,$modBox    = New-ResultPanel "MOD ANALYZER" $cGREEN $topY;   $topY += 168
$memPanel,$memBox    = New-ResultPanel "MEMORY SCAN"  $cACCENT $topY; $topY += 168
$sysPanel,$sysBox    = New-ResultPanel "SYS INFO"     $cORANGE $topY; $topY += 168
$siPanel,$siBox      = New-ResultPanel "SI DEEP SCAN" $cRED $topY;    $topY += 168

$LeftScroll.Controls.AddRange(@($modPanel,$memPanel,$sysPanel,$siPanel))

$SummaryPanel = New-Object System.Windows.Forms.Panel
$SummaryPanel.Location = New-Object System.Drawing.Point(8,$topY)
$SummaryPanel.Size = New-Object System.Drawing.Size(410,60)
$SummaryPanel.BackColor = $cBG3
$okLbl    = New-Lbl "OK: --"    8  8  120 20 $cGREEN  $cBG3 $fBold
$unkLbl   = New-Lbl "UNK: --"  130  8  120 20 $cORANGE $cBG3 $fBold
$cheatLbl = New-Lbl "CHEAT: --" 252  8  150 20 $cRED    $cBG3 $fBold
$memLbl   = New-Lbl "MEM: --"    8 32  120 20 $cACCENT $cBG3 $fBold
$siLbl    = New-Lbl "SI: --"   130 32  120 20 $cRED    $cBG3 $fBold
$SummaryPanel.Controls.AddRange(@($okLbl,$unkLbl,$cheatLbl,$memLbl,$siLbl))
$LeftScroll.Controls.Add($SummaryPanel)

$StartBtn.Add_Click({
    if (-not (Test-Path $mc)) {
        Log $LiveLog "[ERROR] Mods folder not found: $mc"; return
    }

    $global:StopAll = $false
    $modBox.Items.Clear(); $memBox.Items.Clear()
    $sysBox.Items.Clear(); $siBox.Items.Clear()
    $LiveLog.Clear(); $ProgBar.Value = 0
    $okLbl.Text = "OK: --"; $unkLbl.Text = "UNK: --"
    $cheatLbl.Text = "CHEAT: --"; $memLbl.Text = "MEM: --"; $siLbl.Text = "SI: --"

    $StartBtn.Visible = $false; $StopBtn.Visible = $true; $StopBtn.Enabled = $true
    Set-Status "Running all scans..."

    $t = [System.Threading.Thread]::new({
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        Log $LiveLog "============================================"
        Log $LiveLog "  SS TOOL  --  FULL SCAN"
        Log $LiveLog "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Log $LiveLog "  $env:COMPUTERNAME / $env:USERNAME"
        Log $LiveLog "============================================"
        Log $LiveLog ""

        Log $LiveLog "--- MOD ANALYZER ---"
        Set-Status "Running mod analyzer..."
        Set-Prog 5

        $jarFiles = Get-ChildItem -Path $mc -Filter "*.jar" -ErrorAction SilentlyContinue
        $total = $jarFiles.Count
        $verOK = 0; $verUNK = 0; $verCHEAT = 0
        $reportMods = @()

        if ($total -eq 0) {
            Log $LiveLog "[WARN] No .jar files found in mods folder."
            $modBox.Invoke([Action]{ $modBox.Items.Add("No jars found") | Out-Null })
        } else {
            Log $LiveLog "Found $total jar(s)"
            $counter = 0
            foreach ($file in $jarFiles) {
                if ($global:StopAll) { Log $LiveLog "-- Stopped --"; break }
                $counter++
                $pct = [int](($counter / $total) * 28) + 5
                Set-Prog $pct
                Log $LiveLog "[$counter/$total] $($file.Name)"

                $hash = Get-SHA1 $file.FullName

                $mr = Fetch-Modrinth $hash
                if ($mr.Slug) {
                    Log $LiveLog "  [OK] $($mr.Name)"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[OK] $($file.Name)") | Out-Null })
                    $verOK++; $reportMods += "[OK]    $($mr.Name)  --  $($file.Name)"
                    continue
                }

                $mb = Fetch-Megabase $hash
                if ($mb -and $mb.name) {
                    Log $LiveLog "  [OK] $($mb.name)"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[OK] $($file.Name)") | Out-Null })
                    $verOK++; $reportMods += "[OK]    $($mb.name)  --  $($file.Name)"
                    continue
                }

                $strings = Check-CheatStrings $file.FullName
                if ($strings.Count -gt 0) {
                    $joined = ($strings -join ", ")
                    Log $LiveLog "  [CHEAT] $joined"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[CHEAT] $($file.Name)") | Out-Null })
                    $verCHEAT++; $reportMods += "[CHEAT] $($file.Name)  --  $joined"
                    continue
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
                                Log $LiveLog "  [CHEAT] dep $($dep.Name): $joined"
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
                    $zoneStr = if ($zone) { "from: $zone" } else { "no source" }
                    Log $LiveLog "  [UNK] $zoneStr"
                    $modBox.Invoke([Action]{ $modBox.Items.Add("[UNK] $($file.Name)") | Out-Null })
                    $verUNK++; $reportMods += "[UNK]   $($file.Name)  --  $zoneStr"
                }
            }
        }

        $ok_=$verOK; $unk_=$verUNK; $cheat_=$verCHEAT
        $okLbl.Invoke([Action]{ $okLbl.Text = "OK: $ok_" })
        $unkLbl.Invoke([Action]{ $unkLbl.Text = "UNK: $unk_" })
        $cheatLbl.Invoke([Action]{ $cheatLbl.Text = "CHEAT: $cheat_" })
        Log $LiveLog "Mod scan done -- OK: $verOK  UNK: $verUNK  CHEAT: $verCHEAT"
        Log $LiveLog ""
        Set-Prog 35

        if (-not $global:StopAll) {
            Log $LiveLog "--- MEMORY SCAN ---"
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
                Log $LiveLog "[WARN] Minecraft not running - skipping memory scan"
                $memBox.Invoke([Action]{ $memBox.Items.Add("Minecraft not running") | Out-Null })
                $memLbl.Invoke([Action]{ $memLbl.Text = "MEM: N/A" })
            } else {
                foreach ($proc in $javaws) {
                    if ($global:StopAll) { break }
                    Log $LiveLog "Scanning PID $($proc.Id)..."
                    $handle = [MemReader2]::OpenProcess(0x0410,$false,$proc.Id)
                    if ($handle -eq [IntPtr]::Zero) {
                        Log $LiveLog "[WARN] Cannot open PID $($proc.Id)"
                        continue
                    }
                    $addr = [IntPtr]::Zero; $hits = @{}; $scanned = 0
                    while ($scanned -lt 512MB -and -not $global:StopAll) {
                        $mbi = New-Object MemReader2+MBI3
                        $ret = [MemReader2]::VirtualQueryEx($handle,$addr,[ref]$mbi,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
                        if ($ret -eq 0) { break }
                        $size = $mbi.RegionSize.ToInt64()
                        if ($size -le 0) { break }
                        $readable = ($mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x20 -or $mbi.Protect -eq 0x40)
                        if ($mbi.State -eq 0x1000 -and $readable) {
                            $buf = New-Object byte[] ([Math]::Min($size,4MB)); $read = 0
                            if ([MemReader2]::ReadProcessMemory($handle,$mbi.Base,$buf,$buf.Length,[ref]$read) -and $read -gt 0) {
                                $str = [System.Text.Encoding]::UTF8.GetString($buf,0,$read)
                                foreach ($sig in $MEM_SIGS) {
                                    if (-not $hits[$sig] -and $str.Contains($sig)) {
                                        $hits[$sig] = $true
                                        Log $LiveLog "  [HIT] $sig"
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
                        Log $LiveLog "  [OK] PID $($proc.Id) clean"
                        $memBox.Invoke([Action]{ $memBox.Items.Add("[OK] PID $($proc.Id) clean") | Out-Null })
                    }
                }
                $mh = $totalMemHits
                $memLbl.Invoke([Action]{ $memLbl.Text = "MEM: $mh hit(s)" })
            }
            Log $LiveLog "Memory scan done -- $totalMemHits hit(s)"
            Log $LiveLog ""
            Set-Prog 60
        }

        if (-not $global:StopAll) {
            Log $LiveLog "--- SYS INFO ---"
            Set-Status "Gathering sys info..."

            $jw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $jw) { $jw = Get-Process -Name "java" -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if ($jw) {
                $el = (Get-Date) - $jw.StartTime
                $ups = "$($el.Hours)h $($el.Minutes)m $($el.Seconds)s"
                $startedAt = $jw.StartTime.ToString("HH:mm:ss")
                Log $LiveLog "  MC Uptime: $ups (since $startedAt) PID $($jw.Id)"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("Uptime: $ups since $startedAt") | Out-Null })
            } else {
                Log $LiveLog "  MC not running"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("Minecraft not running") | Out-Null })
            }

            try {
                $mb2  = (Get-WmiObject win32_baseboard).Manufacturer + " " + (Get-WmiObject win32_baseboard).SerialNumber
                $cpu2 = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
                $dsk  = (Get-PhysicalDisk | Select-Object -First 1).SerialNumber
                $raw  = "$mb2|$cpu2|$dsk"
                $hwid = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($raw)).Replace("=","")
                Log $LiveLog "  HWID: $hwid"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("HWID: $($hwid.Substring(0,[Math]::Min(40,$hwid.Length)))...") | Out-Null })
            } catch {
                Log $LiveLog "  HWID failed: $_"
                $sysBox.Invoke([Action]{ $sysBox.Items.Add("HWID: error") | Out-Null })
            }

            Log $LiveLog "Sys info done"
            Log $LiveLog ""
            Set-Prog 75
        }

        if (-not $global:StopAll) {
            Log $LiveLog "--- SI DEEP SCAN ---"
            Set-Status "Running SI deep scan..."

            $siExe = $SI_PATHS | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $siExe) {
                Log $LiveLog "[WARN] System Informer not installed - skipping"
                Log $LiveLog "       Get it from systeminformer.sourceforge.io"
                $siBox.Invoke([Action]{ $siBox.Items.Add("System Informer not found") | Out-Null })
                $siLbl.Invoke([Action]{ $siLbl.Text = "SI: N/A" })
            } else {
                $siProc = Get-Process -Name "SystemInformer","ProcessHacker" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $siProc) { Start-Process $siExe; Start-Sleep 3 }
                $siProc = Get-Process -Name "SystemInformer","ProcessHacker" -ErrorAction SilentlyContinue | Select-Object -First 1

                $javaw2 = Get-Process -Name "javaw" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $javaw2) {
                    Log $LiveLog "[WARN] Minecraft not running - skipping SI scan"
                    $siBox.Invoke([Action]{ $siBox.Items.Add("Minecraft not running") | Out-Null })
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
                        Log $LiveLog "[ERROR] Cannot open javaw - need admin"
                    } else {
                        while ($scanned2 -lt 1GB -and -not $global:StopAll) {
                            $mbi2 = New-Object SIMem2+MBI4
                            $ret2 = [SIMem2]::VirtualQueryEx($handle2,$addr2,[ref]$mbi2,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi2))
                            if ($ret2 -eq 0) { break }
                            $size2 = $mbi2.RegionSize.ToInt64()
                            if ($size2 -le 0) { break }
                            $priv2 = $mbi2.Type  -eq 0x20000
                            $comm2 = $mbi2.State -eq 0x1000
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
                            $cnt2 = $allHits2[$kw]
                            Log $LiveLog "  [HIT] $kw ($cnt2 regions)"
                            $siBox.Invoke([Action]{ $siBox.Items.Add("[HIT] $kw") | Out-Null })
                            $siHitCount++
                        }
                    }
                    if ($siHitCount -eq 0) {
                        Log $LiveLog "  [OK] No SI keyword hits"
                        $siBox.Invoke([Action]{ $siBox.Items.Add("[OK] No hits") | Out-Null })
                    }
                    $sh = $siHitCount
                    $siLbl.Invoke([Action]{ $siLbl.Text = "SI: $sh hit(s)" })
                }
            }
            Log $LiveLog "SI scan done"
            Log $LiveLog ""
            Set-Prog 90
        }

        if (-not $global:StopAll) {
            Log $LiveLog "--- WRITING REPORT ---"
            $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $lines = @(
                "="*60,
                "  SS TOOL FULL SCAN REPORT",
                "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
                "  $env:COMPUTERNAME / $env:USERNAME",
                "  Mods folder: $mc",
                "="*60,""
            )
            $lines += "--- MOD ANALYZER ---"
            foreach ($r in $reportMods) { $lines += "  $r" }
            $lines += ""
            $lines | Out-File "$out\fullscan_$stamp.txt" -Encoding UTF8
            Log $LiveLog "Report saved: $out\fullscan_$stamp.txt"
        }

        Set-Prog 100
        Set-Status "All scans complete"
        Log $LiveLog ""
        Log $LiveLog "============================================"
        Log $LiveLog "  ALL SCANS COMPLETE"
        Log $LiveLog "============================================"

        $StartBtn.Invoke([Action]{ $StartBtn.Visible = $true })
        $StopBtn.Invoke([Action]{ $StopBtn.Visible = $false; $StopBtn.Enabled = $false })
    })
    $t.IsBackground = $true; $t.Start()
})

[System.Windows.Forms.Application]::Run($Form)
