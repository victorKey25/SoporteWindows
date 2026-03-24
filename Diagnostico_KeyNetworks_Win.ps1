<#
.SYNOPSIS
KeyNetworks Diagnostic Tool - FULL UX + AI

.VERSION
3.5

.AUTHOR
Victor Keymolen - KeyNetworks
#>

param (
    [string]$ReportPath = "$env:USERPROFILE\Desktop\WindowsDiagnostic"
)

$VERSION = "3.5"
$HTML_REPORT = "$ReportPath\report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null

# ==========================
# UI (ESTILO MAC)
# ==========================
function Show-Section($title) {
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "🔹 $title" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
}

function OK($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function WARN($msg) { Write-Host "⚠️ $msg" -ForegroundColor Yellow }
function BAD($msg) { Write-Host "❌ $msg" -ForegroundColor Red }

# ==========================
# DATOS BASE
# ==========================
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor

$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum | Select -Expand Sum
$freeMemory = $os.FreePhysicalMemory * 1KB
$usedRAMPercent = (($memory - $freeMemory) / $memory) * 100

$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskType = (Get-PhysicalDisk | Select -First 1).MediaType

$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

# Usuarios
$users = Get-CimInstance Win32_UserProfile | Where-Object { $_.Special -eq $false }

# Chrome
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeProfiles = @()
if (Test-Path $chromePath) {
    $chromeProfiles = Get-ChildItem $chromePath -Directory | Where-Object { $_.Name -like "Profile*" -or $_.Name -eq "Default" }
}

# Bluetooth
$bluetooth = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "OK" }

# ==========================
# RESUMEN EJECUTIVO
# ==========================
Show-Section "RESUMEN EJECUTIVO"

Write-Host "🖥️ Sistema:"
Write-Host "$($os.Caption) - Build $($os.BuildNumber)"
Write-Host "$($computer.Manufacturer) $($computer.Model)"

Write-Host "`n👤 Usuarios:"
$users | ForEach-Object { Write-Host "- $($_.LocalPath.Split('\')[-1])" }

Write-Host "`n🌐 Chrome:"
if ($chromeProfiles) {
    $chromeProfiles | ForEach-Object { Write-Host "- $($_.Name)" }
} else { Write-Host "No detectado" }

Write-Host "`n🔵 Bluetooth:"
if ($bluetooth) {
    $bluetooth | ForEach-Object { Write-Host "- $($_.FriendlyName)" }
} else { Write-Host "Sin dispositivos" }

Write-Host "`n💾 Memoria:"
Write-Host "$([math]::Round($memory / 1GB,2)) GB - Uso $([int]$usedRAMPercent)%"

# ==========================
# ANÁLISIS INTELIGENTE
# ==========================
Show-Section "ANÁLISIS INTELIGENTE"

$issues = @()
$recommendations = @()

if ($usedRAMPercent -gt 80) {
    BAD "RAM alta"
    $issues += "RAM saturada"
    $recommendations += "Ampliar RAM a 16GB o más"
} else { OK "RAM estable" }

if ($diskType -eq "HDD") {
    BAD "HDD detectado"
    $issues += "Disco HDD"
    $recommendations += "Migrar a SSD"
} else { OK "SSD detectado" }

if ($diskUsagePercent -gt 85) {
    WARN "Disco lleno"
    $issues += "Disco lleno"
    $recommendations += "Liberar espacio"
}

if ($cpuLoad -gt 80) {
    WARN "CPU alta"
    $issues += "CPU alta"
    $recommendations += "Optimizar procesos"
}

if ($os.Caption -match "Windows 10") {
    WARN "Windows 10 detectado"
    $recommendations += "Evaluar actualización a Windows 11"
}

if ($users.Count -gt 3) {
    WARN "Múltiples usuarios"
    $issues += "Muchos usuarios"
}

# SCORE
$score = 100
if ($usedRAMPercent -gt 80) { $score -= 20 }
if ($diskUsagePercent -gt 85) { $score -= 20 }
if ($cpuLoad -gt 80) { $score -= 20 }
if ($diskType -eq "HDD") { $score -= 30 }
if ($score -lt 0) { $score = 0 }

Show-Section "RESULTADO"
Write-Host "📊 SCORE: $score / 100" -ForegroundColor Cyan

# ==========================
# HTML DISEÑO PRO
# ==========================
@"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>KeyNetworks Diagnostic</title>
<style>
body { font-family: Arial; background:#f5f6fa; margin:20px; color:#2f3640;}
.card { background:white; padding:20px; border-radius:10px; margin-bottom:20px; box-shadow:0 2px 10px rgba(0,0,0,0.05);}
.header { background:#111; color:white; padding:20px; border-radius:10px; text-align:center;}
h1,h2 { margin:0 0 10px 0;}
ul { padding-left:20px;}
.bad { color:#e84118;}
.warn { color:#fbc531;}
.ok { color:#44bd32;}
</style>
</head>
<body>

<div class="header">
<h1>KeyNetworks Diagnostic</h1>
<p>Reporte profesional del sistema</p>
</div>

<div class="card">
<h2>📊 Score</h2>
<h1>$score / 100</h1>
</div>

<div class="card">
<h2>🖥️ Sistema</h2>
<p>$($os.Caption) - Build $($os.BuildNumber)</p>
<p>$($computer.Manufacturer) $($computer.Model)</p>
</div>

<div class="card">
<h2>👤 Usuarios</h2>
<ul>
$($users | ForEach-Object { "<li>$($_.LocalPath)</li>" })
</ul>
</div>

<div class="card">
<h2>🌐 Chrome</h2>
<ul>
$($chromeProfiles | ForEach-Object { "<li>$($_.Name)</li>" })
</ul>
</div>

<div class="card">
<h2>🔵 Bluetooth</h2>
<ul>
$($bluetooth | ForEach-Object { "<li>$($_.FriendlyName)</li>" })
</ul>
</div>

<div class="card">
<h2>💾 Memoria</h2>
<p>$([math]::Round($memory / 1GB,2)) GB - Uso $([int]$usedRAMPercent)%</p>
</div>

<div class="card">
<h2>🚨 Problemas</h2>
<ul>
$($issues | ForEach-Object { "<li class='bad'>$_</li>" })
</ul>
</div>

<div class="card">
<h2>💡 Recomendaciones</h2>
<ul>
$($recommendations | ForEach-Object { "<li class='warn'>$_</li>" })
</ul>
</div>

<div class="card">
<h2>🛠 Soporte</h2>
<p>Optimización, upgrades y soporte empresarial</p>
<p><strong>soporte@keynetworks.mx</strong></p>
</div>

</body>
</html>
"@ | Out-File $HTML_REPORT -Encoding UTF8

Write-Host "`n📄 Reporte generado: $HTML_REPORT" -ForegroundColor Green
Invoke-Item $HTML_REPORT
