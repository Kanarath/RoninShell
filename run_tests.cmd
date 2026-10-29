@echo off
rem Ejecuta los tests de RoninShell con Godot en modo consola (sin ventana).
rem Uso:  run_tests.cmd
rem Si Godot esta en otra ruta, define la variable de entorno GODOT con el .exe de consola.
rem Falla (codigo 1) si algun test falla O si Godot imprime un "SCRIPT ERROR":
rem un error de ejecucion dentro de un test no debe pasar desapercibido.

if "%GODOT%"=="" set "GODOT=C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo No encuentro Godot en "%GODOT%".
    echo Define la variable GODOT con la ruta del .exe de consola.
    exit /b 2
)

set "OUT=%TEMP%\roninshell_tests.txt"
"%GODOT%" --headless --path "%~dp0." --script res://tests/run_tests.gd > "%OUT%" 2>&1
set "CODE=%ERRORLEVEL%"
type "%OUT%"

findstr /C:"SCRIPT ERROR" "%OUT%" >nul
if not errorlevel 1 (
    echo.
    echo ERROR: Godot informo de errores de script durante las pruebas.
    exit /b 1
)
exit /b %CODE%
