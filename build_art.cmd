@echo off
rem Reconstruye el pixel art: art\roninshell.px.js -> assets\sprites\*.png
rem Necesita Node 22.18 o superior y la herramienta pxl (variable PXL con la ruta de pxl.js).
rem Los previews quedan en art\out\_preview (no se versionan).

if "%PXL%"=="" set "PXL=C:\Users\Ruben\.claude\skills\pxl-pixel-art\bin\pxl.js"
where node >nul 2>nul
if errorlevel 1 (
    echo No encuentro Node. Instala Node 22.18+ o abre una terminal nueva si acabas de instalarlo.
    exit /b 2
)
if not exist "%PXL%" (
    echo No encuentro pxl en "%PXL%". Define la variable PXL con la ruta de pxl.js.
    exit /b 2
)

node "%PXL%" build "%~dp0art\roninshell.px.js" --out "%~dp0art\out" || exit /b 1
if not exist "%~dp0assets\sprites" mkdir "%~dp0assets\sprites"
copy /Y "%~dp0art\out\sprites\*.png" "%~dp0assets\sprites\" >nul
echo Sprites copiados a assets\sprites

rem Cyberdeck: pantalla de arranque, compuertas y cursores -> assets\ui
node "%PXL%" build "%~dp0art\deck.px.js" --out "%~dp0art\out_deck" || exit /b 1
if not exist "%~dp0assets\ui" mkdir "%~dp0assets\ui"
copy /Y "%~dp0art\out_deck\scenes\boot_base.png" "%~dp0assets\ui\" >nul
for %%f in (helmet shutter cursor_arrow cursor_link cursor_text) do copy /Y "%~dp0art\out_deck\sprites\%%f.png" "%~dp0assets\ui\" >nul
echo Arte del cyberdeck copiado a assets\ui
