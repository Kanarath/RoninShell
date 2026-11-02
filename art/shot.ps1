# Captura de pantalla del juego para revisar la interfaz: .\art\shot.ps1 nombre "args del juego"
param([string]$Name, [string]$GameArgs = "", [double]$Delay = 1.5)
$g = "C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
$d = Split-Path -Parent $PSScriptRoot
$out = Join-Path $d "art\out_deck\$Name.png"
$argList = @("--path", "`"$d`"", "--", "--no-save") + ($GameArgs -split " " | Where-Object { $_ }) + @("--screenshot=`"$out`"", "--shot-delay=$Delay")
$p = Start-Process -FilePath $g -ArgumentList $argList -PassThru -RedirectStandardError "$d\art\out_deck\err.txt" -RedirectStandardOutput "$d\art\out_deck\out.txt"
if (-not $p.WaitForExit(60000)) { $p.Kill(); "TIMEOUT" }
Get-Content "$d\art\out_deck\err.txt", "$d\art\out_deck\out.txt" | Select-String "SCRIPT ERROR|Parse Error" | Select-Object -First 8
