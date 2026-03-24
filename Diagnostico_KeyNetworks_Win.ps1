<#
KeyNetworks Diagnostic Tool v5.1 - FINAL CLEAN
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
# SISTEMA
# ==========================
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
$uptime = (Get-Date) - $os.LastBootUpTime
$arch = $os.OSArchitecture

# ==========================
# RAM
# ==========================
$ramModules = Get-CimInstance Win32_PhysicalMemory
$totalRAM = ($ramModules | Measure-Object Capacity -Sum).Sum
$freeMemory = $os.FreePhysicalMemory * 1KB
$usedRAMPercent = (($totalRAM - $freeMemory) / $totalRAM) * 100

# ==========================
# DISCO
# ==========================
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskUsagePercent = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
$diskPhysical = Get-PhysicalDisk | Select-Object -First 1

# ==========================
# CPU USO
# ==========================
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

# ==========================
# RED / WIFI
# ==========================
$wifi = netsh wlan show interfaces | Select-String "SSID"
$ip = ""
try { $ip = Invoke-RestMethod "https://api.ipify.org" } catch { $ip = "No disponible" }

# ==========================
# BATERÍA
# ==========================
$battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if ($battery) {
    $batteryPercent = "$($battery.EstimatedChargeRemaining)%"
} else {
    $batteryPercent = "No aplica"
}

# ==========================
# PROCESOS TOP RAM
# ==========================
$topProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 10 Name, @{Name="MB";Expression={[math]::Round($_.WS/1MB,2)}}

# ==========================
# USUARIOS
# ==========================
$users = Get-CimInstance Win32_UserProfile | Where-Object { $_.Special -eq $false }

# ==========================
# CHROME (NOMBRE + CORREO)
# ==========================
$chromeProfilesData = @()
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"

if (Test-Path $chromePath) {
    $profiles = Get-ChildItem $chromePath -Directory | Where-Object {
        $_.Name -like "Profile*" -or $_.Name -eq "Default"
    }

    foreach ($p in $profiles) {
        try {
            $pref = Get-Content "$($p.FullName)\Preferences" -Raw | ConvertFrom-Json
            $name = $pref.profile.name
            $email = $pref.account_info[0].email

            if (-not $name) { $name = $p.Name }
            if (-not $email) { $email = "Sin correo" }

            $chromeProfilesData += "$name - $email"
        } catch {}
    }
}

# ==========================
# BLUETOOTH (NOMBRES)
# ==========================
$btDevices = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
Where-Object { $_.FriendlyName } |
Select-Object -ExpandProperty FriendlyName

# ==========================
# ARCHIVOS PESADOS
# ==========================
$heavyFiles = Get-ChildItem $env:USERPROFILE -Recurse -File -ErrorAction SilentlyContinue |
Sort-Object Length -Descending | Select-Object -First 10 FullName, @{Name="MB";Expression={[math]::Round($_.Length/1MB,2)}}

# ==========================
# APLICACIONES
# ==========================
$apps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Where-Object { $_.DisplayName } | Select-Object -First 20 DisplayName

# ==========================
# PROCESOS SOSPECHOSOS
# ==========================
$suspicious = Get-Process | Where-Object {
    $_.Path -like "*AppData*" -or $_.Path -like "*Temp*"
}

if ($suspicious -and $suspicious.Count -gt 0) {
    $suspiciousList = ($suspicious | ForEach-Object {
        "<li>$($_.Name)</li>"
    }) -join ""
} else {
    $suspiciousList = "<li>✅ No se encontraron amenazas evidentes</li>"
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

# SCORE
$score = 100
if ($usedRAMPercent -gt 80) { $score -= 20 }
if ($diskUsagePercent -gt 85) { $score -= 20 }
if ($cpuLoad -gt 80) { $score -= 20 }
if ($diskPhysical.MediaType -eq "HDD") { $score -= 30 }
if ($score -lt 0) { $score = 0 }

# ==========================
# HTML
# ==========================
@"
<html>
<body style='font-family:Arial;background:#f5f6fa;padding:20px;'>

<h1>KeyNetworks</h1>

<h2>📊 Score: $score / 100</h2>
<ul>$($scoreDetails | ForEach-Object { "<li>$_</li>" })</ul>

<h2>🖥️ Sistema</h2>
<p>$($os.Caption)</p>
<p>Arquitectura: $arch</p>
<p>CPU: $($cpu.Name)</p>
<p>Uptime: $($uptime.Days)d $($uptime.Hours)h</p>

<h2>💾 Memoria</h2>
<p>Total: $([math]::Round($totalRAM/1GB,2)) GB</p>
<ul>$($ramModules | ForEach-Object { "<li>$([math]::Round($_.Capacity/1GB,2)) GB - $($_.Speed) MHz</li>" })</ul>

<h2>🗄️ Disco</h2>
<p>Tipo: $($diskPhysical.MediaType)</p>
<p>Uso: $([int]$diskUsagePercent)%</p>

<h2>🔋 Batería</h2>
<p>$batteryPercent</p>

<h2>🌐 Red</h2>
<p>IP Pública: $ip</p>
<p>$wifi</p>

<h2>🌐 Chrome</h2>
<ul>$($chromeProfilesData | ForEach-Object { "<li>$_</li>" })</ul>

<h2>🔵 Bluetooth</h2>
<ul>$($btDevices | ForEach-Object { "<li>$_</li>" })</ul>

<h2>📂 Archivos pesados</h2>
<ul>$($heavyFiles | ForEach-Object { "<li>$($_.FullName) - $($_.MB) MB</li>" })</ul>

<h2>📊 Top procesos RAM</h2>
<ul>$($topProcesses | ForEach-Object { "<li>$($_.Name) - $($_.MB) MB</li>" })</ul>

<h2>📦 Aplicaciones</h2>
<ul>$($apps | ForEach-Object { "<li>$($_.DisplayName)</li>" })</ul>

<h2>🛡️ Procesos Sospechosos</h2>
<ul>$suspiciousList</ul>

<h2>🧩 Extensiones Kernel</h2>
<p>No aplica en Windows</p>

<h2>📩 Contacto</h2>
<p>contacto@keynetworks.com.mx</p>

</body>
</html>
"@ | Out-File $HTML_REPORT -Encoding UTF8

Invoke-Item $HTML_REPORT
