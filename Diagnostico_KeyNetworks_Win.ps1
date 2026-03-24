<#
.SYNOPSIS
KeyNetworks Diagnostic Tool - Reporte HTML Inteligente

.VERSION
2.0

.AUTHOR
Victor Keymolen - KeyNetworks
#>

param (
    [string]$ReportPath = "$env:USERPROFILE\Desktop\WindowsDiagnostic"
)

$VERSION = "2.0"
$HTML_REPORT = "$ReportPath\report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null

# ==========================
# FUNCIONES
# ==========================
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
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
$uptime = (Get-Date) - $os.LastBootUpTime

# RAM
$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum | Select-Object -ExpandProperty Sum
$osInfo = Get-CimInstance Win32_OperatingSystem
$freeMemoryBytes = $osInfo.FreePhysicalMemory * 1KB
$usedRAMPercent = (($memory - $freeMemoryBytes) / $memory) * 100

# Disco
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskType = (Get-PhysicalDisk | Select-Object -First 1).MediaType

# CPU uso
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

# ==========================
# ANÁLISIS INTELIGENTE
# ==========================
$issues = @()
$recommendations = @()

if ($usedRAMPercent -gt 80) {
    $issues += "RAM alta ($([int]$usedRAMPercent)%)"
    $recommendations += "Ampliar RAM a 16GB o más"
}

if ($diskUsagePercent -gt 85) {
    $issues += "Disco casi lleno ($([int]$diskUsagePercent)%)"
    $recommendations += "Liberar espacio o ampliar almacenamiento"
}

if ($diskType -eq "HDD") {
    $issues += "Disco HDD detectado"
    $recommendations += "Cambiar a SSD (MEJORA CRÍTICA)"
}

if ($cpuLoad -gt 80) {
    $issues += "CPU alta ($([int]$cpuLoad)%)"
    $recommendations += "Revisar procesos en segundo plano"
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
<!DOCTYPE html>
<html>
<head>
<title>Diagnóstico - $($env:COMPUTERNAME)</title>
<style>
body { font-family: Arial; margin:20px; }
.card { background:#f4f4f4; padding:15px; border-radius:8px; margin-bottom:20px; }
.header { background:#111; color:white; padding:15px; border-radius:8px; text-align:center; }
.critical { color:red; }
.warning { color:orange; }
</style>
</head>
<body>

<div class="header">
<strong>KeyNetworks</strong><br>
soporte@keynetworks.mx
</div>

<h1>Diagnóstico - $($env:COMPUTERNAME)</h1>
<p>Fecha: $(Get-Date) | Versión: $VERSION</p>

<div class="card">
<h2>📊 Evaluación General</h2>
<h3>Score: $score / 100</h3>

<h3>Problemas:</h3>
<ul>
$($issues | ForEach-Object { "<li class='critical'>$_</li>" })
</ul>

<h3>Recomendaciones:</h3>
<ul>
$($recommendations | ForEach-Object { "<li class='warning'>$_</li>" })
</ul>
</div>

<div class="card">
<h2>Sistema</h2>
<p>$($computer.Manufacturer) - $($computer.Model)</p>
<p>$($os.Caption)</p>
<p>CPU: $($cpu.Name)</p>
</div>

<div class="card">
<h2>RAM</h2>
<p>Total: $([math]::Round($memory / 1GB,2)) GB</p>
<p>Uso: $([int]$usedRAMPercent)%</p>
</div>

<div class="card">
<h2>Disco</h2>
<p>Tipo: $diskType</p>
<p>Uso: $([int]$diskUsagePercent)%</p>
</div>

<div class="card">
<h2>🛠 Soporte</h2>
<p>¿Quieres optimizar tu equipo?</p>
<p>Contáctanos: soporte@keynetworks.mx</p>
</div>

</body>
</html>
"@ | Out-File $HTML_REPORT -Encoding UTF8

Write-Host "✅ Reporte generado: $HTML_REPORT" -ForegroundColor Green
Invoke-Item $HTML_REPORT
