@echo off
rem Ejecuta los tests de RoninShell con Godot en modo consola (sin ventana).
rem Uso:  run_tests.cmd
rem Si Godot esta en otra ruta, define la variable de entorno GODOT con el .exe de consola.

if "%GODOT%"=="" set "GODOT=C:\Users\Ruben\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo No encuentro Godot en "%GODOT%".
    echo Define la variable GODOT con la ruta del .exe de consola.
    exit /b 2
)

"%GODOT%" --headless --path "%~dp0." --script res://tests/run_tests.gd
exit /b %ERRORLEVEL%
