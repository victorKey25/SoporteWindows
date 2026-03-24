<#
KeyNetworks Diagnostic Tool v3.6
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
$users = Get-CimInstance Win32_UserProfile | Where { $_.Special -eq $false }

# Chrome
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeProfiles = if (Test-Path $chromePath) {
    Get-ChildItem $chromePath -Directory | Where { $_.Name -like "Profile*" -or $_.Name -eq "Default" }
}

# ==========================
# BLUETOOTH (REGISTRADOS)
# ==========================
$btDevices = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices" -ErrorAction SilentlyContinue |
ForEach-Object { $_.PSChildName }

# ==========================
# ARCHIVOS PESADOS
# ==========================
$heavyFiles = Get-ChildItem $env:USERPROFILE -Recurse -File -ErrorAction SilentlyContinue |
Sort Length -Descending | Select -First 10 FullName, @{Name="Size";Expression={[math]::Round($_.Length/1MB,2)}}

# ==========================
# ANÁLISIS
# ==========================
$issues = @()
$recommendations = @()

if ($usedRAMPercent -gt 80) {
    $issues += "RAM alta"
    $recommendations += "Ampliar RAM"
}

if ($diskUsagePercent -gt 85) {
    $issues += "Disco lleno"
    $recommendations += "Liberar espacio"
}

if ($diskType -eq "HDD") {
    $issues += "Disco HDD"
    $recommendations += "Migrar a SSD"
}

if ($cpuLoad -gt 80) {
    $issues += "CPU alta"
    $recommendations += "Optimizar procesos"
}

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

# ==========================
# HTML
# ==========================
@"
<html>
<body style='font-family:Arial;background:#f5f6fa;padding:20px;'>

<div style='background:#111;color:white;padding:20px;border-radius:10px;text-align:center;'>
<h1>KeyNetworks</h1>
<p>Reporte del sistema</p>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>📊 Score: $score / 100</h2>
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
<h2>👤 Usuarios</h2>
<ul>
$($users | ForEach-Object { "<li>$($_.LocalPath)</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>🌐 Chrome</h2>
<ul>
$($chromeProfiles | ForEach-Object { "<li>$($_.Name)</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>🔵 Bluetooth (registrados)</h2>
<ul>
$($btDevices | ForEach-Object { "<li>$_</li>" })
</ul>
</div>

<div style='background:white;padding:20px;margin-top:20px;border-radius:10px;'>
<h2>📂 Archivos pesados</h2>
<ul>
$($heavyFiles | ForEach-Object { "<li>$($_.FullName) - $($_.Size) MB</li>" })
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
