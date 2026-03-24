<#
.SYNOPSIS
KeyNetworks Diagnostic Tool (Mac Style + AI)

.VERSION
2.1

.AUTHOR
Victor Keymolen - KeyNetworks
#>

param (
    [string]$ReportPath = "$env:USERPROFILE\Desktop\WindowsDiagnostic"
)

$VERSION = "2.1"
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

# ==========================
# DATOS
# ==========================
Show-Section "INICIANDO DIAGNÓSTICO KEYNETWORKS"

$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor

# CPU
Show-Section "CPU"
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
Write-Host "Modelo: $($cpu.Name)"
Write-Host "Uso actual: $([int]$cpuLoad)%"

# RAM
Show-Section "MEMORIA RAM"
$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum | Select-Object -ExpandProperty Sum
$freeMemory = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB
$usedRAMPercent = (($memory - $freeMemory) / $memory) * 100

Write-Host "Total: $([math]::Round($memory / 1GB,2)) GB"
Write-Host "Uso: $([int]$usedRAMPercent)%"

# DISCO
Show-Section "ALMACENAMIENTO"
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskType = (Get-PhysicalDisk | Select-Object -First 1).MediaType

Write-Host "Tipo: $diskType"
Write-Host "Uso: $([int]$diskUsagePercent)%"

# PROCESOS
Show-Section "PROCESOS PESADOS"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU

# ==========================
# ANÁLISIS INTELIGENTE
# ==========================
Show-Section "ANÁLISIS INTELIGENTE"

$issues = @()
$recommendations = @()

if ($usedRAMPercent -gt 80) {
    BAD "RAM saturada ($([int]$usedRAMPercent)%)"
    $issues += "RAM alta"
    $recommendations += "Ampliar a 16GB o más"
} else {
    OK "RAM en buen estado"
}

if ($diskType -eq "HDD") {
    BAD "Disco HDD detectado"
    $issues += "Disco HDD"
    $recommendations += "Cambiar a SSD (CRÍTICO)"
} else {
    OK "Disco SSD detectado"
}

if ($diskUsagePercent -gt 85) {
    WARN "Disco casi lleno"
    $issues += "Disco lleno"
    $recommendations += "Liberar espacio"
}

if ($cpuLoad -gt 80) {
    WARN "CPU alta ($([int]$cpuLoad)%)"
    $issues += "CPU alta"
    $recommendations += "Revisar procesos"
}

# SCORE
$score = 100
if ($usedRAMPercent -gt 80) { $score -= 20 }
if ($diskUsagePercent -gt 85) { $score -= 20 }
if ($cpuLoad -gt 80) { $score -= 20 }
if ($diskType -eq "HDD") { $score -= 30 }

if ($score -lt 0) { $score = 0 }

Show-Section "RESULTADO FINAL"

Write-Host "📊 SCORE: $score / 100" -ForegroundColor Cyan

if ($score -gt 80) { OK "Equipo en buen estado" }
elseif ($score -gt 60) { WARN "Equipo mejorable" }
else { BAD "Equipo requiere optimización" }

# ==========================
# HTML REPORT
# ==========================
@"
<html>
<body style='font-family:Arial'>
<h1>KeyNetworks Diagnostic</h1>
<h2>Score: $score / 100</h2>

<h3>Problemas:</h3>
<ul>
$($issues | ForEach-Object { "<li>$_</li>" })
</ul>

<h3>Recomendaciones:</h3>
<ul>
$($recommendations | ForEach-Object { "<li>$_</li>" })
</ul>

<p>Contacto: soporte@keynetworks.mx</p>

</body>
</html>
"@ | Out-File $HTML_REPORT

Write-Host "`n📄 Reporte generado: $HTML_REPORT" -ForegroundColor Green
Invoke-Item $HTML_REPORT
