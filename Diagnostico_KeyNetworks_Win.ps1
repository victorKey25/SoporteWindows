param (
    [string]$ReportPath = "$env:USERPROFILE\Documents\KeyNetworks\Reports"
)

New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
$HTML_REPORT = "$ReportPath\report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

# ==========================
# SISTEMA
# ==========================
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
$uptime = (Get-Date) - $os.LastBootUpTime
$arch = $os.OSArchitecture
$fecha = Get-Date

# ==========================
# VERSION WINDOWS
# ==========================
$build = [int]$os.BuildNumber
if ($build -lt 19045) {
    $winStatus = "⚠ Windows desactualizado (recomendado actualizar)"
} else {
    $winStatus = "✔ Windows actualizado"
}

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
# CPU
# ==========================
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

# ==========================
# RED
# ==========================
$wifi = (netsh wlan show interfaces | Select-String "SSID") -replace "SSID\s+:\s+",""
$ip = try { Invoke-RestMethod "https://api.ipify.org" } catch { "No disponible" }

# ==========================
# BATERÍA
# ==========================
$battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$batteryPercent = if ($battery) { "$($battery.EstimatedChargeRemaining)%" } else { "No aplica" }

# ==========================
# PROCESOS
# ==========================
$topProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 10 Name,@{n="MB";e={[math]::Round($_.WS/1MB,2)}}

# ==========================
# CHROME
# ==========================
$chromeProfilesData = @()
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"

if (Test-Path $chromePath) {
    Get-ChildItem $chromePath -Directory | Where-Object { $_.Name -match "Profile|Default" } | ForEach-Object {
        try {
            $json = Get-Content "$($_.FullName)\Preferences" -Raw | ConvertFrom-Json
            $name = $json.profile.name
            $email = $json.account_info[0].email
            if (!$name) { $name = $_.Name }
            if (!$email) { $email = "Sin correo" }
            $chromeProfilesData += "$name - $email"
        } catch {}
    }
}

# ==========================
# BLUETOOTH
# ==========================
$btDevices = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
Where-Object { $_.FriendlyName } |
Select-Object -ExpandProperty FriendlyName

# ==========================
# ARCHIVOS PESADOS
# ==========================
$heavyFiles = Get-ChildItem $env:USERPROFILE -Recurse -File -ErrorAction SilentlyContinue |
Sort-Object Length -Descending | Select-Object -First 10 FullName,@{n="MB";e={[math]::Round($_.Length/1MB,2)}}

# ==========================
# APPS
# ==========================
$apps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
Where-Object { $_.DisplayName } | Select-Object -First 20 DisplayName

# ==========================
# SOSPECHOSOS
# ==========================
$suspicious = Get-Process | Where-Object { $_.Path -like "*AppData*" -or $_.Path -like "*Temp*" }

if ($suspicious -and $suspicious.Count -gt 0) {
    $suspiciousList = ($suspicious | ForEach-Object { "<li>$($_.Name)</li>" }) -join ""
} else {
    $suspiciousList = "<li>✅ No se encontraron amenazas evidentes</li>"
}

# ==========================
# ANALISIS
# ==========================
$issues = @()
$recommendations = @()
$scoreDetails = @()

if ($usedRAMPercent -gt 80) {
    $issues += "RAM alta"
    $recommendations += "RAM actual: $([math]::Round($totalRAM/1GB))GB → recomendado: 16GB"
    $scoreDetails += "❌ RAM alta"
} else { $scoreDetails += "✔ RAM OK" }

if ($diskPhysical.MediaType -eq "HDD") {
    $issues += "Disco HDD"
    $recommendations += "Migrar a SSD mejora hasta 5x rendimiento"
    $scoreDetails += "❌ HDD detectado"
} else { $scoreDetails += "✔ SSD detectado" }

if ($diskUsagePercent -gt 85) {
    $issues += "Disco lleno"
    $recommendations += "Liberar espacio (archivos grandes detectados)"
    $scoreDetails += "⚠ Disco lleno"
} else { $scoreDetails += "✔ Disco OK" }

if ($cpuLoad -gt 80) {
    $issues += "CPU alta"
    $recommendations += "Optimizar procesos en segundo plano"
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

if ($score -ge 80) { $scoreColor="#2ecc71"; $final="Equipo en excelente estado" }
elseif ($score -ge 50) { $scoreColor="#f1c40f"; $final="Equipo funcional con mejoras recomendadas" }
else { $scoreColor="#e74c3c"; $final="Equipo requiere optimización urgente" }

# ==========================
# HTML
# ==========================
@"
<html>
<head>
<style>
body { font-family: Arial; background:#f5f6fa; margin:0; padding:20px; }
.card { background:white; padding:20px; border-radius:12px; margin-top:20px; box-shadow:0 4px 10px rgba(0,0,0,0.05);}
h2 { border-bottom:1px solid #eee; padding-bottom:5px; }
ul { padding-left:20px; }
</style>
</head>

<body>

<div style="background:linear-gradient(135deg,#1e272e,#2f3640);color:white;padding:30px;border-radius:12px;text-align:center;">
<h1 style="margin:0;font-size:34px;letter-spacing:2px;text-transform:uppercase;">KeyNetworks</h1>
<p>Diagnóstico Técnico Completo</p>
<p style="opacity:0.8;">Generado: $fecha | Versión: 1.3.2</p>
<hr style="border:0;border-top:1px solid #555;">
<p>📞 55 7434 7924 | 📩 contacto@keynetworks.com.mx | 🌐 keynetworks.com.mx</p>
</div>

<div class="card" style="text-align:center;">
<h1 style="color:$scoreColor;font-size:40px;">$score / 100</h1>
<p>$final</p>
</div>

<div class="card">
<h2>🖥️ Sistema</h2>
<p><strong>$($os.Caption)</strong></p>
<p>Arquitectura: $arch</p>
<p>Estado: $winStatus</p>
<p>CPU: $($cpu.Name)</p>
<p>Uptime: $($uptime.Days)d $($uptime.Hours)h</p>
</div>

<div class="card">
<h2>💾 Memoria</h2>
<p>Total: $([math]::Round($totalRAM/1GB))GB</p>
<ul>$($ramModules | % { "<li>$([math]::Round($_.Capacity/1GB,2))GB - $($_.Speed)MHz</li>" })</ul>
</div>

<div class="card">
<h2>🗄️ Disco</h2>
<p>$($diskPhysical.MediaType) - $([int]$diskUsagePercent)% uso</p>
</div>

<div class="card">
<h2>🌐 Red</h2>
<p>IP: $ip</p>
<p>WiFi: $wifi</p>
</div>

<div class="card">
<h2>🌐 Chrome</h2>
<ul>$($chromeProfilesData | % { "<li>$_</li>" })</ul>
</div>

<div class="card">
<h2>🔵 Bluetooth</h2>
<ul>$($btDevices | % { "<li>$_</li>" })</ul>
</div>

<div class="card">
<h2>📂 Archivos pesados</h2>
<ul>$($heavyFiles | % { "<li>$($_.FullName) - $($_.MB) MB</li>" })</ul>
</div>

<div class="card">
<h2>📊 Procesos</h2>
<ul>$($topProcesses | % { "<li>$($_.Name) - $($_.MB) MB</li>" })</ul>
</div>

<div class="card">
<h2>📦 Aplicaciones</h2>
<ul>$($apps | % { "<li>$($_.DisplayName)</li>" })</ul>
</div>

<div class="card">
<h2>🛡️ Seguridad</h2>
<ul>$suspiciousList</ul>
</div>

<div class="card">
<h2>🚨 Problemas</h2>
<ul>$($issues | % { "<li>$_</li>" })</ul>
</div>

<div class="card">
<h2>💡 Recomendaciones</h2>
<ul>$($recommendations | % { "<li>$_</li>" })</ul>
</div>

</body>
</html>
"@ | Out-File $HTML_REPORT -Encoding UTF8

Invoke-Item $HTML_REPORT
