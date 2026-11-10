# RoninShell

Simulador de aprendizaje de pentesting, gamificado y 100 % local, hecho en Godot 4.7.

Aprendes Linux, Bash y pentesting **investigando** en un laboratorio controlado: recibes un objetivo, usas una terminal simulada con estado real, interpretas resultados y demuestras con evidencias lo que has conseguido. Sin historia, sin vidas, sin esperas.

## Estado

Jugable: un laboratorio ("Primer contacto") con 4 misiones y 17 objetivos, de la orientación en Linux hasta un mini informe.

Qué hay hecho:
- **Motor de laboratorio** (`engine/`): estado del mundo cargado desde datos, intérprete de comandos (comillas, tuberías, redirecciones, errores estilo bash), permisos Unix reales y comandos `ls cd cat head tail wc sort uniq grep find chmod whoami id` más `ping`, `nmap` y `curl` simulados desde el mismo estado.
- **Misiones** (`engine/missions/`, `data/missions/`): los objetivos se demuestran en la terminal y se comprueban sobre lo observado, no sobre el comando exacto. Cuatro tipos: observar, contrastar (provocar las dos situaciones que hay que distinguir), clasificar (`hallazgo`: indicio, hipótesis, confirmado, falso positivo) y redactar (`revisar` comprueba tu informe contra una lista). Pistas en 3-4 niveles, XP por nivel de ayuda, evidencias y perfil de competencias. La autoevaluación tipo test es opcional (`responder`).
- **Campaña de laboratorios** (`laboratorio`): "Primer contacto" (Linux, permisos, reconocimiento de red y un informe) y, al completarlo, "Tienda web" (auditoría autorizada de una aplicación web ficticia: alcance, cabeceras de seguridad, sesiones y cookies, y control de acceso). El progreso de cada uno se guarda por separado. Los sitios web simulados son solo datos: rutas con variantes que dependen del método, la consulta, el formulario y las cookies.
- **Modo libre y repaso**: `modo libre` es un laboratorio sin objetivos para experimentar (lo que hagas no cuenta ni da XP; `reiniciar` lo restaura). `repaso` aplica repetición espaciada por conceptos: lo que resuelves con ayuda vuelve antes y lo que resuelves solo, más tarde. Los retos de repaso son escenarios nuevos (otra red, otros hosts), así que no sirve recordar respuestas; superarlos da XP y fallarlos nunca resta.
- **Shell con scripts de una línea**: variables (`VAR=x`, `$VAR`, `${VAR}`, `$?`, `~`), `;` `&&` `||`, `for`, `while`, `until` e `if/elif/else` (anidables, con tope de seguridad contra bucles infinitos), `$(comando)`, aritmética `$((a+1))`, `export env unset seq test [ true false`, `break`/`continue`, `case ... esac` y funciones (`nombre() { ...; }` con `$1`, `$#`, `$@` y `return`; máximo 20 llamadas anidadas). Comodines `*`, `?` y clases `[0-9]`/`[a-z]` sobre el sistema de archivos del laboratorio (también en `case`). Texto: `cut`, `tr` y `comm`, además de `grep sort uniq`.
- **Tercer laboratorio, "Guardia de logs"** (defensivo): analiza `auth.log` y `access.log` de un servidor propio con tuberías, variables, bucles y `&&`/`||`, y termina con un informe de medidas defensivas.
- **Cuarto laboratorio, "Endurecimiento"** (defensivo): revisión de la configuración de SSH y permisos de una copia de trabajo de un servidor propio, corrección, verificación con `if` e informe.
- **Quinto laboratorio, "Triaje de un incidente"** (defensivo): ante un aviso de monitorización, resumes el registro con `sort | uniq -c`, separas hechos de suposiciones, automatizas con funciones y `case`, y entregas un informe con límites y medidas.
- **Sexto laboratorio, "Copias y recuperación"** (defensivo): crear carpetas, copiar antes de cambiar, verificar con `sha256sum` y `diff`, borrar con cuidado y volver atrás restaurando la copia. Incluye los comandos simulados `mkdir touch cp mv rm sha256sum diff` (solo sobre el sistema de archivos virtual, con permisos y protección de la raíz) y tres repasos nuevos.
- **Séptimo laboratorio, "Inventario y exposición"** (defensivo, red propia): escaneas la red, guardas el estado con `nmap | grep > archivo`, lo comparas con el inventario esperado usando `diff` (ahora con algoritmo de líneas comunes, formato normal), compruebas qué es lo que sobra, separas hechos de suposiciones y cierras sobre una copia.
- **Octavo laboratorio, "Higiene de cuentas"** (defensivo): revisas con una política delante qué cuentas llevan más de 90 días sin acceso, propones bloquearlas sobre copias (sin bloquear de más ni a ciegas: lo dudoso pasa a revisión), endureces la política de contraseñas y entregas un informe con límites y medidas.
- **Noveno laboratorio, "Radar de vulnerabilidades"** (defensivo): identificas versiones con `nmap -sV` y las contrastas con una base de datos LOCAL y ficticia de avisos (`avisos <host> <puerto>`, comando nuevo): cada aviso dice la clase de fallo y su gravedad, nunca cómo explotarlo. Enseña a priorizar qué actualizar antes según la gravedad, y a no asumir que "sin avisos" es "sin riesgo".
- **Décimo laboratorio, "Auditoría de cabeceras web"** (observación: solo GET/HEAD, nada de formularios ni intentos de acceso): comparas cabeceras de seguridad entre rutas, encuentras una ruta expuesta sin enlazar (via robots.txt) y priorizas qué corregir antes (una ruta entera expuesta pesa más que una cabecera que falta).
- **Resumen de campaña (F5)**: los laboratorios de un vistazo, con su estado y tu progreso real en cada uno (misión y XP), no solo el activo.
- **Examen final** (`repaso examen`): encadena un reto de repaso de cada bloque grande del temario (Linux, redes, web, automatización, defensa), uno tras otro, con un resumen final de cuántos se superaron.
- **Repaso espaciado de automatización**: seis retos nuevos (tuberías, variables, bucles, encadenar, logs y comodines) en un laboratorio distinto.
- **Editor `nano`**: ventana con Ctrl+S para guardar y Esc para cerrar, con los mismos permisos que el resto del laboratorio.
- **Ayuda integrada**: `<comando> --help`, `man <comando>` (con límites y "qué NO puedes concluir"), `help`, y `cheatsheet [tema]`.
- **Interfaz** (`ui/`): terminal interactiva (escribir directo, historial con flechas, Tab, Ctrl+L), paneles de misión, mapa de red y expediente, con VFX mínimo.
- **Progreso** guardado en tu equipo (`user://`).

Siguiente: modo libre, repaso espaciado, más laboratorios y pentesting web. El diseño está en [`docs/GDD.md`](docs/GDD.md).

## Probar el juego

Abre la carpeta con Godot 4.7 y pulsa F5. Escribe directamente (no hace falta pulsar Enter antes). Empieza con `mision` y `help`. Al arrancar aparece el **menú inicial**: continuar partida, nueva partida (borra el progreso, con confirmación), ajustes, modo pruebas y salir. Teclas: `F9` menú, `F1` chuleta de comandos, `F10` ajustes (efectos, tamaño de letra, alto contraste, mascota y aviso de descanso), `F11` **modo pruebas** y `F2` efectos. `Esc` cierra cualquier ventana.

**Modo pruebas** (`F11` o desde el menú): botones para saltar directo a cualquier misión de cualquier laboratorio (las anteriores quedan completadas, sin XP), a un modo (libre, misión, repaso por concepto), abrir ventanas, dar XP, marcar repasos como atrasados, reiniciar el laboratorio o borrar el progreso. Para arrancar sin menú: `godot --path . -- --no-menu`. El diseño visual de referencia está en `docs/reference/`. Para empezar de cero, borra el archivo de progreso de la carpeta de datos de la app.

## Ejecutar los tests

```
run_tests.cmd
```

Lanza Godot en modo consola (`--headless`), descubre `tests/test_*.gd`, ejecuta cada método `test_*` y devuelve código de salida 1 si algo falla. Si Godot no está en la ruta por defecto, define la variable de entorno `GODOT` con la ruta del `.exe` de consola.

## Interfaz "cyberdeck"

La ventana es la pantalla de un cyberdeck: carcasa de metal con remaches, esquinas doradas y una franja de mandos
(los LEDs reaccionan a lo que haces). Al abrir el juego, las compuertas se abren y carga (cualquier tecla lo salta).
Los paneles laterales (objetivos, mapa, expediente) se amplían con el botón de la esquina o clicando en su título,
con un zoom desde su sitio; Esc o un clic fuera los cierra. Hay cursor propio, ondas al hacer clic y chispas al
completar objetivos. Todo ello se apaga con F2 / Ajustes → Efectos visuales.

El arte sale de `art/deck.px.js` (`build_art.cmd` lo copia a `assets/ui`). `art/shot.ps1` hace capturas para revisar la interfaz.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `engine/` | Motor de laboratorio, sin interfaz (próximos pasos) |
| `data/` | Laboratorios, misiones y fichas como datos |
| `ui/`, `scenes/` | Interfaz de Godot |
| `tests/` | Runner y tests automáticos |

## Ideas clave

- **Aprender haciendo:** ningún reto se supera con una secuencia memorizada.
- **Terminal simulada con estado real:** hosts, puertos, servicios, archivos y permisos coherentes entre comandos. Nada llega al sistema anfitrión.
- **Pistas progresivas** en cuatro niveles, sin penalización que bloquee.
- **Pensado para sesiones cortas:** misiones de 10-15 min, micro-victorias, objetivo siempre visible, sin presión de tiempo.
- **Pixel art** generado con `pxl` para que la interfaz también enseñe.

## Requisitos (previstos)

- Godot 4.7 (sin Docker, sin base de datos, sin internet).
