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

$fUI   = New-Object System.Drawing.Font("Segoe UI", 10)
$fBold = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fMono = New-Object System.Drawing.Font("Consolas", 9)
$fHead = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$fTiny = New-Object System.Drawing.Font("Consolas", 8)

$CHEATS    = @("wurst","impact","future","liquidbounce","aristois","meteor","killaura","sigma","entropy","novoline","rusherhack","vape","astolfo","inertia","ghost","rise","tenacity","aura","esp","aimbot","bhop","scaffold","velocity","criticals","nofall","autoeat","autofish","tracers","xray","freecam","fly","speed","jesus","mixin","bytebuddy","javassist","agentmain","premain")
$SCAN_EXTS = @(".jar",".zip",".class",".json",".cfg",".properties")
$MEM_SIGS  = @("KillAura","killaura","AutoCrystal","autocrystal","Scaffold","scaffold","Velocity","NoFall","Freecam","ESP","Xray","xray","BHop","Flight","CrystalAura","BaritoneAPI","agentmain","premain","ClassFileTransformer","bytebuddy","javassist","aimbot","wallhack","autoclick","triggerbot","sendPacket","injectPacket","noknockback")

$global:McFolder  = ""
$global:OutFolder = ""
$global:Findings  = @()
$global:StopScan  = $false
$global:StopMem   = $false

function New-Lbl($txt,$x,$y,$w,$h,$fg,$bg,$font=$fUI,$align="MiddleLeft") {
    $l = New-Object System.Windows.Forms.Label
    $l.Text=$txt; $l.Location=New-Object System.Drawing.Point($x,$y); $l.Size=New-Object System.Drawing.Size($w,$h)
    $l.ForeColor=$fg; $l.BackColor=$bg; $l.Font=$font
    $l.TextAlign=[System.Drawing.ContentAlignment]::$align
    return $l
}
function New-Btn($txt,$x,$y,$w,$h,$bg,$fg) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text=$txt; $b.Location=New-Object System.Drawing.Point($x,$y); $b.Size=New-Object System.Drawing.Size($w,$h)
    $b.BackColor=$bg; $b.ForeColor=$fg; $b.FlatStyle="Flat"
    $b.FlatAppearance.BorderSize=0; $b.Font=$fBold; $b.Cursor="Hand"
    return $b
}
function New-Tbox($x,$y,$w,$h,$multi=$false) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location=New-Object System.Drawing.Point($x,$y); $t.Size=New-Object System.Drawing.Size($w,$h)
    $t.BackColor=$cBG3; $t.ForeColor=$cTEXT; $t.BorderStyle="None"; $t.Font=$fMono
    if ($multi) { $t.Multiline=$true; $t.ScrollBars="Vertical"; $t.ReadOnly=$true; $t.WordWrap=$true }
    return $t
}
function Log($box,$txt) {
    if ($box.InvokeRequired) { $box.Invoke([Action]{ $box.AppendText("$txt`r`n"); $box.ScrollToCaret() }) }
    else { $box.AppendText("$txt`r`n"); $box.ScrollToCaret() }
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text="SS Tool  //  MC Cheat Scanner"; $Form.Size=New-Object System.Drawing.Size(1100,720)
$Form.MinimumSize=New-Object System.Drawing.Size(960,600); $Form.BackColor=$cBG
$Form.StartPosition="CenterScreen"; $Form.FormBorderStyle="Sizable"

$Header = New-Object System.Windows.Forms.Panel
$Header.Dock="Top"; $Header.Height=52; $Header.BackColor=$cBG2
$Header.Controls.Add((New-Lbl "⚡  SS TOOL  //  MC CHEAT SCANNER" 16 12 500 28 $cACCENT $cBG2 $fHead))
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
$Header.Controls.Add((New-Lbl (if($isAdmin){"✔ ADMIN"}else{"⚠ NOT ADMIN"}) 950 16 120 22 (if($isAdmin){$cGREEN}else{$cRED}) $cBG2 $fTiny "MiddleRight"))
$Form.Controls.Add($Header)

$NavLine = New-Object System.Windows.Forms.Panel
$NavLine.Dock="Top"; $NavLine.Height=1; $NavLine.BackColor=$cBORDER
$Form.Controls.Add($NavLine)

$Nav = New-Object System.Windows.Forms.Panel
$Nav.Dock="Top"; $Nav.Height=40; $Nav.BackColor=$cBG2
$Form.Controls.Add($Nav)

$NavLine2 = New-Object System.Windows.Forms.Panel
$NavLine2.Dock="Top"; $NavLine2.Height=1; $NavLine2.BackColor=$cBORDER
$Form.Controls.Add($NavLine2)

$Container = New-Object System.Windows.Forms.Panel
$Container.Dock="Fill"; $Container.BackColor=$cBG
$Form.Controls.Add($Container)

$StatusBar = New-Object System.Windows.Forms.Panel
$StatusBar.Dock="Bottom"; $StatusBar.Height=24; $StatusBar.BackColor=$cBG2
$StatusLbl = New-Lbl "Ready — set paths in Setup then run a scan" 10 4 900 18 $cDIM $cBG2 $fTiny
$StatusBar.Controls.Add($StatusLbl)
$Form.Controls.Add($StatusBar)

function Set-Status($msg) {
    if ($StatusLbl.InvokeRequired) { $StatusLbl.Invoke([Action]{ $StatusLbl.Text=$msg }) }
    else { $StatusLbl.Text=$msg }
}

$Pages = @{}

function Show-Page($name) {
    foreach ($p in $Pages.Values) { $p.Visible=$false }
    $Pages[$name].Visible=$true
    foreach ($nb in $Nav.Controls) {
        if ($nb -is [System.Windows.Forms.Button]) {
            if ($nb.Tag -eq $name) { $nb.ForeColor=$cACCENT; $nb.BackColor=$cBG3 }
            else { $nb.ForeColor=$cDIM; $nb.BackColor=$cBG2 }
        }
    }
}

$navNames = @("Setup","Scanner","Memory","Sys Info")
$nx = 0
foreach ($name in $navNames) {
    $nb = New-Object System.Windows.Forms.Button
    $nb.Text=" $name "; $nb.Tag=$name
    $nb.Location=New-Object System.Drawing.Point($nx,0); $nb.Size=New-Object System.Drawing.Size(110,40)
    $nb.BackColor=$cBG2; $nb.ForeColor=$cDIM; $nb.FlatStyle="Flat"
    $nb.FlatAppearance.BorderSize=0; $nb.Font=$fBold; $nb.Cursor="Hand"
    $nb.Add_Click({ param($s,$e) Show-Page $s.Tag })
    $Nav.Controls.Add($nb)
    $nx += 110
    $page = New-Object System.Windows.Forms.Panel
    $page.Dock="Fill"; $page.BackColor=$cBG; $page.Visible=$false
    $Container.Controls.Add($page)
    $Pages[$name] = $page
}

$pSetup   = $Pages["Setup"]
$pScan    = $Pages["Scanner"]
$pMemory  = $Pages["Memory"]
$pSysInfo = $Pages["Sys Info"]

$pSetup.Controls.Add((New-Lbl "SETUP" 20 18 300 30 $cACCENT $cBG $fHead))
$pSetup.Controls.Add((New-Lbl "Set your folders before running any scan." 20 52 600 22 $cDIM $cBG $fUI))
$pSetup.Controls.Add((New-Lbl "Minecraft Mods Folder" 20 88 300 22 $cACCENT $cBG $fBold))
$McEntry = New-Tbox 20 114 780 28
$pSetup.Controls.Add($McEntry)
$bMc = New-Btn "Browse" 812 112 100 30 $cBG3 $cACCENT
$bMc.Add_Click({
    $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description="Select Minecraft mods folder"
    if ($d.ShowDialog()-eq"OK") { $McEntry.Text=$d.SelectedPath; $global:McFolder=$d.SelectedPath }
})
$pSetup.Controls.Add($bMc)
$pSetup.Controls.Add((New-Lbl "Output / Report Folder" 20 158 300 22 $cACCENT $cBG $fBold))
$OutEntry = New-Tbox 20 184 780 28
$pSetup.Controls.Add($OutEntry)
$bOut = New-Btn "Browse" 812 182 100 30 $cBG3 $cACCENT
$bOut.Add_Click({
    $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description="Select output folder"
    if ($d.ShowDialog()-eq"OK") { $OutEntry.Text=$d.SelectedPath; $global:OutFolder=$d.SelectedPath }
})
$pSetup.Controls.Add($bOut)
$pSetup.Controls.Add((New-Lbl "Quick Launch" 20 228 300 22 $cACCENT $cBG $fBold))
$qlScan = New-Btn "▶  File Scanner" 20 254 150 36 $cGREEN $cBG
$qlScan.Add_Click({ Show-Page "Scanner" })
$pSetup.Controls.Add($qlScan)
$qlMem = New-Btn "▶  Memory Scan" 180 254 150 36 $cACCENT $cBG
$qlMem.Add_Click({ Show-Page "Memory" })
$pSetup.Controls.Add($qlMem)
$qlSys = New-Btn "▶  Sys Info" 340 254 150 36 $cORANGE $cBG
$qlSys.Add_Click({ Show-Page "Sys Info" })
$pSetup.Controls.Add($qlSys)
$reqTxt  = if (Get-Command python -ErrorAction SilentlyContinue) {"✔ Python  "} else {"✘ Python  "}
$reqTxt += if ($isAdmin) {"✔ Admin  "} else {"✘ Admin  "}
$reqTxt += if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {"✔ Windows"} else {"✘ Windows"}
$pSetup.Controls.Add((New-Lbl "Requirements" 20 310 200 22 $cACCENT $cBG $fBold))
$pSetup.Controls.Add((New-Lbl $reqTxt 20 336 600 24 $cTEXT $cBG $fMono))

$scanTopBar = New-Object System.Windows.Forms.Panel
$scanTopBar.Dock="Top"; $scanTopBar.Height=48; $scanTopBar.BackColor=$cBG2
$pScan.Controls.Add($scanTopBar)
$scanTopBar.Controls.Add((New-Lbl "FILE SCANNER" 16 14 300 22 $cACCENT $cBG2 $fBold))
$scanProg = New-Object System.Windows.Forms.ProgressBar
$scanProg.Dock="Top"; $scanProg.Height=4; $scanProg.Style="Continuous"
$scanProg.BackColor=$cBG2; $scanProg.ForeColor=$cACCENT
$pScan.Controls.Add($scanProg)
$scanSplit = New-Object System.Windows.Forms.SplitContainer
$scanSplit.Dock="Fill"; $scanSplit.SplitterDistance=300; $scanSplit.BackColor=$cBORDER
$scanSplit.Panel1.BackColor=$cBG2; $scanSplit.Panel2.BackColor=$cBG
$pScan.Controls.Add($scanSplit)
$scanSplit.Panel1.Controls.Add((New-Lbl "FINDINGS" 10 8 200 18 $cDIM $cBG2 $fTiny))
$cntPanel = New-Object System.Windows.Forms.Panel
$cntPanel.Location=New-Object System.Drawing.Point(6,28); $cntPanel.Size=New-Object System.Drawing.Size(282,48); $cntPanel.BackColor=$cBG2
$critLbl = New-Lbl "0  CRIT" 0 0 94 48 $cRED $cBG3 $fBold "MiddleCenter"
$warnLbl = New-Lbl "0  WARN" 95 0 94 48 $cORANGE $cBG3 $fBold "MiddleCenter"
$infoLbl = New-Lbl "0  INFO" 190 0 94 48 $cACCENT $cBG3 $fBold "MiddleCenter"
$cntPanel.Controls.AddRange(@($critLbl,$warnLbl,$infoLbl))
$scanSplit.Panel1.Controls.Add($cntPanel)
$findBox = New-Object System.Windows.Forms.ListBox
$findBox.Location=New-Object System.Drawing.Point(6,82); $findBox.Size=New-Object System.Drawing.Size(282,500)
$findBox.BackColor=$cBG2; $findBox.ForeColor=$cTEXT; $findBox.BorderStyle="None"; $findBox.Font=$fMono
$scanSplit.Panel1.Controls.Add($findBox)
$scanSplit.Panel2.Controls.Add((New-Lbl "SCAN LOG" 10 8 200 18 $cDIM $cBG $fTiny))
$scanLog = New-Tbox 6 28 0 0 $true; $scanLog.Dock="Fill"; $scanLog.BackColor=$cBG
$scanSplit.Panel2.Controls.Add($scanLog)
$stopScanBtn = New-Btn "■  STOP" 940 10 100 28 $cRED ([System.Drawing.Color]::White)
$stopScanBtn.Enabled=$false
$stopScanBtn.Add_Click({ $global:StopScan=$true })
$scanTopBar.Controls.Add($stopScanBtn)
$startScanBtn = New-Btn "▶  START SCAN" 820 10 116 28 $cGREEN $cBG
$scanTopBar.Controls.Add($startScanBtn)

$startScanBtn.Add_Click({
    $global:McFolder=$McEntry.Text.Trim(); $global:OutFolder=$OutEntry.Text.Trim()
    if (-not $global:McFolder -or -not (Test-Path $global:McFolder)) { Log $scanLog "[ERROR] Set a valid Minecraft folder in Setup."; return }
    if (-not $global:OutFolder -or -not (Test-Path $global:OutFolder)) { Log $scanLog "[ERROR] Set a valid output folder in Setup."; return }
    $global:StopScan=$false; $global:Findings=@()
    $findBox.Items.Clear(); $scanLog.Clear(); $scanProg.Value=0
    $critLbl.Text="0  CRIT"; $warnLbl.Text="0  WARN"; $infoLbl.Text="0  INFO"
    $startScanBtn.Enabled=$false; $stopScanBtn.Enabled=$true
    Set-Status "File scan running..."
    $t=[System.Threading.Thread]::new({
        $mc=$global:McFolder; $out=$global:OutFolder
        Log $scanLog "Started  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Log $scanLog "Folder   $mc"
        Log $scanLog ""
        Log $scanLog "Scanning files..."
        $scanProg.Invoke([Action]{ $scanProg.Value=20 })
        $skipDirs=@("versions","assets","libraries","natives","cache")
        Get-ChildItem -Path $mc -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if ($global:StopScan) { return }
            $rel=$_.FullName.Replace($mc,"").TrimStart("\")
            $top=$rel.Split("\")[0].ToLower()
            if ($skipDirs -contains $top) { return }
            $ext=$_.Extension.ToLower()
            if ($SCAN_EXTS -notcontains $ext) { return }
            $name=$_.Name.ToLower()
            foreach ($ch in $CHEATS) {
                if ($name -match $ch) {
                    Log $scanLog "[CRIT] Cheat file: $($_.Name)"
                    $global:Findings+=[PSCustomObject]@{Severity="critical";Category="Cheat File";Detail=$_.FullName}
                    $findBox.Invoke([Action]{ $findBox.Items.Add("[CRIT] Cheat File: $($_.Name)") | Out-Null })
                    $c=[int]($critLbl.Text.Split(" ")[0])+1
                    $critLbl.Invoke([Action]{ $critLbl.Text="$c  CRIT" })
                }
            }
            if ($ext -in @(".json",".cfg",".properties")) {
                try {
                    $hit=Get-Content $_.FullName -Raw -ErrorAction Stop | Select-String -Pattern ($CHEATS -join "|") -Quiet
                    if ($hit) {
                        Log $scanLog "[WARN] Cheat string in config: $($_.Name)"
                        $global:Findings+=[PSCustomObject]@{Severity="warning";Category="Config Match";Detail=$_.FullName}
                        $findBox.Invoke([Action]{ $findBox.Items.Add("[WARN] Config: $($_.Name)") | Out-Null })
                        $w=[int]($warnLbl.Text.Split(" ")[0])+1
                        $warnLbl.Invoke([Action]{ $warnLbl.Text="$w  WARN" })
                    }
                } catch {}
            }
        }
        Log $scanLog "File scan done."
        Log $scanLog ""
        Log $scanLog "Checking startup entries..."
        $scanProg.Invoke([Action]{ $scanProg.Value=60 })
        @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup","$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup") | ForEach-Object {
            if (Test-Path $_) {
                Get-ChildItem $_ | ForEach-Object {
                    foreach ($ch in $CHEATS) {
                        if ($_.Name.ToLower() -match $ch) {
                            Log $scanLog "[CRIT] Cheat in startup: $($_.Name)"
                            $global:Findings+=[PSCustomObject]@{Severity="critical";Category="Startup";Detail=$_.FullName}
                            $findBox.Invoke([Action]{ $findBox.Items.Add("[CRIT] Startup: $($_.Name)") | Out-Null })
                        }
                    }
                }
            }
        }
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run","HKLM:\Software\Microsoft\Windows\CurrentVersion\Run") | ForEach-Object {
            if (Test-Path $_) {
                $rp=$_
                Get-ItemProperty $rp | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $val=(Get-ItemProperty $rp).$($_.Name)
                    foreach ($ch in $CHEATS) {
                        if ($_.Name.ToLower() -match $ch -or "$val".ToLower() -match $ch) {
                            Log $scanLog "[CRIT] Registry Run: $($_.Name)"
                            $global:Findings+=[PSCustomObject]@{Severity="critical";Category="Registry Run";Detail="$($_.Name) = $val"}
                            $findBox.Invoke([Action]{ $findBox.Items.Add("[CRIT] Registry: $($_.Name)") | Out-Null })
                        }
                    }
                }
            }
        }
        Log $scanLog "Startup check done."
        Log $scanLog ""
        Log $scanLog "Writing report..."
        $scanProg.Invoke([Action]{ $scanProg.Value=90 })
        $stamp=Get-Date -Format "yyyyMMdd_HHmmss"
        $crits=($global:Findings|Where-Object Severity -eq "critical").Count
        $warns=($global:Findings|Where-Object Severity -eq "warning").Count
        $lines=@("="*60,"  SS TOOL SCAN REPORT","  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')","  $env:COMPUTERNAME / $env:USERNAME","  Scanned: $mc","="*60,"","  Total: $($global:Findings.Count)  Critical: $crits  Warning: $warns","")
        foreach ($f in $global:Findings) { $lines+="  [$($f.Severity.ToUpper())]  $($f.Category) — $($f.Detail)" }
        $lines|Out-File "$out\scan_$stamp.txt" -Encoding UTF8
        $global:Findings|ConvertTo-Json|Out-File "$out\scan_$stamp.json" -Encoding UTF8
        Log $scanLog "Report saved to $out\scan_$stamp.txt"
        $scanProg.Invoke([Action]{ $scanProg.Value=100 })
        Set-Status "Done — $($global:Findings.Count) findings, $crits critical"
        Log $scanLog ""
        Log $scanLog "Scan complete."
        $startScanBtn.Invoke([Action]{ $startScanBtn.Enabled=$true })
        $stopScanBtn.Invoke([Action]{ $stopScanBtn.Enabled=$false })
    })
    $t.IsBackground=$true; $t.Start()
})

$memTopBar = New-Object System.Windows.Forms.Panel
$memTopBar.Dock="Top"; $memTopBar.Height=48; $memTopBar.BackColor=$cBG2
$pMemory.Controls.Add($memTopBar)
$memTopBar.Controls.Add((New-Lbl "MEMORY SCANNER" 16 14 400 22 $cACCENT $cBG2 $fBold))
$memTopBar.Controls.Add((New-Lbl "Scans javaw.exe RAM for cheat signatures" 230 16 400 18 $cDIM $cBG2 $fTiny))
$stopMemBtn = New-Btn "■  STOP" 940 10 100 28 $cRED ([System.Drawing.Color]::White)
$stopMemBtn.Enabled=$false
$stopMemBtn.Add_Click({ $global:StopMem=$true })
$memTopBar.Controls.Add($stopMemBtn)
$startMemBtn = New-Btn "▶  SCAN MEMORY" 800 10 136 28 $cACCENT $cBG
$memTopBar.Controls.Add($startMemBtn)
$memLog = New-Tbox 8 56 0 0 $true; $memLog.Dock="Fill"; $memLog.BackColor=$cBG
$pMemory.Controls.Add($memLog)

$startMemBtn.Add_Click({
    $memLog.Clear(); $global:StopMem=$false
    $startMemBtn.Enabled=$false; $stopMemBtn.Enabled=$true
    Set-Status "Memory scan running..."
    $t=[System.Threading.Thread]::new({
        Log $memLog "Memory scan started  $(Get-Date -Format 'HH:mm:ss')"
        Log $memLog ""
        $javaws=Get-Process -Name "javaw" -ErrorAction SilentlyContinue
        if (-not $javaws) {
            Log $memLog "[WARN] No javaw.exe found. Is Minecraft running?"
            $startMemBtn.Invoke([Action]{$startMemBtn.Enabled=$true}); $stopMemBtn.Invoke([Action]{$stopMemBtn.Enabled=$false})
            Set-Status "No Minecraft found"; return
        }
        Add-Type @"
using System; using System.Runtime.InteropServices;
public class MemReader {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a,bool b,int c);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int s,out int r);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h,IntPtr a,out MBI m,uint s);
    [StructLayout(LayoutKind.Sequential)] public struct MBI { public IntPtr Base,AllocBase; public uint AllocProtect; public IntPtr RegionSize; public uint State,Protect,Type; }
}
"@ -ErrorAction SilentlyContinue
        $totalHits=0
        foreach ($proc in $javaws) {
            Log $memLog "Scanning PID $($proc.Id)..."
            $handle=[MemReader]::OpenProcess(0x0410,$false,$proc.Id)
            if ($handle -eq [IntPtr]::Zero) { Log $memLog "[WARN] Cannot open PID $($proc.Id) — need admin"; continue }
            $addr=[IntPtr]::Zero; $hits=@{}; $scanned=0
            while ($scanned -lt 512MB -and -not $global:StopMem) {
                $mbi=New-Object MemReader+MBI
                $ret=[MemReader]::VirtualQueryEx($handle,$addr,[ref]$mbi,[System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
                if ($ret -eq 0) { break }
                $size=$mbi.RegionSize.ToInt64()
                if ($size -le 0) { break }
                if ($mbi.State -eq 0x1000 -and ($mbi.Protect -eq 0x02 -or $mbi.Protect -eq 0x04 -or $mbi.Protect -eq 0x20 -or $mbi.Protect -eq 0x40)) {
                    $buf=New-Object byte[] ([Math]::Min($size,4MB)); $read=0
                    if ([MemReader]::ReadProcessMemory($handle,$mbi.Base,$buf,$buf.Length,[ref]$read) -and $read -gt 0) {
                        $str=[System.Text.Encoding]::UTF8.GetString($buf,0,$read)
                        foreach ($sig in $MEM_SIGS) {
                            if (-not $hits[$sig] -and $str.Contains($sig)) { $hits[$sig]=$true; Log $memLog "[CRIT] HIT: $sig"; $totalHits++ }
                        }
                    }
                    $scanned+=$read
                }
                $next=$mbi.Base.ToInt64()+$size
                if ($next -ge 0x7FFFFFFFFFFF) { break }
                $addr=[IntPtr]::new($next)
            }
            [MemReader]::CloseHandle($handle)|Out-Null
            if ($hits.Count -eq 0) { Log $memLog "✔ PID $($proc.Id) — Clean" }
            else { Log $memLog "⚠ PID $($proc.Id) — $($hits.Count) signature(s) found" }
        }
        Log $memLog ""; Log $memLog "Done — $totalHits total hit(s)"
        Set-Status "Memory scan done — $totalHits hit(s)"
        $startMemBtn.Invoke([Action]{$startMemBtn.Enabled=$true}); $stopMemBtn.Invoke([Action]{$stopMemBtn.Enabled=$false})
    })
    $t.IsBackground=$true; $t.Start()
})

$sysTopBar = New-Object System.Windows.Forms.Panel
$sysTopBar.Dock="Top"; $sysTopBar.Height=48; $sysTopBar.BackColor=$cBG2
$pSysInfo.Controls.Add($sysTopBar)
$sysTopBar.Controls.Add((New-Lbl "SYSTEM INFO" 16 14 300 22 $cACCENT $cBG2 $fBold))
$runSysBtn = New-Btn "▶  RUN CHECKS" 820 10 140 28 $cORANGE $cBG
$sysTopBar.Controls.Add($runSysBtn)
$uptimePanel = New-Object System.Windows.Forms.Panel
$uptimePanel.Location=New-Object System.Drawing.Point(8,56); $uptimePanel.Size=New-Object System.Drawing.Size(500,56); $uptimePanel.BackColor=$cBG3
$pSysInfo.Controls.Add($uptimePanel)
$uptimePanel.Controls.Add((New-Lbl "MC UPTIME" 12 6 200 16 $cDIM $cBG3 $fTiny))
$uptimeVal=New-Lbl "—" 12 24 480 24 $cTEXT $cBG3 $fBold
$uptimePanel.Controls.Add($uptimeVal)
$hwidPanel = New-Object System.Windows.Forms.Panel
$hwidPanel.Location=New-Object System.Drawing.Point(8,120); $hwidPanel.Size=New-Object System.Drawing.Size(1050,56); $hwidPanel.BackColor=$cBG3
$pSysInfo.Controls.Add($hwidPanel)
$hwidPanel.Controls.Add((New-Lbl "HWID" 12 6 200 16 $cDIM $cBG3 $fTiny))
$hwidVal=New-Lbl "—" 12 24 1020 24 $cACCENT $cBG3 $fMono
$hwidPanel.Controls.Add($hwidVal)
$sysLog=New-Tbox 8 184 1066 400 $true; $sysLog.Anchor="Top,Bottom,Left,Right"
$pSysInfo.Controls.Add($sysLog)

$runSysBtn.Add_Click({
    $sysLog.Clear(); $uptimeVal.Text="Checking..."; $hwidVal.Text="Generating..."
    Set-Status "Running sys info checks..."
    $t=[System.Threading.Thread]::new({
        Log $sysLog "Checks started  $(Get-Date -Format 'HH:mm:ss')"
        Log $sysLog "Host: $env:COMPUTERNAME   User: $env:USERNAME"
        Log $sysLog ""
        Log $sysLog "MC Uptime"
        $jw=Get-Process -Name "javaw" -ErrorAction SilentlyContinue|Select-Object -First 1
        if ($jw) {
            $el=(Get-Date)-$jw.StartTime; $ups="$($el.Hours)h $($el.Minutes)m $($el.Seconds)s"
            $uptimeVal.Invoke([Action]{ $uptimeVal.Text="PID $($jw.Id) — $ups (started $($jw.StartTime.ToString('HH:mm:ss')))" })
            Log $sysLog "✔ javaw PID $($jw.Id) running $ups"
        } else {
            $uptimeVal.Invoke([Action]{ $uptimeVal.Text="Not running" })
            Log $sysLog "No Minecraft process found."
        }
        Log $sysLog ""
        Log $sysLog "HWID"
        try {
            $mb=(Get-WmiObject win32_baseboard).Manufacturer+" "+(Get-WmiObject win32_baseboard).SerialNumber
            $cpu=(Get-WmiObject Win32_Processor).Name
            $disk=(Get-PhysicalDisk|Select-Object -First 1).SerialNumber
            $raw="$mb|$cpu|$disk"
            $hwid=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($raw)).Replace("=","")
            $hwidVal.Invoke([Action]{ $hwidVal.Text=$hwid })
            Log $sysLog "✔ HWID generated"
            Log $sysLog $hwid
        } catch { $hwidVal.Invoke([Action]{ $hwidVal.Text="Error: $_" }); Log $sysLog "HWID failed: $_" }
        Log $sysLog ""; Log $sysLog "All checks complete."
        Set-Status "Sys info checks complete"
    })
    $t.IsBackground=$true; $t.Start()
})

Show-Page "Setup"
[System.Windows.Forms.Application]::Run($Form)
