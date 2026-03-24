<#
KeyNetworks Diagnostic Tool v4
#>

param (
    [string]$ReportPath = "$env:USERPROFILE\Desktop\WindowsDiagnostic"
)

$HTML_REPORT = "$ReportPath\report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null

function Show-Section($title) {
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "🔹 $title" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
}

# ==========================
# DATOS BASE
# ==========================
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem

# RAM
$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum | Select -Expand Sum
$freeMemory = $os.FreePhysicalMemory * 1KB
$usedRAMPercent = (($memory - $freeMemory) / $memory) * 100

# DISCO
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskType = (Get-PhysicalDisk | Select -First 1).MediaType

# CPU
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

# Usuarios
$users = Get-CimInstance Win32_UserProfile | Where-Object { $_.Special -eq $false }

# ==========================
# CHROME (NOMBRE + CORREO)
# ==========================
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeProfilesData = @()

if (Test-Path $chromePath) {
    $profiles = Get-ChildItem $chromePath -Directory | Where-Object {
        $_.Name -like "Profile*" -or $_.Name -eq "Default"
    }

    foreach ($p in $profiles) {
        $prefFile = "$($p.FullName)\Preferences"

        if (Test-Path $prefFile) {
            try {
                $json = Get-Content $prefFile -Raw | ConvertFrom-Json
                $name = $json.profile.name
                $email = $json.account_info[0].email

                if (-not $name) { $name = $p.Name }
                if (-not $email) { $email = "Sin correo" }

                $chromeProfilesData += @{
                    Name = $name
                    Email = $email
                }
            } catch {}
        }
    }
}

# ==========================
# BLUETOOTH (NOMBRE REAL)
# ==========================
$btDevices = @()
$btRegistry = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices" -ErrorAction SilentlyContinue

foreach ($device in $btRegistry) {
    try {
        $props = Get-ItemProperty $device.PSPath
        $name = $props.Name
        if (-not $name) { $name = $device.PSChildName }

        $btDevices += $name
    } catch {
        $btDevices += $device.PSChildName
    }
}

# ==========================
# ARCHIVOS PESADOS
# ==========================
$heavyFiles = Get-ChildItem $env:USERPROFILE -Recurse -File -ErrorAction SilentlyContinue |
Sort Length -Descending | Select -First 10 FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}}

# ==========================
# ANÁLISIS
# ==========================
$issues = @()
$recommendations = @()
$scoreDetails = @()

if ($usedRAMPercent -gt 80) {
    $issues += "RAM alta"
    $recommendations += "Ampliar RAM"
    $scoreDetails += "❌ RAM alta"
} else { $scoreDetails += "✔ RAM OK" }

if ($diskType -eq "HDD") {
    $issues += "Disco HDD"
    $recommendations += "Migrar a SSD"
    $scoreDetails += "❌ HDD detectado"
} else { $scoreDetails += "✔ SSD detectado" }

if ($diskUsagePercent -gt 85) {
    $issues += "Disco lleno"
    $recommendations += "Liberar espacio"
    $scoreDetails += "⚠ Disco lleno"
} else { $scoreDetails += "✔ Disco OK" }

if ($cpuLoad -gt 80) {
    $issues += "CPU alta"
    $recommendations += "Optimizar procesos"
    $scoreDetails += "⚠ CPU alta"
} else { $scoreDetails += "✔ CPU estable" }

if ($issues.Count -eq 0) {
    $issues += "Equipo en buen estado"
    $recommendations += "No se requieren acciones inmediatas"
}

# SCORE
$score = 100
if ($usedRAMPercent -gt 80) { $score -= 20 }
if ($diskUsagePercent -gt 85) { $score -= 20 }
if ($cpuLoad -gt 80) { $score -= 20 }
if ($diskType -eq "HDD") { $score -= 30 }
if ($score -lt 0) { $score = 0 }

# ==========================
# HTML
# ==========================
@"
<html>
<body style='font-family:Arial;background:#f5f6fa;padding:20px;'>

<div style='background:#111;color:white;padding:20px;border-radius:10px;text-align:center;'>
<h1>KeyNetworks</h1>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>📊 Score: $score / 100</h2>
<ul>
$($scoreDetails | ForEach-Object { "<li>$_</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>🖥️ Sistema</h2>
<p>$($os.Caption)</p>
<p>$($computer.Model)</p>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>💾 Memoria</h2>
<p>RAM: $([math]::Round($memory/1GB,2)) GB ($([int]$usedRAMPercent)% uso)</p>
<p>Disco: $diskType ($([int]$diskUsagePercent)% uso)</p>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>🌐 Chrome</h2>
<ul>
$($chromeProfilesData | ForEach-Object { "<li>$($_.Name) - $($_.Email)</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>🔵 Bluetooth</h2>
<ul>
$($btDevices | ForEach-Object { "<li>$_</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>📂 Archivos pesados</h2>
<ul>
$($heavyFiles | ForEach-Object { "<li>$($_.FullName) - $($_.SizeMB) MB</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>🚨 Análisis</h2>
<ul>
$($issues | ForEach-Object { "<li>$_</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>💡 Recomendaciones</h2>
<ul>
$($recommendations | ForEach-Object { "<li>$_</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>📩 Contacto</h2>
<p>contacto@keynetworks.com.mx</p>
</div>

</body>
</html>
"@ | Out-File $HTML_REPORT -Encoding UTF8

Invoke-Item $HTML_REPORT
