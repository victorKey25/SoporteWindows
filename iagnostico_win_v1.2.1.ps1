<#
.SYNOPSIS
Windows Diagnostic Tool - Genera un reporte completo del sistema en formato HTML

.VERSION
1.2.1

.AUTHOR
Victor Keymolen - KeysTelecom
#>

param (
    [string]$ReportPath = "$env:USERPROFILE\Desktop\WindowsDiagnostic"
)

# Configuración
$VERSION = "1.2.1"
$HTML_REPORT = "$ReportPath\report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null

# Función para formatear tamaños
function Format-Size {
    param([int64]$bytes)
    if ($bytes -ge 1TB) { "{0:N1} TB" -f ($bytes / 1TB) }
    elseif ($bytes -ge 1GB) { "{0:N1} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { "{0:N1} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { "{0:N1} KB" -f ($bytes / 1KB) }
    else { "$bytes B" }
}

# Generar HTML inicial
@"
<!DOCTYPE html>
<html>
<head>
    <title>Diagnóstico Windows - $($env:COMPUTERNAME)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #fff; color: #333; }
        h1, h2, h3 { color: #333; }
        .header {
            background-color: #222;
            color: white;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            font-size: 18px;
            margin-bottom: 20px;
        }
        .card { background: #f9f9f9; border-radius: 8px; padding: 15px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        .critical { color: #e74c3c; }
        .warning { color: #f39c12; }
        pre { background: #f0f0f0; padding: 10px; border-radius: 5px; overflow-x: auto; }
        .scrollable { max-height: 300px; overflow-y: scroll; background: #f0f0f0; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <strong>KeysTelecom</strong> - 
        <a href="https://keystelecom.com/" target="_blank">https://keystelecom.com/</a> | 
        info@keystelecom.com | 
        victor.keymolen@keystelecom.com
    </div>
    <h1>Diagnóstico Técnico Completo - $($env:COMPUTERNAME)</h1>
    <p>Generado: $(Get-Date) | Versión: $VERSION</p>
"@ | Out-File -FilePath $HTML_REPORT -Encoding UTF8

# Información del sistema
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor
$uptime = (Get-Date) - $os.LastBootUpTime

@"
    <div class="card">
        <h2>Sistema</h2>
        <table>
            <tr><th>Fabricante:</th><td>$($computer.Manufacturer)</td></tr>
            <tr><th>Modelo:</th><td>$($computer.Model)</td></tr>
            <tr><th>Windows:</th><td>$($os.Caption) (Build $($os.BuildNumber))</td></tr>
            <tr><th>Arquitectura:</th><td>$($os.OSArchitecture)</td></tr>
            <tr><th>CPU:</th><td>$($cpu.Name)</td></tr>
            <tr><th>Núcleos:</th><td>$($cpu.NumberOfCores) físicos, $($cpu.NumberOfLogicalProcessors) lógicos</td></tr>
            <tr><th>Uptime:</th><td>"$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"</td></tr>
        </table>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Memoria
$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | Select-Object -ExpandProperty Sum
$memoryInGB = [math]::Round($memory / 1GB, 2)
$osInfo = Get-CimInstance Win32_OperatingSystem
$freeMemory = Format-Size ($osInfo.FreePhysicalMemory * 1KB)

@"
    <div class="card">
        <h2>Memoria</h2>
        <table>
            <tr><th>Total RAM:</th><td>$memoryInGB GB</td></tr>
            <tr><th>Uso Actual:</th><td>$freeMemory libres</td></tr>
        </table>
        <h3>Top Procesos (RAM):</h3>
        <pre>$((Get-Process | Sort-Object -Property WS -Descending | Select-Object -First 10 | Format-Table -AutoSize -Property Name, @{Name="Memoria";Expression={Format-Size $_.WS}}, Id | Out-String).Trim())</pre>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Almacenamiento
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskFree = Format-Size $disk.FreeSpace
$diskTotal = Format-Size $disk.Size

@"
    <div class="card">
        <h2>Almacenamiento</h2>
        <table>
            <tr><th>Disco Principal (C:):</th><td>$diskFree libres de $diskTotal ($([math]::Round(($disk.Size - $disk.FreeSpace)/$disk.Size*100))% usado)</td></tr>
        </table>
        <h3>Archivos Más Grandes (Top 10 en C:\Users):</h3>
        <pre>$((Get-ChildItem -Path "$env:USERPROFILE" -Recurse -File -ErrorAction SilentlyContinue | Sort-Object -Property Length -Descending | Select-Object -First 10 | Format-Table -AutoSize -Property FullName, @{Name="Tamaño";Expression={Format-Size $_.Length}} | Out-String).Trim())</pre>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Batería (si es portátil)
$battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if ($battery) {
    $batteryStatus = switch ($battery.BatteryStatus) {
        1 { "Desconocido" }
        2 { "Conectado" }
        3 { "Descargando" }
        4 { "Conectado" }
        5 { "Carga crítica" }
        6 { "Cargando" }
        7 { "Carga crítica" }
        default { "Desconocido" }
    }
    
    $statusClass = if ($batteryStatus -match "Crític") { "warning" } else { "" }
    
    @"
    <div class="card">
        <h2>Batería</h2>
        <table>
            <tr><th>Estado:</th><td class="$statusClass">$batteryStatus</td></tr>
            <tr><th>Capacidad:</th><td>$($battery.EstimatedChargeRemaining)%</td></tr>
        </table>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8
}

# Red
$publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -UseBasicParsing)
$dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses -ne $null }).ServerAddresses -join ", "

@"
    <div class="card">
        <h2>Red</h2>
        <table>
            <tr><th>IP Pública:</th><td>$publicIP</td></tr>
            <tr><th>DNS:</th><td>$dnsServers</td></tr>
        </table>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Aplicaciones instaladas
$installedApps = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Select-Object DisplayName, DisplayVersion, InstallDate | 
    Where-Object { $_.DisplayName } | 
    Sort-Object DisplayName

@"
    <div class="card">
        <h2>Aplicaciones Instaladas</h2>
        <pre>$($installedApps | Format-Table -AutoSize | Out-String)</pre>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Eventos de error recientes
@"
    <div class="card">
        <h2>Últimos Errores (últimas 24h)</h2>
        <div class="scrollable">
            <pre>$((Get-EventLog -LogName System -EntryType Error -After (Get-Date).AddHours(-24) -Newest 20 | Format-Table -AutoSize -Property TimeGenerated, Source, Message | Out-String).Trim()</pre>
        </div>
    </div>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Recomendaciones
@"
    <div class="card">
        <h2>Recomendaciones</h2>
        <ul>
            <li>Mantén Windows actualizado con las últimas actualizaciones de seguridad.</li>
            <li>Haz copias de seguridad periódicas de tus datos importantes.</li>
            <li>Usa un antivirus confiable y mantenlo actualizado.</li>
            <li>Monitorea el estado de tu disco duro con herramientas como CrystalDiskInfo.</li>
            <li>Para portátiles: Calibra la batería periódicamente si notas problemas de autonomía.</li>
            <li>Consulta soporte técnico si detectas procesos o drivers sospechosos.</li>
        </ul>
    </div>
</body>
</html>
"@ | Out-File -FilePath $HTML_REPORT -Append -Encoding UTF8

# Mensaje final
Write-Host "✅ Diagnóstico generado: $HTML_REPORT" -ForegroundColor Green

# Abrir el reporte automáticamente
Invoke-Item $HTML_REPORT
