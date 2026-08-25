# =============================================================================
#  N I G H T D R I V E
#  A PowerShell theme for Windows Terminal
#  Palette: deep-space base, cyan -> violet -> magenta accents
# =============================================================================

if ($Host.Name -eq 'Windows PowerShell ISE Host') { return }

$script:ESC = [char]27
$script:RST = "$([char]27)[0m"
$script:BLD = "$([char]27)[1m"

# ---------------------------------------------------------------- palette ---
$script:Pal = [ordered]@{
    Fg        = '#C9D1E1'
    Dim       = '#5A6480'
    Faint     = '#39415A'
    White     = '#F0F4FC'
    Cyan      = '#4DE8E0'
    Blue      = '#5AA9FF'
    Violet    = '#C792EA'
    Magenta   = '#FF6FD8'
    Green     = '#5CE6A6'
    Yellow    = '#FFD166'
    Orange    = '#FF9F5A'
    Red       = '#FF5C7A'
    # segment backgrounds
    BgUser    = '#1B2B45'
    BgPath    = '#2A2140'
    BgGitOk   = '#123A2C'
    BgGitDirt = '#3D3417'
    BgNode    = '#10331F'
    BgPy      = '#1E2E45'
    BgAdmin   = '#4A1226'
    BgMeta    = '#161B26'
}

function script:Rgb([string]$hex) {
    $h = $hex.TrimStart('#')
    ,@([Convert]::ToInt32($h.Substring(0,2),16),
       [Convert]::ToInt32($h.Substring(2,2),16),
       [Convert]::ToInt32($h.Substring(4,2),16))
}
function script:Fg([string]$hex) { $c = Rgb $hex; "$($script:ESC)[38;2;$($c[0]);$($c[1]);$($c[2])m" }
function script:Bg([string]$hex) { $c = Rgb $hex; "$($script:ESC)[48;2;$($c[0]);$($c[1]);$($c[2])m" }

# Precompute escape sequences so the prompt stays cheap.
# NB: PowerShell variables are case-insensitive, so a loop variable named $k
# would silently clobber a script variable named $K. Hence the long names.
$script:FGC = @{}
foreach ($key in $script:Pal.Keys) {
    $script:FGC[$key] = Fg $script:Pal[$key]
}

# ------------------------------------------------------------ nerd glyphs ---
function script:Test-NerdFont {
    $names = @()
    foreach ($p in @('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                     'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        $i = Get-ItemProperty $p -ErrorAction SilentlyContinue
        if ($i) { $names += $i.PSObject.Properties.Name }
    }
    return [bool]($names -match 'NF|Nerd Font')
}

$script:NF = ($null -ne $env:WT_SESSION) -and (Test-NerdFont)

if ($script:NF) {
    $script:GLY = @{
        Sep    = [char]0xE0B0   # solid right chevron
        Thin   = [char]0xE0B1   # thin right chevron
        Branch = [char]0xE0A0   # git branch
        Arrow  = [char]0x276F   # heavy right angle quote
        Node   = [char]0xE718
        Py     = [char]0xE73C
        Lock   = [char]0xE0A2
    }
} else {
    $script:GLY = @{
        Sep    = [char]0x25B6   # geometric triangle (any mono font)
        Thin   = [char]0x203A
        Branch = [char]0x00A7
        Arrow  = [char]0x003E
        Node   = 'node'
        Py     = 'py'
        Lock   = '!'
    }
}

# glyphs present in essentially every monospace font - no Nerd Font required
$script:Box = @{
    TL=[char]0x256D; TR=[char]0x256E; BL=[char]0x2570; BR=[char]0x256F
    H=[char]0x2500;  V=[char]0x2502
    Full=[char]0x2588; Light=[char]0x2591
    Dot=[char]0x25CF; Up=[char]0x2191; Down=[char]0x2193
    Check=[char]0x2713; Cross=[char]0x2717; Ell=[char]0x2026
}

# =============================================================================
#  PROMPT
# =============================================================================

function script:Shorten-Path([string]$full) {
    $home_ = $HOME.TrimEnd('\')
    if ($full -eq $home_) { return '~' }
    if ($full.StartsWith($home_ + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $full = '~\' + $full.Substring($home_.Length + 1)
    }
    $parts = $full -split '\\'
    if ($parts.Count -le 4) { return $full }
    return ($parts[0], $script:Box.Ell, $parts[-2], $parts[-1]) -join '\'
}

function script:Get-GitSegment {
    if (-not $script:HasGit) { return $null }
    $raw = & git status --porcelain=v1 -b --ignore-submodules 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }

    $lines  = @($raw)
    $header = $lines[0]
    $branch = 'detached'
    $ahead  = 0
    $behind = 0

    if ($header -match '^##\s+(?<b>[^\s\.]+)') { $branch = $Matches['b'] }
    if ($header -match 'ahead (?<n>\d+)')      { $ahead  = [int]$Matches['n'] }
    if ($header -match 'behind (?<n>\d+)')     { $behind = [int]$Matches['n'] }

    $staged = 0; $mod = 0; $untracked = 0; $conflict = 0
    if ($lines.Count -gt 1) {
        foreach ($l in $lines[1..($lines.Count-1)]) {
            if ($null -eq $l -or $l.Length -lt 2) { continue }
            $x = $l[0]; $y = $l[1]
            if ($x -eq '?' -and $y -eq '?') { $untracked++; continue }
            if ($x -eq 'U' -or $y -eq 'U')  { $conflict++;  continue }
            if ($x -ne ' ') { $staged++ }
            if ($y -ne ' ') { $mod++ }
        }
    }

    $bits = @()
    if ($ahead)     { $bits += "$($script:Box.Up)$ahead" }
    if ($behind)    { $bits += "$($script:Box.Down)$behind" }
    if ($staged)    { $bits += "+$staged" }
    if ($mod)       { $bits += "~$mod" }
    if ($untracked) { $bits += "?$untracked" }
    if ($conflict)  { $bits += "!$conflict" }

    $clean = ($staged + $mod + $untracked + $conflict) -eq 0
    $text  = "$($script:GLY.Branch) $branch"
    if ($bits.Count) { $text += ' ' + ($bits -join ' ') }
    if ($clean)      { $text += " $($script:Box.Check)" }

    return @{
        Text = $text
        Fg   = $(if ($clean) { $script:Pal.Green }    else { $script:Pal.Yellow })
        Bg   = $(if ($clean) { $script:Pal.BgGitOk }  else { $script:Pal.BgGitDirt })
    }
}

function script:Render-Segments([object[]]$segs) {
    # returns @{ Text = <ansi>; Len = <visible columns> }
    $sb  = New-Object System.Text.StringBuilder
    $len = 0
    for ($i = 0; $i -lt $segs.Count; $i++) {
        $s = $segs[$i]
        [void]$sb.Append((Bg $s.Bg)).Append((Fg $s.Fg)).Append(' ').Append($s.Text).Append(' ')
        $len += $s.Text.Length + 2

        $next = $null
        if ($i -lt $segs.Count - 1) { $next = $segs[$i+1].Bg }

        [void]$sb.Append($script:RST).Append((Fg $s.Bg))
        if ($next) { [void]$sb.Append((Bg $next)) }
        [void]$sb.Append($script:GLY.Sep).Append($script:RST)
        $len += 1
    }
    return @{ Text = $sb.ToString(); Len = $len }
}

function global:prompt {
    $ok      = $?
    $exit    = $global:LASTEXITCODE
    $cwd     = (Get-Location).Path

    # ---- left side ----------------------------------------------------------
    $segs = New-Object System.Collections.ArrayList

    if ($script:IsAdmin) {
        [void]$segs.Add(@{ Text = "$($script:GLY.Lock) ADMIN"; Fg = $script:Pal.Red; Bg = $script:Pal.BgAdmin })
    }

    [void]$segs.Add(@{
        Text = "$env:USERNAME@$env:COMPUTERNAME"
        Fg   = $script:Pal.Blue
        Bg   = $script:Pal.BgUser
    })

    [void]$segs.Add(@{
        Text = (Shorten-Path $cwd)
        Fg   = $script:Pal.Violet
        Bg   = $script:Pal.BgPath
    })

    $git = $null
    try { $git = Get-GitSegment } catch { }
    if ($git) { [void]$segs.Add($git) }

    if (Test-Path -LiteralPath (Join-Path $cwd 'package.json')) {
        $nv = $script:NodeVersion
        if ($nv) {
            [void]$segs.Add(@{ Text = "$($script:GLY.Node) $nv"; Fg = $script:Pal.Green; Bg = $script:Pal.BgNode })
        }
    }

    if ($env:VIRTUAL_ENV) {
        [void]$segs.Add(@{
            Text = "$($script:GLY.Py) $(Split-Path $env:VIRTUAL_ENV -Leaf)"
            Fg   = $script:Pal.Cyan
            Bg   = $script:Pal.BgPy
        })
    }

    $left = Render-Segments $segs.ToArray()

    # ---- right side ---------------------------------------------------------
    $rbits  = @()
    $rplain = @()

    $h = Get-History -Count 1 -ErrorAction SilentlyContinue
    if ($h -and $h.EndExecutionTime -and $h.StartExecutionTime) {
        $ms = ($h.EndExecutionTime - $h.StartExecutionTime).TotalMilliseconds
        if ($ms -ge 200) {
            $d = if ($ms -ge 60000) { '{0:n1}m' -f ($ms/60000) }
                 elseif ($ms -ge 1000) { '{0:n1}s' -f ($ms/1000) }
                 else { '{0:n0}ms' -f $ms }
            $rbits  += "$($script:FGC.Orange)$d$($script:RST)"
            $rplain += $d
        }
    }

    if (-not $ok -or ($null -ne $exit -and $exit -ne 0)) {
        $code = if ($null -ne $exit -and $exit -ne 0) { $exit } else { '1' }
        $t = "$($script:Box.Cross) $code"
        $rbits  += "$($script:FGC.Red)$t$($script:RST)"
        $rplain += $t
    }

    $clock = (Get-Date).ToString('HH:mm:ss')
    $rbits  += "$($script:FGC.Dim)$clock$($script:RST)"
    $rplain += $clock

    $right    = $rbits -join "$($script:FGC.Faint) $($script:GLY.Thin) $($script:RST)"
    $rightLen = ($rplain -join '   ').Length

    # ---- assemble -----------------------------------------------------------
    $width = 120
    try { $width = $Host.UI.RawUI.WindowSize.Width } catch { }

    $head = "$($script:FGC.Faint)$($script:Box.TL)$($script:Box.H)$($script:RST)"
    $fill = $width - 2 - $left.Len - $rightLen - 2
    $line1 = $head + $left.Text
    if ($fill -gt 1) {
        $line1 += "$($script:FGC.Faint)" + ($script:Box.H.ToString() * $fill) + "$($script:RST) " + $right
    }

    $acol = if ($ok -and ($null -eq $exit -or $exit -eq 0)) { $script:FGC.Cyan } else { $script:FGC.Red }
    $line2 = "$($script:FGC.Faint)$($script:Box.BL)$($script:Box.H)$($script:RST)$acol$($script:BLD)$($script:GLY.Arrow)$($script:RST) "

    try { $Host.UI.RawUI.WindowTitle = "$(Shorten-Path $cwd)  -  PowerShell" } catch { }

    $global:LASTEXITCODE = 0
    return "`n$line1`n$line2"
}

# =============================================================================
#  BANNER
# =============================================================================

$script:Glyphs = @{
    'N' = @('#   #','##  #','# # #','#  ##','#   #')
    'I' = @('#####','  #  ','  #  ','  #  ','#####')
    'G' = @(' ### ','#    ','#  ##','#   #',' ### ')
    'H' = @('#   #','#   #','#####','#   #','#   #')
    'T' = @('#####','  #  ','  #  ','  #  ','  #  ')
    'D' = @('#### ','#   #','#   #','#   #','#### ')
    'R' = @('#### ','#   #','#### ','#  # ','#   #')
    'V' = @('#   #','#   #','#   #',' # # ','  #  ')
    'E' = @('#####','#    ','#### ','#    ','#####')
}

function script:Lerp([string]$a, [string]$b, [double]$t) {
    $ca = Rgb $a; $cb = Rgb $b
    $r = [int]($ca[0] + ($cb[0] - $ca[0]) * $t)
    $g = [int]($ca[1] + ($cb[1] - $ca[1]) * $t)
    $bl= [int]($ca[2] + ($cb[2] - $ca[2]) * $t)
    return "$($script:ESC)[38;2;$r;$g;${bl}m"
}

function script:Gradient([double]$t, [string[]]$stops) {
    if ($t -le 0) { return Fg $stops[0] }
    if ($t -ge 1) { return Fg $stops[-1] }
    $n    = $stops.Count - 1
    $seg  = [Math]::Min([int]($t * $n), $n - 1)
    $localT = ($t * $n) - $seg
    return Lerp $stops[$seg] $stops[$seg+1] $localT
}

function script:Write-Logo([string]$word) {
    $stops = @($script:Pal.Cyan, $script:Pal.Blue, $script:Pal.Violet, $script:Pal.Magenta)
    $rows  = @('','','','','')
    foreach ($ch in $word.ToCharArray()) {
        $g = $script:Glyphs["$ch"]
        for ($r = 0; $r -lt 5; $r++) { $rows[$r] += $g[$r] + ' ' }
    }
    $w = $rows[0].Length
    foreach ($row in $rows) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('  ')
        for ($x = 0; $x -lt $row.Length; $x++) {
            if ($row[$x] -eq '#') {
                [void]$sb.Append((Gradient ($x / [double]$w) $stops)).Append($script:Box.Full)
            } else {
                [void]$sb.Append(' ')
            }
        }
        [void]$sb.Append($script:RST)
        Write-Host $sb.ToString()
    }
}

function script:Bar([double]$pct, [int]$len) {
    $filled = [int][Math]::Round($len * ($pct / 100.0))
    if ($filled -gt $len) { $filled = $len }
    if ($filled -lt 0)    { $filled = 0 }
    $col = if ($pct -ge 85) { $script:FGC.Red } elseif ($pct -ge 60) { $script:FGC.Yellow } else { $script:FGC.Green }
    $s = $col + ($script:Box.Full.ToString() * $filled) +
         $script:FGC.Faint + ($script:Box.Light.ToString() * ($len - $filled)) + $script:RST
    return @{ Text = $s; Len = $len }
}

$script:BoxW = 66

function script:BTop([string]$title) {
    $t = " $title "
    $rest = $script:BoxW - 3 - $t.Length
    Write-Host ("  $($script:FGC.Faint)$($script:Box.TL)$($script:Box.H)$($script:RST)" +
                "$($script:FGC.Cyan)$($script:BLD)$t$($script:RST)" +
                "$($script:FGC.Faint)" + ($script:Box.H.ToString() * $rest) + "$($script:Box.TR)$($script:RST)")
}
function script:BBot {
    Write-Host ("  $($script:FGC.Faint)$($script:Box.BL)" + ($script:Box.H.ToString() * ($script:BoxW - 2)) + "$($script:Box.BR)$($script:RST)")
}
function script:BRow([string]$label, [string]$value, [string]$colorHex, [object]$prefix = $null) {
    if ($null -eq $colorHex) { $colorHex = $script:Pal.Fg }
    # 9-wide label column; a longer label still keeps one separating space
    $lab = if ($label.Length -ge 9) { $label + ' ' } else { $label.PadRight(9) }
    $body  = ''
    $plain = ''
    if ($prefix) { $body += $prefix.Text + ' '; $plain += (' ' * $prefix.Len) + ' ' }
    $body  += (Fg $colorHex) + $value + $script:RST
    $plain += $value
    $pad   = $script:BoxW - 4 - $lab.Length - $plain.Length
    if ($pad -lt 0) {
        $over = -$pad
        # value too long: trim it
        $value = $value.Substring(0, [Math]::Max(0, $value.Length - $over - 1)) + $script:Box.Ell
        BRow $label $value $colorHex $prefix
        return
    }
    Write-Host ("  $($script:FGC.Faint)$($script:Box.V)$($script:RST)  " +
                "$($script:FGC.Dim)$lab$($script:RST)" + $body + (' ' * $pad) +
                "$($script:FGC.Faint)$($script:Box.V)$($script:RST)")
}

function script:Get-GpuName {
    try {
        $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        foreach ($k in (Get-ChildItem $base -ErrorAction SilentlyContinue)) {
            $d = (Get-ItemProperty $k.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc
            if ($d) { return $d }
        }
    } catch { }
    try { return (Get-CimInstance Win32_VideoController -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Name) } catch { }
    return 'unknown'
}

function global:Show-Nightdrive {
    Write-Host ''
    try { Write-Logo 'NIGHTDRIVE' } catch { Write-Host "  NIGHTDRIVE" -ForegroundColor Cyan }

    $sub = "  dev workstation  $($script:GLY.Thin)  $env:COMPUTERNAME  $($script:GLY.Thin)  $((Get-Date).ToString('ddd dd MMM yyyy  HH:mm'))"
    Write-Host "$($script:FGC.Dim)$sub$($script:RST)`n"

    # ---- system -------------------------------------------------------------
    try {
        $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cpu  = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $disk = Get-PSDrive C -ErrorAction Stop

        $ramTotal = $os.TotalVisibleMemorySize / 1MB
        $ramFree  = $os.FreePhysicalMemory / 1MB
        $ramUsed  = $ramTotal - $ramFree
        $ramPct   = ($ramUsed / $ramTotal) * 100

        $dTotal = ($disk.Used + $disk.Free) / 1GB
        $dUsed  = $disk.Used / 1GB
        $dPct   = ($dUsed / $dTotal) * 100

        $up = (Get-Date) - $os.LastBootUpTime
        $upStr = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes

        BTop 'SYSTEM'
        BRow 'os'   "$($os.Caption.Replace('Microsoft ','')) $($os.Version)" $script:Pal.White
        BRow 'cpu'  "$($cpu.Name.Trim())" $script:Pal.Fg
        BRow 'cores' "$($cpu.NumberOfCores)C / $($cpu.NumberOfLogicalProcessors)T  @ $([math]::Round($cpu.MaxClockSpeed/1000,2)) GHz" $script:Pal.Fg
        BRow 'gpu'  (Get-GpuName) $script:Pal.Fg
        BRow 'ram'  ('{0:n1} / {1:n1} GB   {2:n0}%' -f $ramUsed, $ramTotal, $ramPct) $script:Pal.Fg (Bar $ramPct 18)
        BRow 'disk' ('{0:n0} / {1:n0} GB   {2:n0}%' -f $dUsed, $dTotal, $dPct) $script:Pal.Fg (Bar $dPct 18)
        BRow 'uptime' $upStr $script:Pal.Fg
        BBot
    } catch {
        Write-Host "  (system probe unavailable)" -ForegroundColor DarkGray
    }

    # ---- network ------------------------------------------------------------
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
               Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
               Select-Object -First 1)
        BTop 'NETWORK'
        BRow 'lan' "$($ip.IPAddress)/$($ip.PrefixLength)  on  $($ip.InterfaceAlias)" $script:Pal.Cyan
        BBot
    } catch { }

    # ---- toolchain ----------------------------------------------------------
    BTop 'TOOLCHAIN'
    foreach ($t in @(
        @{ n='git';    c='git';    a='--version' },
        @{ n='node';   c='node';   a='--version' },
        @{ n='npm';    c='npm';    a='--version' },
        @{ n='python'; c='python'; a='--version' },
        @{ n='claude'; c='claude'; a='--version' }
    )) {
        $cmd = Get-Command $t.c -ErrorAction SilentlyContinue
        $v   = $null
        if ($cmd) { try { $v = (& $t.c $t.a 2>$null | Select-Object -First 1) } catch { } }

        # a Store "app execution alias" stub resolves but yields no version
        $real = $cmd -and ($v -or $cmd.Source -notlike '*\WindowsApps\*')

        if ($real) {
            if (-not $v) { $v = 'installed' }
            $v = ($v -replace '^git version ', '' -replace '^Python ', '').Trim()
            BRow $t.n $v $script:Pal.Green (@{ Text = "$($script:FGC.Green)$($script:Box.Dot)$($script:RST)"; Len = 1 })
        } else {
            BRow $t.n 'not installed' $script:Pal.Faint (@{ Text = "$($script:FGC.Faint)$($script:Box.Dot)$($script:RST)"; Len = 1 })
        }
    }
    BBot

    Write-Host "$($script:FGC.Faint)   type $($script:RST)$($script:FGC.Violet)help-me$($script:RST)$($script:FGC.Faint) for the custom commands in this profile$($script:RST)`n"
}

# =============================================================================
#  QUALITY OF LIFE
# =============================================================================

function global:.. { Set-Location .. }
function global:... { Set-Location ..\.. }
function global:.... { Set-Location ..\..\.. }

function global:mkcd { param([Parameter(Mandatory)][string]$Path) New-Item -ItemType Directory -Force $Path | Out-Null; Set-Location $Path }
function global:touch { param([Parameter(Mandatory)][string]$Path) if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date } else { New-Item -ItemType File $Path | Out-Null } }
function global:which { param([Parameter(Mandatory)][string]$Name) (Get-Command $Name -ErrorAction SilentlyContinue).Source }
function global:reload { . $PROFILE.CurrentUserAllHosts; Write-Host "profile reloaded" -ForegroundColor Green }
function global:sysinfo { Show-Nightdrive }

# git shorthands
function global:gs  { & git status -sb @args }
function global:ga  { & git add @args }
function global:gc_ { & git commit @args }
function global:gp  { & git push @args }
function global:gl  { & git log --oneline --graph --decorate -20 @args }
function global:gd  { & git diff @args }
function global:gco { & git checkout @args }
function global:gb  { & git branch @args }

# ---- colourised listing -----------------------------------------------------
$script:ExtColor = @{
    '.ps1'='Yellow'; '.psm1'='Yellow'; '.bat'='Yellow'; '.cmd'='Yellow'; '.sh'='Yellow'
    '.exe'='Green';  '.msi'='Green';   '.dll'='Faint'
    '.json'='Orange';'.yml'='Orange';  '.yaml'='Orange'; '.toml'='Orange'; '.xml'='Orange'; '.ini'='Orange'
    '.md'='Cyan';    '.txt'='Fg';      '.log'='Dim'
    '.js'='Yellow';  '.ts'='Blue';     '.jsx'='Yellow';  '.tsx'='Blue'
    '.py'='Blue';    '.rs'='Orange';   '.go'='Cyan';     '.c'='Blue'; '.cpp'='Blue'; '.cs'='Violet'
    '.zip'='Magenta';'.7z'='Magenta';  '.rar'='Magenta'; '.gz'='Magenta'
    '.png'='Violet'; '.jpg'='Violet';  '.jpeg'='Violet'; '.gif'='Violet'; '.svg'='Violet'; '.mp4'='Violet'
}

function global:ll {
    [CmdletBinding()]
    param([string]$Path = '.')

    $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
             Sort-Object @{ E = { -not $_.PSIsContainer } }, Name
    if (-not $items) { Write-Host "  (empty)" -ForegroundColor DarkGray; return }

    Write-Host ''
    # column widths must match the row format below: 6 + 9 + 2 + 18
    Write-Host ("  $($script:FGC.Dim)" + 'mode'.PadRight(6) + 'size'.PadLeft(9) + '  ' +
                'modified'.PadRight(18) + 'name' + $script:RST)
    Write-Host ("  $($script:FGC.Faint)" + ($script:Box.H.ToString() * 60) + $script:RST)

    foreach ($i in $items) {
        $isDir = $i.PSIsContainer
        $mode  = if ($isDir) { 'd' } else { '-' }
        $mode += if ($i.Attributes -band [IO.FileAttributes]::Hidden)   { 'h' } else { '-' }
        $mode += if ($i.Attributes -band [IO.FileAttributes]::System)   { 's' } else { '-' }
        $mode += if ($i.Attributes -band [IO.FileAttributes]::ReadOnly) { 'r' } else { '-' }
        $mode += if ($i.Attributes -band [IO.FileAttributes]::Archive)  { 'a' } else { '-' }

        if ($isDir) {
            $size = '-'
        } elseif ($i.Length -ge 1GB) { $size = '{0:n1}G' -f ($i.Length/1GB) }
          elseif ($i.Length -ge 1MB) { $size = '{0:n1}M' -f ($i.Length/1MB) }
          elseif ($i.Length -ge 1KB) { $size = '{0:n1}K' -f ($i.Length/1KB) }
          else                       { $size = "$($i.Length)B" }

        $when = $i.LastWriteTime.ToString('yyyy-MM-dd HH:mm')

        if ($isDir) {
            $nameCol = $script:FGC.Blue + $script:BLD
            $name    = $i.Name + '\'
        } else {
            $key = $script:ExtColor[$i.Extension.ToLower()]
            if (-not $key) { $key = 'Fg' }
            $nameCol = $script:FGC[$key]
            $name    = $i.Name
        }

        Write-Host ("  $($script:FGC.Faint)$mode$($script:RST) " +
                    "$($script:FGC.Dim)$($size.PadLeft(9))$($script:RST)  " +
                    "$($script:FGC.Faint)$($when.PadRight(18))$($script:RST)" +
                    "$nameCol$name$($script:RST)")
    }
    Write-Host ''
}

function global:la { ll @args }

function global:help-me {
    Write-Host ''
    BTop 'NIGHTDRIVE COMMANDS'
    BRow 'sysinfo' 'redraw the startup dashboard' $script:Pal.Fg
    BRow 'll / la' 'colourised directory listing' $script:Pal.Fg
    BRow 'reload'  'reload this profile in place' $script:Pal.Fg
    BRow 'mkcd'    'mkdir + cd in one step' $script:Pal.Fg
    BRow 'touch'   'create / bump a file timestamp' $script:Pal.Fg
    BRow 'which'   'resolve a command to its path' $script:Pal.Fg
    BRow '.. ...'  'jump up 2 or 3 directories' $script:Pal.Fg
    BRow 'gs ga gp' 'git status / add / push' $script:Pal.Fg
    BRow 'gl gd'    'git log graph / diff' $script:Pal.Fg
    BRow 'gco gb'   'git checkout / branch' $script:Pal.Fg
    BBot
    Write-Host ''
}

# =============================================================================
#  PSREADLINE
# =============================================================================

if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    $prl = (Get-Module PSReadLine).Version

    # pass raw VT sequences - accepted by every PSReadLine 2.x
    Set-PSReadLineOption -Colors @{
        Command            = $script:FGC.Cyan
        Parameter          = $script:FGC.Violet
        Operator           = $script:FGC.Magenta
        Variable           = $script:FGC.Blue
        String             = $script:FGC.Green
        Number             = $script:FGC.Orange
        Type               = $script:FGC.Yellow
        Comment            = $script:FGC.Faint
        Keyword            = $script:FGC.Magenta
        Error              = $script:FGC.Red
        ContinuationPrompt = $script:FGC.Faint
        Default            = $script:FGC.Fg
    } -ErrorAction SilentlyContinue

    Set-PSReadLineOption -ExtraPromptLineCount 2 -ErrorAction SilentlyContinue
    Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
    Set-PSReadLineOption -HistoryNoDuplicates:$true -ErrorAction SilentlyContinue
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd:$true -ErrorAction SilentlyContinue

    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+d    -Function DeleteCharOrExit

    if ($prl -ge [version]'2.1.0') {
        Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
        Set-PSReadLineKeyHandler -Key Ctrl+f -Function ForwardWord
    }
}

# =============================================================================
#  BOOT
# =============================================================================

$script:IsAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $script:IsAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

$script:HasGit      = [bool](Get-Command git -ErrorAction SilentlyContinue)
$script:NodeVersion = $null
if (Get-Command node -ErrorAction SilentlyContinue) {
    try { $script:NodeVersion = (& node --version 2>$null) } catch { }
}

# UTF-8 everywhere so the glyphs survive
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

if (-not $env:NIGHTDRIVE_QUIET) { Show-Nightdrive }
