# RoninShell

Simulador de aprendizaje de pentesting, gamificado y 100 % local, hecho en Godot 4.7.

Aprendes Linux, Bash y pentesting **investigando** en un laboratorio controlado: recibes un objetivo, usas una terminal simulada con estado real, interpretas resultados y demuestras con evidencias lo que has conseguido. Sin historia, sin vidas, sin esperas.

## Estado

Jugable: un laboratorio ("Primer contacto") con 4 misiones y 17 objetivos, de la orientación en Linux hasta un mini informe.

Qué hay hecho:
- **Motor de laboratorio** (`engine/`): estado del mundo cargado desde datos, intérprete de comandos (comillas, tuberías, redirecciones, errores estilo bash), permisos Unix reales y comandos `ls cd cat head tail wc sort uniq grep find chmod whoami id` más `ping`, `nmap` y `curl` simulados desde el mismo estado.
- **Misiones** (`engine/missions/`, `data/missions/`): objetivos que se comprueban sobre lo observado (no sobre el comando exacto), preguntas de interpretación, pistas en 3-4 niveles, XP por nivel de ayuda, evidencias y perfil de competencias. Órdenes de juego: `mision`, `pista`, `responder`, `expediente`, `perfil`.
- **Interfaz** (`ui/`): terminal interactiva (escribir directo, historial con flechas, Tab, Ctrl+L), paneles de misión, mapa de red y expediente, con VFX mínimo.
- **Progreso** guardado en tu equipo (`user://`).

Siguiente: modo libre, repaso espaciado, más laboratorios y pentesting web. El diseño está en [`docs/GDD.md`](docs/GDD.md).

## Probar el juego

Abre la carpeta con Godot 4.7 y pulsa F5. Escribe directamente (no hace falta pulsar Enter antes). Empieza con `mision` y `help`. `F2` enciende o apaga el VFX. El diseño visual de referencia está en `docs/reference/`. Para empezar de cero, borra el archivo de progreso de la carpeta de datos de la app.

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
