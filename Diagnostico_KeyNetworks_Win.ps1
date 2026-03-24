<#
KeyNetworks Diagnostic Tool v5 - FULL AUDIT
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
# SISTEMA BASE
# ==========================
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor

$uptime = (Get-Date) - $os.LastBootUpTime

# ARQUITECTURA
$arch = $os.OSArchitecture

# ==========================
# RAM DETALLE
# ==========================
$ramModules = Get-CimInstance Win32_PhysicalMemory
$totalRAM = ($ramModules | Measure Capacity -Sum).Sum
$freeMemory = $os.FreePhysicalMemory * 1KB
$usedRAMPercent = (($totalRAM - $freeMemory) / $totalRAM) * 100

# ==========================
# DISCO DETALLE
# ==========================
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskPhysical = Get-PhysicalDisk | Select -First 1

# ==========================
# CPU
# ==========================
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

# ==========================
# RED / WIFI
# ==========================
$wifi = netsh wlan show interfaces | Select-String "SSID"
$ip = (Invoke-RestMethod "https://api.ipify.org")

# ==========================
# BATERÍA
# ==========================
$battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$batteryPercent = if ($battery) { $battery.EstimatedChargeRemaining } else { "N/A" }

# ==========================
# PROCESOS TOP RAM
# ==========================
$topProcesses = Get-Process | Sort WS -Descending | Select -First 10 Name, @{Name="MB";Expression={[math]::Round($_.WS/1MB,2)}}

# ==========================
# USUARIOS
# ==========================
$users = Get-CimInstance Win32_UserProfile | Where { $_.Special -eq $false }

# ==========================
# CHROME
# ==========================
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeProfilesData = @()

if (Test-Path $chromePath) {
    $profiles = Get-ChildItem $chromePath -Directory | Where {
        $_.Name -like "Profile*" -or $_.Name -eq "Default"
    }

    foreach ($p in $profiles) {
        try {
            $json = Get-Content "$($p.FullName)\Preferences" -Raw | ConvertFrom-Json
            $name = $json.profile.name
            $email = $json.account_info[0].email
            $chromeProfilesData += "$name - $email"
        } catch {}
    }
}

# ==========================
# BLUETOOTH MEJORADO
# ==========================
$btDevices = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
Select FriendlyName

# ==========================
# ARCHIVOS PESADOS
# ==========================
$heavyFiles = Get-ChildItem $env:USERPROFILE -Recurse -File -ErrorAction SilentlyContinue |
Sort Length -Descending | Select -First 10 FullName, @{Name="MB";Expression={[math]::Round($_.Length/1MB,2)}}

# ==========================
# APPS INSTALADAS
# ==========================
$apps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Where { $_.DisplayName } | Select -First 20 DisplayName

# ==========================
# PROCESOS SOSPECHOSOS
# ==========================
$suspicious = Get-Process | Where {
    $_.Path -like "*AppData*" -or $_.Path -like "*Temp*"
}

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

if ($diskPhysical.MediaType -eq "HDD") {
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

$score = 100
if ($usedRAMPercent -gt 80) { $score -= 20 }
if ($diskUsagePercent -gt 85) { $score -= 20 }
if ($cpuLoad -gt 80) { $score -= 20 }
if ($diskPhysical.MediaType -eq "HDD") { $score -= 30 }

# ==========================
# HTML
# ==========================
@"
<html>
<body style='font-family:Arial;background:#f5f6fa;padding:20px;'>

<h1>KeyNetworks</h1>

<h2>📊 Score: $score / 100</h2>
<ul>$($scoreDetails | % { "<li>$_</li>" })</ul>

<h2>🖥️ Sistema</h2>
<p>$($os.Caption)</p>
<p>Arquitectura: $arch</p>
<p>CPU: $($cpu.Name)</p>
<p>Uptime: $($uptime.Days)d $($uptime.Hours)h</p>

<h2>💾 Memoria</h2>
<p>Total: $([math]::Round($totalRAM/1GB,2)) GB</p>
<ul>$($ramModules | % { "<li>$($_.Capacity/1GB) GB - $($_.Speed) MHz</li>" })</ul>

<h2>🗄️ Disco</h2>
<p>Tipo: $($diskPhysical.MediaType)</p>
<p>Uso: $([int]$diskUsagePercent)%</p>

<h2>🔋 Batería</h2>
<p>$batteryPercent %</p>

<h2>🌐 Red</h2>
<p>IP Pública: $ip</p>
<p>WiFi: $wifi</p>

<h2>🌐 Chrome</h2>
<ul>$($chromeProfilesData | % { "<li>$_</li>" })</ul>

<h2>🔵 Bluetooth</h2>
<ul>$($btDevices | % { "<li>$($_.FriendlyName)</li>" })</ul>

<h2>📂 Archivos pesados</h2>
<ul>$($heavyFiles | % { "<li>$($_.FullName) - $($_.MB) MB</li>" })</ul>

<h2>📊 Top procesos RAM</h2>
<ul>$($topProcesses | % { "<li>$($_.Name) - $($_.MB) MB</li>" })</ul>

<h2>📦 Aplicaciones</h2>
<ul>$($apps | % { "<li>$($_.DisplayName)</li>" })</ul>

<h2>🛡️ Procesos Sospechosos</h2>
<p>$([string]::IsNullOrEmpty($suspicious) ? "No se encontraron amenazas evidentes" : "Revisar procesos")</p>

<h2>🧩 Extensiones Kernel</h2>
<p>No aplica (Windows)</p>

<h2>📩 Contacto</h2>
<p>contacto@keynetworks.com.mx</p>

</body>
</html>
"@ | Out-File $HTML_REPORT -Encoding UTF8

Invoke-Item $HTML_REPORT
