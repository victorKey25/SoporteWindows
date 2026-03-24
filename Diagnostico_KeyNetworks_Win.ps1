<#
.SYNOPSIS
KeyNetworks Diagnostic Tool - FULL (Auditoría + Inteligencia)

.VERSION
3.0

.AUTHOR
Victor Keymolen - KeyNetworks
#>

param (
    [string]$ReportPath = "$env:USERPROFILE\Desktop\WindowsDiagnostic"
)

$VERSION = "3.0"
$HTML_REPORT = "$ReportPath\report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null

# ==========================
# UI (ESTILO MAC)
# ==========================
function Show-Section($title) {
    Write-Host "`n=====================================" -ForegroundColor DarkGray
    Write-Host "🔹 $title" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor DarkGray
}

function OK($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function WARN($msg) { Write-Host "⚠️ $msg" -ForegroundColor Yellow }
function BAD($msg) { Write-Host "❌ $msg" -ForegroundColor Red }

function Format-Size {
    param([int64]$bytes)
    if ($bytes -ge 1TB) { "{0:N1} TB" -f ($bytes / 1TB) }
    elseif ($bytes -ge 1GB) { "{0:N1} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { "{0:N1} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { "{0:N1} KB" -f ($bytes / 1KB) }
    else { "$bytes B" }
}

# ==========================
# DATOS DEL SISTEMA
# ==========================
Show-Section "INICIANDO DIAGNÓSTICO KEYNETWORKS"

$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor

# CPU
Show-Section "CPU"
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
Write-Host "Modelo: $($cpu.Name)"
Write-Host "Uso: $([int]$cpuLoad)%"

# RAM
Show-Section "MEMORIA"
$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum | Select -Expand Sum
$freeMemory = $os.FreePhysicalMemory * 1KB
$usedRAMPercent = (($memory - $freeMemory) / $memory) * 100

Write-Host "Total: $([math]::Round($memory / 1GB,2)) GB"
Write-Host "Uso: $([int]$usedRAMPercent)%"

# DISCO
Show-Section "DISCO"
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskType = (Get-PhysicalDisk | Select -First 1).MediaType

Write-Host "Tipo: $diskType"
Write-Host "Uso: $([int]$diskUsagePercent)%"

# ==========================
# USUARIOS
# ==========================
Show-Section "USUARIOS"

$users = Get-CimInstance Win32_UserProfile | Where { $_.Special -eq $false }

foreach ($u in $users) {
    $name = $u.LocalPath.Split("\")[-1]
    $last = if ($u.LastUseTime) { ([datetime]$u.LastUseTime).ToString("yyyy-MM-dd") } else { "N/A" }
    Write-Host "$name - Último uso: $last"
}

# ==========================
# BLUETOOTH
# ==========================
Show-Section "BLUETOOTH"

$bluetooth = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where Status -eq "OK"
$bluetooth | Select FriendlyName, Status

# ==========================
# ERRORES
# ==========================
Show-Section "ERRORES RECIENTES"

$errors = Get-EventLog System -EntryType Error -Newest 10
$errors | Select TimeGenerated, Source

# ==========================
# POSIBLE MALWARE
# ==========================
Show-Section "PROCESOS SOSPECHOSOS"

$suspicious = Get-Process | Where {
    $_.Path -like "*AppData*" -or $_.Path -like "*Temp*"
} | Select Name, Path

$suspicious

# ==========================
# WINDOWS VERSION
# ==========================
Show-Section "WINDOWS"

Write-Host "$($os.Caption)"
Write-Host "Build: $($os.BuildNumber)"

# ==========================
# ANÁLISIS INTELIGENTE
# ==========================
Show-Section "ANÁLISIS"

$issues = @()
$recommendations = @()

if ($usedRAMPercent -gt 80) {
    BAD "RAM alta"
    $issues += "RAM saturada"
    $recommendations += "Ampliar RAM"
}

if ($diskType -eq "HDD") {
    BAD "HDD detectado"
    $issues += "Disco HDD"
    $recommendations += "Cambiar a SSD"
}

if ($diskUsagePercent -gt 85) {
    WARN "Disco lleno"
    $issues += "Disco lleno"
    $recommendations += "Liberar espacio"
}

if ($cpuLoad -gt 80) {
    WARN "CPU alta"
    $issues += "CPU alta"
    $recommendations += "Revisar procesos"
}

if ($os.Caption -match "Windows 10") {
    WARN "Sistema en Windows 10"
    $recommendations += "Actualizar a Windows 11"
}

if ($users.Count -gt 5) {
    WARN "Muchos usuarios"
    $issues += "Exceso de usuarios"
}

# SCORE
$score = 100
if ($usedRAMPercent -gt 80) { $score -= 20 }
if ($diskUsagePercent -gt 85) { $score -= 20 }
if ($cpuLoad -gt 80) { $score -= 20 }
if ($diskType -eq "HDD") { $score -= 30 }

if ($score -lt 0) { $score = 0 }

Show-Section "RESULTADO"
Write-Host "SCORE: $score / 100"

# ==========================
# HTML
# ==========================
@"
<html>
<body style='font-family:Arial'>
<h1>KeyNetworks Diagnostic</h1>

<h2>Score: $score / 100</h2>

<h3>Problemas</h3>
<ul>
$($issues | ForEach-Object { "<li>$_</li>" })
</ul>

<h3>Recomendaciones</h3>
<ul>
$($recommendations | ForEach-Object { "<li>$_</li>" })
</ul>

<h3>Windows</h3>
<p>$($os.Caption) - Build $($os.BuildNumber)</p>

<h3>Usuarios</h3>
<ul>
$($users | ForEach-Object {
    "<li>$($_.LocalPath)</li>"
})
</ul>

<h3>Bluetooth</h3>
<ul>
$($bluetooth | ForEach-Object {
    "<li>$($_.FriendlyName)</li>"
})
</ul>

<p>Contacto: soporte@keynetworks.mx</p>

</body>
</html>
"@ | Out-File $HTML_REPORT

Write-Host "`nReporte generado: $HTML_REPORT" -ForegroundColor Green
Invoke-Item $HTML_REPORT
