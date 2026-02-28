param([string]$McFolder = "")

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force 2>$null

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$CheatNames = @(
    "wurst","impact","future","liquidbounce","aristois","meteor",
    "killaura","sigma","entropy","novoline","rusherhack","vape",
    "astolfo","inertia","ghost","rise","tenacity","nearbyplayers",
    "aura","esp","aimbot","bhop","scaffold","velocity","criticals",
    "nofall","autoeat","autofish","tracers","xray","freecam",
    "fly","speed","jesus","mixin","bytebuddy","javassist",
    "classinjector","agentmain","premain","instrumentation"
)

$BadJvmFlags = @(
    "-javaagent","-agentlib","-agentpath",
    "-Xbootclasspath","bytebuddy","javassist","premain","agentmain"
)

$CheatStrings = @(
    "AimAssist","AnchorTweaks","AutoAnchor","AutoCrystal","AutoDoubleHand",
    "AutoHitCrystal","AutoPot","AutoTotem","AutoArmor","InventoryTotem",
    "Hitboxes","JumpReset","LegitTotem","PingSpoof","SelfDestruct",
    "ShieldBreaker","TriggerBot","Velocity","AxeSpam","WebMacro","FastPlace",
    "CrystalAura","CrystalPlace","PlaceCrystal","BreakCrystal","CrystalSwap",
    "KillAura","AuraModule","AutoClicker","PacketFly","ElytraFly","Phase",
    "BedAura","AnchorAura","AutoBed","AutoTotem","TotemPopper","AutoOffhand",
    "sendPacket","injectPacket","ClassFileTransformer","redefineClasses",
    "Surround","AntiSurround","HoleFiller","AutoObsidian","OffhandSwap"
)

$ScanExts = @(".jar",".zip",".class",".json",".cfg",".properties")

$Findings = [System.Collections.Generic.List[hashtable]]::new()

function Write-Color {
    param([string]$Text, [string]$Color = "White", [switch]$NoNewline)
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Color ("─" * 60) "DarkGray"
    Write-Color "  $Title" "Cyan"
    Write-Color ("─" * 60) "DarkGray"
}

function Add-Finding {
    param([string]$Severity, [string]$Category, [string]$Detail, [string]$Extra = "")
    $Findings.Add(@{
        Severity = $Severity
        Category = $Category
        Detail   = $Detail
        Extra    = $Extra
        Time     = (Get-Date).ToString("o")
    })
}

function Get-SHA1 {
    param([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm SHA1).Hash
}

function Get-ZoneIdentifier {
    param([string]$FilePath)
    $ads = Get-Content -Raw -Stream Zone.Identifier $FilePath -ErrorAction SilentlyContinue
    if ($ads -match "HostUrl=(.+)") { return $matches[1].Trim() }
    return $null
}

function Fetch-Modrinth {
    param([string]$Hash)
    try {
        $r = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$Hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($r.project_id) {
            $p = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($r.project_id)" -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ Name = $p.title; Slug = $p.slug }
        }
    } catch {}
    return @{ Name = ""; Slug = "" }
}

function Fetch-Megabase {
    param([string]$Hash)
    try {
        $r = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$Hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $r.error) { return $r.data }
    } catch {}
    return $null
}

function Check-JarStrings {
    param([string]$FilePath)
    $found = [System.Collections.Generic.HashSet[string]]::new()
    try {
        $content = Get-Content -Raw $FilePath -ErrorAction SilentlyContinue
        if ($content) {
            foreach ($s in $CheatStrings) {
                if ($content -match $s) { $found.Add($s) | Out-Null }
            }
        }
    } catch {}
    return $found
}

Clear-Host
Write-Color " " 
Write-Color "  ⚡  MC CHEAT SCANNER  v3.0" "Cyan"
Write-Color "  ─────────────────────────────────────────────────────────" "DarkGray"
Write-Host ""

if (-not $McFolder) {
    Write-Color "  Enter path to the Minecraft instance folder:" "White"
    Write-Color "  (press Enter for default .minecraft)" "DarkGray"
    $McFolder = Read-Host "  PATH"
    Write-Host ""
}

if (-not $McFolder) {
    $McFolder = "$env:APPDATA\.minecraft"
    Write-Color "  Using default: $McFolder" "DarkGray"
    Write-Host ""
}

if (-not (Test-Path $McFolder -PathType Container)) {
    Write-Color "  Invalid path: $McFolder" "Red"
    pause
    exit 1
}

Write-Color "  Scanning: $McFolder" "Cyan"
Write-Host ""

$OutputFolder = "$env:TEMP\mc_scan_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null


Write-Section "1/7  —  Country, VPN & HWID"

try {
    $ipData = Invoke-RestMethod -Uri "https://api.ip2location.io/" -UseBasicParsing -ErrorAction Stop
    $country  = $ipData.country_name
    $isProxy  = $ipData.is_proxy
    $ipAddr   = $ipData.ip

    Write-Color "  ✔  IP      : $ipAddr" "Green"
    Write-Color "  ✔  Country : $country" "Green"

    if ($isProxy) {
        Write-Color "  🔴  VPN / Proxy detected via ip2location!" "Red"
        Add-Finding "critical" "VPN Detected" "IP $ipAddr flagged as proxy/VPN"
    } else {
        $vpnAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { -not $_.MacAddress -and $_.Status -eq "Up" } | Select-Object -ExpandProperty Name
        if ($vpnAdapter) {
            Write-Color "  🟠  VPN adapter found: $vpnAdapter" "Yellow"
            Add-Finding "warning" "VPN Adapter" "Adapter without MAC address: $vpnAdapter"
        } else {
            Write-Color "  ✔  No VPN detected" "Green"
        }
    }
} catch {
    Write-Color "  ⚠  Could not reach ip2location: $_" "Yellow"
}

Write-Host ""
Write-Color "  HWID:" "DarkGray"
try {
    $mb   = "$(((Get-WmiObject win32_baseboard).Manufacturer)) $(((Get-WmiObject win32_baseboard).Product)) $(((Get-WmiObject win32_baseboard).SerialNumber))"
    $ram  = "$(((Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).Manufacturer)) $(((Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).PartNumber)) $(((Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).SerialNumber))"
    $disk = "$(((Get-PhysicalDisk | Select-Object -First 1).FriendlyName)) $(((Get-PhysicalDisk | Select-Object -First 1).MediaType)) $(((Get-PhysicalDisk | Select-Object -First 1).SerialNumber))"
    $cpu  = "$((Get-WmiObject Win32_Processor).Name)"
    $raw  = "$mb | $ram | $disk | $cpu"
    $hwid = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($raw)).Replace("=","")
    Write-Color "  $hwid" "Cyan"
} catch {
    Write-Color "  ⚠  HWID generation failed: $_" "Yellow"
}


Write-Section "2/7  —  Minecraft Process & Uptime"

$McProcess = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $McProcess) { $McProcess = Get-Process java -ErrorAction SilentlyContinue }

if ($McProcess) {
    try {
        $startTime   = $McProcess.StartTime
        $elapsed     = (Get-Date) - $startTime
        $uptime      = "$($elapsed.Hours)h $($elapsed.Minutes)m $($elapsed.Seconds)s"
        Write-Color "  ✔  $($McProcess.Name) PID $($McProcess.Id) — running for $uptime" "Green"
        Add-Finding "info" "Process" "$($McProcess.Name) PID $($McProcess.Id)" "Started $startTime, uptime $uptime"
    } catch {
        Write-Color "  ✔  Minecraft running (PID $($McProcess.Id)) — uptime unavailable" "Green"
    }
} else {
    Write-Color "  No Minecraft process found — file scan will still run" "DarkGray"
}


Write-Section "3/7  —  JVM Arguments"

if ($McProcess) {
    try {
        $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($McProcess.Id)" -ErrorAction Stop
        $cmd = $wmi.CommandLine

        $flagHit = $false
        foreach ($flag in $BadJvmFlags) {
            if ($cmd -match [regex]::Escape($flag)) {
                $sev = if ($flag.StartsWith("-")) { "critical" } else { "warning" }
                $color = if ($sev -eq "critical") { "Red" } else { "Yellow" }
                Write-Color "  🔴  Suspicious JVM flag: $flag" $color
                Add-Finding $sev "JVM Flag" "'$flag' in PID $($McProcess.Id)" ($cmd.Substring(0, [Math]::Min(200, $cmd.Length)))
                $flagHit = $true
            }
        }

        $agents = [regex]::Matches($cmd, '-javaagent[=:]([^\s"]+)')
        foreach ($m in $agents) {
            $agent = $m.Groups[1].Value
            Write-Color "  🔴  Java agent JAR: $agent" "Red"
            Add-Finding "critical" "Java Agent" "Agent: $(Split-Path $agent -Leaf)" $agent
            foreach ($cheat in $CheatNames) {
                if ($agent.ToLower() -match $cheat) {
                    Write-Color "  🚨  KNOWN CHEAT MATCH: $($cheat.ToUpper())" "Red"
                    Add-Finding "critical" "Known Cheat" "Matches: $cheat" $agent
                }
            }
            $flagHit = $true
        }

        if (-not $flagHit) {
            Write-Color "  ✔  No suspicious JVM flags" "Green"
        }
    } catch {
        Write-Color "  ⚠  Could not read JVM args: $_" "Yellow"
    }
} else {
    Write-Color "  No process to check" "DarkGray"
}


Write-Section "4/7  —  Scanning Mod Files (Modrinth + Megabase)"

$VerifiedMods = @()
$UnknownMods  = @()
$CheatMods    = @()

$ModsFolder = Join-Path $McFolder "mods"
if (-not (Test-Path $ModsFolder)) {
    Write-Color "  No mods folder found at $ModsFolder" "DarkGray"
} else {
    $JarFiles   = Get-ChildItem -Path $ModsFolder -Filter "*.jar" -ErrorAction SilentlyContinue
    $Total      = $JarFiles.Count
    $Counter    = 0
    $Spinner    = @("|","/","-","\")

    foreach ($file in $JarFiles) {
        $Counter++
        $spin = $Spinner[$Counter % $Spinner.Length]
        Write-Host "`r  [$spin] Checking mods: $Counter / $Total   " -NoNewline -ForegroundColor Yellow

        $hash = Get-SHA1 -FilePath $file.FullName

        $modrinth = Fetch-Modrinth -Hash $hash
        if ($modrinth.Slug) {
            $VerifiedMods += [PSCustomObject]@{ ModName = $modrinth.Name; FileName = $file.Name }
            continue
        }

        $megabase = Fetch-Megabase -Hash $hash
        if ($megabase.name) {
            $VerifiedMods += [PSCustomObject]@{ ModName = $megabase.name; FileName = $file.Name }
            continue
        }

        $zoneId = Get-ZoneIdentifier $file.FullName
        $UnknownMods += [PSCustomObject]@{ FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneId }
    }

    Write-Host "`r$(' ' * 50)`r" -NoNewline

    if ($UnknownMods.Count -gt 0) {
        $TempDir = Join-Path $env:TEMP "mcscanner_jars"
        try {
            if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
            New-Item -ItemType Directory -Path $TempDir | Out-Null
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            $Counter = 0
            foreach ($mod in $UnknownMods) {
                $Counter++
                $spin = $Spinner[$Counter % $Spinner.Length]
                Write-Host "`r  [$spin] Deep scanning unknown mods: $Counter / $($UnknownMods.Count)   " -NoNewline -ForegroundColor Yellow

                $strings = Check-JarStrings $mod.FilePath
                if ($strings.Count -gt 0) {
                    $script:UnknownMods = @($UnknownMods | Where-Object { $_ -ne $mod })
                    $CheatMods += [PSCustomObject]@{ FileName = $mod.FileName; DepFileName = ""; StringsFound = $strings }
                    continue
                }

                $nameNoExt  = [System.IO.Path]::GetFileNameWithoutExtension($mod.FileName)
                $extractDir = Join-Path $TempDir $nameNoExt
                New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

                try {
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($mod.FilePath, $extractDir)
                } catch { continue }

                $depJarsPath = Join-Path $extractDir "META-INF\jars"
                if (Test-Path $depJarsPath) {
                    foreach ($dep in (Get-ChildItem -Path $depJarsPath)) {
                        $depStrings = Check-JarStrings $dep.FullName
                        if ($depStrings.Count -gt 0) {
                            $script:UnknownMods = @($UnknownMods | Where-Object { $_ -ne $mod })
                            $CheatMods += [PSCustomObject]@{ FileName = $mod.FileName; DepFileName = $dep.Name; StringsFound = $depStrings }
                        }
                    }
                }
            }
        } catch {
            Write-Color "  ⚠  Error during jar scan: $_" "Yellow"
        } finally {
            if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue }
        }

        Write-Host "`r$(' ' * 60)`r" -NoNewline
    }

    if ($VerifiedMods.Count -gt 0) {
        Write-Color "  ✔  Verified Mods ($($VerifiedMods.Count)):" "Green"
        foreach ($m in $VerifiedMods) {
            Write-Color ("    > {0,-32}" -f $m.ModName) "Green" -NoNewline
            Write-Color $m.FileName "DarkGray"
        }
    }

    if ($UnknownMods.Count -gt 0) {
        Write-Host ""
        Write-Color "  🟠  Unknown Mods ($($UnknownMods.Count)):" "Yellow"
        foreach ($m in $UnknownMods) {
            Add-Finding "warning" "Unknown Mod" $m.FileName ($m.ZoneId)
            if ($m.ZoneId) {
                Write-Color ("    > {0,-40}" -f $m.FileName) "Yellow" -NoNewline
                Write-Color $m.ZoneId "DarkGray"
            } else {
                Write-Color "    > $($m.FileName)" "Yellow"
            }
        }
    }

    if ($CheatMods.Count -gt 0) {
        Write-Host ""
        Write-Color "  🔴  Cheat Mods ($($CheatMods.Count)):" "Red"
        foreach ($m in $CheatMods) {
            Add-Finding "critical" "Cheat Mod" $m.FileName ($m.StringsFound -join ", ")
            Write-Color "    > $($m.FileName)" "Red" -NoNewline
            if ($m.DepFileName) { Write-Color " -> $($m.DepFileName)" "DarkRed" -NoNewline }
            Write-Color " [$($m.StringsFound -join ', ')]" "Magenta"
        }
    }

    if ($VerifiedMods.Count -eq 0 -and $UnknownMods.Count -eq 0 -and $CheatMods.Count -eq 0) {
        Write-Color "  No jar files found in mods folder" "DarkGray"
    }
}


Write-Section "5/7  —  File Scan (configs, extra jars)"

$ScannedCount = 0
Get-ChildItem -Path $McFolder -Recurse -ErrorAction SilentlyContinue |
    Where-Object { -not $_.PSIsContainer -and $ScanExts -contains $_.Extension.ToLower() } |
    Where-Object { $_.FullName -notmatch "\\(versions|assets|libraries|natives|cache)\\" } |
    ForEach-Object {
        $ScannedCount++
        $fname = $_.Name.ToLower()
        foreach ($cheat in $CheatNames) {
            if ($fname -match $cheat) {
                Write-Color "  🔴  Cheat filename: $($_.Name)" "Red"
                Add-Finding "critical" "Cheat File" "Filename matches '$cheat'" $_.FullName
            }
        }
        if ($_.Extension -in @(".json",".cfg",".properties")) {
            try {
                $content = Get-Content -Raw $_.FullName -ErrorAction SilentlyContinue
                if ($content) {
                    foreach ($cheat in $CheatNames) {
                        if ($content.ToLower() -match $cheat) {
                            Write-Color "  🟠  Cheat string in config: $($_.Name)" "Yellow"
                            Add-Finding "warning" "Config Match" "'$cheat' in config" $_.FullName
                            break
                        }
                    }
                }
            } catch {}
        }
    }

Write-Color "  ✔  Scanned $ScannedCount files" "Green"


Write-Section "6/7  —  Startup Entries"

$StartupDirs = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)
foreach ($dir in $StartupDirs) {
    if (Test-Path $dir) {
        Get-ChildItem $dir -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($cheat in $CheatNames) {
                if ($_.Name.ToLower() -match $cheat) {
                    Write-Color "  🔴  Cheat in startup: $($_.Name)" "Red"
                    Add-Finding "critical" "Startup Entry" "Matches '$cheat'" $_.FullName
                }
            }
        }
    }
}

$RunKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
)
foreach ($key in $RunKeys) {
    if (Test-Path $key) {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props) {
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                $name = $_.Name; $val = "$($_.Value)"
                foreach ($cheat in $CheatNames) {
                    if ($name.ToLower() -match $cheat -or $val.ToLower() -match $cheat) {
                        Write-Color "  🔴  Registry Run: $name" "Red"
                        Add-Finding "critical" "Registry Run" "'$name' matches '$cheat'" $val
                    }
                }
            }
        }
    }
}

Write-Color "  ✔  Startup check done" "Green"


Write-Section "7/7  —  Writing Report"

$ts       = Get-Date -Format "yyyyMMdd_HHmmss"
$txtPath  = Join-Path $OutputFolder "mc_scan_$ts.txt"
$jsonPath = Join-Path $OutputFolder "mc_scan_$ts.json"

$crits = @($Findings | Where-Object { $_.Severity -eq "critical" })
$warns = @($Findings | Where-Object { $_.Severity -eq "warning" })
$infos = @($Findings | Where-Object { $_.Severity -eq "info" })

$report = @()
$report += "=" * 70
$report += "  MC CHEAT SCANNER v3.0 — REPORT"
$report += "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "  $env:COMPUTERNAME / $env:USERNAME"
$report += "  Scanned folder: $McFolder"
$report += "=" * 70
$report += ""
$report += "  Total: $($Findings.Count)  |  Critical: $($crits.Count)  |  Warning: $($warns.Count)  |  Info: $($infos.Count)"
$report += ""

foreach ($group in @(("CRITICAL", $crits), ("WARNING", $warns), ("INFO", $infos))) {
    $label = $group[0]; $items = $group[1]
    if ($items.Count -gt 0) {
        $report += ""
        $report += "  $label"
        $report += "  " + ("─" * 50)
        foreach ($f in $items) {
            $report += "  [$($f.Time)]  $($f.Category) — $($f.Detail)"
            if ($f.Extra) { $report += "  $($f.Extra)" }
            $report += ""
        }
    }
}
$report += "=" * 70

$report | Out-File -FilePath $txtPath -Encoding UTF8

$jsonObj = @{
    time           = (Get-Date).ToString("o")
    host           = $env:COMPUTERNAME
    user           = $env:USERNAME
    scanned_folder = $McFolder
    summary        = @{ total = $Findings.Count; critical = $crits.Count; warning = $warns.Count; info = $infos.Count }
    findings       = $Findings
}
$jsonObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

Write-Color "  ✔  $txtPath" "Green"
Write-Color "  ✔  $jsonPath" "Green"


Write-Host ""
Write-Color ("─" * 60) "DarkGray"
Write-Color "  SCAN COMPLETE" "Cyan"
Write-Color ("─" * 60) "DarkGray"
Write-Color "  Total findings  : $($Findings.Count)" "White"
Write-Color "  Critical        : $($crits.Count)" $(if ($crits.Count -gt 0) { "Red" } else { "Green" })
Write-Color "  Warning         : $($warns.Count)" $(if ($warns.Count -gt 0) { "Yellow" } else { "Green" })
Write-Color "  Info            : $($infos.Count)" "Cyan"
Write-Host ""
Write-Color "  Report saved to: $OutputFolder" "DarkGray"
Write-Host ""

pause
