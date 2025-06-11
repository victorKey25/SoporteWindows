<#
.SYNOPSIS
Diagnóstico Windows — Versión 1.0

#>

param (
    :contentReference[oaicite:1]{index=1}
    :contentReference[oaicite:2]{index=2}\Desktop\WinDiagnostic"
)

# Crear carpeta y archivo HTML
:contentReference[oaicite:3]{index=3}
:contentReference[oaicite:4]{index=4}
:contentReference[oaicite:5]{index=5}

# Función para formatear tamaños
:contentReference[oaicite:6]{index=6}
    :contentReference[oaicite:7]{index=7}
    :contentReference[oaicite:8]{index=8}
    :contentReference[oaicite:9]{index=9}
        :contentReference[oaicite:10]{index=10}
    }
    :contentReference[oaicite:11]{index=11}
}

# Iniciar HTML
$css = @"
:contentReference[oaicite:12]{index=12}
:contentReference[oaicite:13]{index=13}
:contentReference[oaicite:14]{index=14}
:contentReference[oaicite:15]{index=15}
:contentReference[oaicite:16]{index=16}
:contentReference[oaicite:17]{index=17}
:contentReference[oaicite:18]{index=18}
"@

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Diagnóstico Windows - $env:COMPUTERNAME</title>
    <style>$css</style>
</head>
<body>
    <div class="header">
        🛰️ <strong>KeysTelecom</strong> |
        📧 victor.keymolen@keystelecom.com
    </div>
    <h1>🔍 Diagnóstico Técnico Completo - $env:COMPUTERNAME</h1>
    <p>Generado: $(Get-Date) | Versión: $Version</p>
"@

# Sistema
:contentReference[oaicite:19]{index=19}
:contentReference[oaicite:20]{index=20}
:contentReference[oaicite:21]{index=21}
:contentReference[oaicite:22]{index=22}
$html += @"
    :contentReference[oaicite:23]{index=23}
      :contentReference[oaicite:24]{index=24}
      <table>
        :contentReference[oaicite:25]{index=25}
        :contentReference[oaicite:26]{index=26}
        :contentReference[oaicite:27]{index=27}
        :contentReference[oaicite:28]{index=28}
      </table>
    </div>
"@

# Disco
:contentReference[oaicite:29]{index=29}
:contentReference[oaicite:30]{index=30}
    :contentReference[oaicite:31]{index=31}
}
$html += @"
    :contentReference[oaicite:32]{index=32}
      :contentReference[oaicite:33]{index=33}
      <table>
        :contentReference[oaicite:34]{index=34}
        :contentReference[oaicite:35]{index=35}
      </table>
    </div>
"@

# Memoria y procesos top RAM
:contentReference[oaicite:36]{index=36}\Memory\Available MBytes'
:contentReference[oaicite:37]{index=37}
$html += @"
    :contentReference[oaicite:38]{index=38}
      :contentReference[oaicite:39]{index=39}
      <table>
        :contentReference[oaicite:40]{index=40}
      </table>
      :contentReference[oaicite:41]{index=41}
      :contentReference[oaicite:42]{index=42}
    </div>
"@

# Batería (si es laptop)
:contentReference[oaicite:43]{index=43}
if ($batt) {
    :contentReference[oaicite:44]{index=44}
    $html += @"
    :contentReference[oaicite:45]{index=45}
      :contentReference[oaicite:46]{index=46}
      <table>
        :contentReference[oaicite:47]{index=47}
      </table>
    </div>
"@
}

# Red
:contentReference[oaicite:48]{index=48}
:contentReference[oaicite:49]{index=49}
$html += @"
    :contentReference[oaicite:50]{index=50}
      :contentReference[oaicite:51]{index=51}
      <table>
        :contentReference[oaicite:52]{index=52}
        :contentReference[oaicite:53]{index=53}
      </table>
    </div>
"@

# Apps instaladas
:contentReference[oaicite:54]{index=54}\Software\Microsoft\Windows\CurrentVersion\Uninstall\* ,
                      HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
        :contentReference[oaicite:55]{index=55}
$html += @"
    :contentReference[oaicite:56]{index=56}
      :contentReference[oaicite:57]{index=57}
      :contentReference[oaicite:58]{index=58}
    </div>
"@

# Errores recientes
:contentReference[oaicite:59]{index=59}
$html += @"
    :contentReference[oaicite:60]{index=60}
      :contentReference[oaicite:61]{index=61}
      :contentReference[oaicite:62]{index=62}
    </div>
"@

# Recomendaciones y cierre
$html += @"
    :contentReference[oaicite:63]{index=63}
      :contentReference[oaicite:64]{index=64}
      <ul>
        :contentReference[oaicite:65]{index=65}
        :contentReference[oaicite:66]{index=66}
        :contentReference[oaicite:67]{index=67}
        :contentReference[oaicite:68]{index=68}
      </ul>
    </div>
  </body>
</html>
"@

# Guardar y abrir
:contentReference[oaicite:69]{index=69}
:contentReference[oaicite:70]{index=70}
:contentReference[oaicite:71]{index=71}
