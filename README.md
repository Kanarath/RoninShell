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
- **Shell con scripts de una línea**: variables (`VAR=x`, `$VAR`, `${VAR}`, `$?`, `~`), `;` `&&` `||`, `for x in ...; do ...; done`, `$(comando)`, y `export env unset seq test true false`. Sin bucles anidados ni `if`/`while` todavía.
- **Tercer laboratorio, "Guardia de logs"** (defensivo): analiza `auth.log` y `access.log` de un servidor propio con tuberías, variables, bucles y `&&`/`||`, y termina con un informe de medidas defensivas.
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
